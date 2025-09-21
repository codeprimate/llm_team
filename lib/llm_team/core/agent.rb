# frozen_string_literal: true

module LlmTeam
  module Core
    # Base agent class implementing dual conversation tracking and tool orchestration
    # 
    # Key non-obvious behaviors:
    # - Maintains separate @conversation_history (per-call) and @persistent_history (cross-calls)
    # - History behavior modes control what persists between calls: :none, :last, :full
    # - Tool discovery uses class-level schema introspection rather than method reflection
    # - Retry logic handles both API failures and tool-not-found scenarios differently
    class Agent
      attr_reader :name, :llm_client, :available_tools, :conversation, :max_iterations

      # Default model parameters - can be overridden by subclasses
      DEFAULT_TEMPERATURE = 0.7

      def initialize(name, model: nil, history_behavior: nil, max_iterations: nil)
        @name = name
        config = LlmTeam.configuration
        
        # Use configuration values with fallbacks
        @model = model || config.model
        @max_iterations = max_iterations || config.max_iterations
        history_behavior ||= config.default_history_behavior
        
        @llm_client = OpenAI::Client.new(
          access_token: config.api_key,
          uri_base: config.api_base_url
        )
        
        @total_tokens_used = 0
        @available_tools = {} # Tool registry: name => agent_instance
        @conversation = Conversation.new(history_behavior: history_behavior)
        @total_latency_ms = 0
        @llm_calls_count = 0
        
        # Always auto-load auxiliary agents
        load_auxiliary_agents
      end

      # Dynamic system prompt resolution - subclasses can define SYSTEM_PROMPT constant
      def system_prompt
        self.class.const_defined?(:SYSTEM_PROMPT) ? self.class::SYSTEM_PROMPT : nil
      end

      # Dynamic tool prompt resolution - subclasses can define TOOL_PROMPT constant
      def tool_prompt
        (self.class.const_defined?(:TOOL_PROMPT) ? self.class::TOOL_PROMPT : nil)
      end

      # Dynamic tool prompt resolution for registered tools
      def registered_tool_prompts
        @available_tools.values.map(&:tool_prompt).compact.join("\n")
      end

      # Get agent-specific model parameters with fallbacks to configuration
      def model_parameters
        config = LlmTeam.configuration
        {
          temperature: self.class::DEFAULT_TEMPERATURE || config.temperature
        }
      end

      # Convert LLM API role strings to our role constants
      def normalize_role(role_string)
        case role_string.to_s
        when "system"
          LlmTeam::ROLE_SYSTEM
        when "user"
          LlmTeam::ROLE_USER
        when "assistant"
          LlmTeam::ROLE_ASSISTANT
        when "tool"
          LlmTeam::ROLE_TOOL
        else
          raise ArgumentError, "Unknown role: #{role_string}"
        end
      end

      # Tool registration: maps symbolic names to agent instances for dynamic dispatch
      def register_tool(tool_name, tool_instance)
        if @available_tools.key?(tool_name)
          raise LlmTeam::AgentRegistrationError, "Tool '#{tool_name}' is already registered. Cannot overwrite existing tool."
        end

        @available_tools[tool_name] = tool_instance
      end

      # Schema extraction for LLM tool calling - relies on class-level tool_schema method
      def tool_schemas
        @available_tools.values.map(&:class).map(&:tool_schema)
      end

      # Main orchestration method with conversation state management and tool iteration
      # 
      # Non-obvious behaviors:
      # - Forces max_iterations=1 when no tools registered (prevents infinite loops)
      # - Manages dual conversation tracking: ephemeral vs persistent history
      # - Handles tool-not-found retries by decrementing iteration counter
      # - Applies history cleanup after completion regardless of success/failure
      def process_with_tools(initial_message, temperature: nil, history_behavior: nil)
        history_behavior ||= @conversation.history_behavior
        
        # Use agent's default temperature if not provided
        temperature ||= model_parameters[:temperature]

        # create a constructed system prompt using this class's system_prompt and all registered tools' prompts
        constructed_tool_prompt = registered_tool_prompts.empty? ? "" : "\n\nTOOLS AVAILABLE:\n" + registered_tool_prompts
        constructed_system_prompt = system_prompt + (constructed_tool_prompt.empty? ? "" : constructed_tool_prompt)

        # Build conversation context from persistent history + new message
        conversation_messages = @conversation.build_conversation_for_llm(constructed_system_prompt, initial_message, history_behavior: history_behavior)

        # Initialize ephemeral conversation for this call
        @conversation.conversation_history = conversation_messages

        # Prevent infinite loops: no tools = no iterations needed
        current_max_iterations = @available_tools.empty? ? 1 : @max_iterations

        iteration = 0
        while iteration < current_max_iterations
          iteration += 1
          puts "\n🔄 #{name} - Iteration #{iteration}".blue.bold

          # Prepare call_llm arguments with agent's model parameters
          call_args = model_parameters.dup
          call_args[:temperature] = temperature if temperature

          # Only add tool-related arguments if tools are registered
          if @available_tools.any?
            call_args[:tools] = tool_schemas
            call_args[:tool_choice] = :auto
          end

          # Call LLM with conditional tool arguments (with retry logic)
          response = call_llm_with_retry(@conversation.conversation_history, **call_args)

          # Check if response is valid after retries
          if response.nil?
            puts "\n❌ #{name} failed to get valid response after retries".red.bold
            return "Error: No response from LLM API after retries"
          end

          message = response.dig("choices", 0, "message")

          # Check if message is valid
          if message.nil?
            puts "\n❌ #{name} received nil message from LLM response".red.bold
            puts "Response structure: #{response.inspect}".light_black
            return "Error: Invalid response structure from LLM"
          end

          if message["tool_calls"]
            # Execute tools and detect missing tool errors
            tools_not_found = handle_tool_calls(message["tool_calls"])

            # Retry mechanism: undo iteration increment and remove failed assistant message
            if tools_not_found
              puts "  🔄 Retrying iteration due to tool not found errors".yellow
              iteration -= 1  # Rewind iteration counter
              # @conversation_history.pop  # Remove the failed assistant message
              next
            end
          elsif message["content"]
            # Final response
            @conversation.add_message(
              normalize_role(message["role"]),
              message["content"]
            )
            puts "\n✅ #{name} completed with response".green.bold
            puts "  ⏱️  Total latency: #{format_latency(@total_latency_ms)} (#{@llm_calls_count} LLM calls)".light_black
            puts "\n📝 #{name} Response:".yellow
            puts message["content"]
            puts "\n" + "─" * 50

            # Apply history cleanup based on behavior
            @conversation.cleanup_conversation_history(history_behavior)

            return message["content"]
          else
            puts "\n⚠️  #{name} received no tool call or content".yellow
            return "No response generated."
          end
        end

        puts "\n⏰ #{name} reached max iterations (#{current_max_iterations})".yellow

        # Apply history cleanup based on behavior even when max iterations reached
        @conversation.cleanup_conversation_history(history_behavior)

        "Max iterations reached without response."
      end

      # Abstract method for simple task processing (without tool orchestration)
      def process_task(task_description)
        raise NotImplementedError, "#{self.class} must implement #process_task"
      end

      protected


      # API retry wrapper with exponential backoff for transient failures
      # 
      # Non-obvious behaviors:
      # - Only retries on nil responses (API failures), not on tool-not-found errors
      # - Uses fixed 1-second delay (not exponential backoff)
      # - Returns nil after max retries, triggering higher-level error handling
      def call_llm_with_retry(messages, temperature: nil, tool_choice: nil, tools: [], max_retries: nil)
        temperature ||= model_parameters[:temperature]
        max_retries ||= LlmTeam.configuration.max_retries
        
        retry_count = 0

        loop do
          response = call_llm(messages, temperature: temperature, tool_choice: tool_choice, tools: tools)

          # Return immediately on successful response
          return response unless response.nil?

          retry_count += 1

          if retry_count <= max_retries
            puts "  🔄 Retrying LLM call (#{retry_count}/#{max_retries})...".yellow
            sleep(1)  # Fixed delay - could be exponential
          else
            puts "  ❌ Max retries (#{max_retries}) exceeded".red.bold
            return nil
          end
        end
      end

      # Core LLM API call with performance tracking and error handling
      # 
      # Non-obvious behaviors:
      # - Conditionally includes tools/tool_choice only when tools are registered
      # - Measures and accumulates latency across all calls for this agent
      # - Returns nil on any API error (triggers retry logic in caller)
      # - Tracks token usage per agent for cost monitoring
      def call_llm(messages, temperature: nil, tool_choice: nil, tools: [], **model_params)
        temperature ||= model_parameters[:temperature]
        puts "  📡 Calling LLM (#{messages.size} messages)".cyan
        puts "  🔧 Tools: #{tools.any? ? tools.map { |t| t[:function][:name] }.join(", ") : "None"}".light_black

        # Start with agent's default model parameters
        request_params = model_parameters.merge(model_params)
        request_params[:model] = @model
        request_params[:messages] = messages
        request_params[:temperature] = temperature

        # Only include tool parameters when tools are actually registered
        request_params[:tools] = tools if tools.any?
        request_params[:tool_choice] = tool_choice if tool_choice

        start_time = Time.now

        begin
          response = llm_client.chat(parameters: request_params)
        rescue => e
          puts "  ❌ LLM API Error: #{e.class} - #{e.message}".red.bold
          puts "  Request params: #{request_params.inspect}".light_black
          return nil
        end

        end_time = Time.now

        # Accumulate performance metrics
        latency_ms = ((end_time - start_time) * 1000).round(2)
        @total_latency_ms += latency_ms
        @llm_calls_count += 1

        puts "  ⏱️  Latency: #{format_latency(latency_ms)} | Total: #{format_latency(@total_latency_ms)} (#{@llm_calls_count} calls)".light_black

        track_token_usage(response)
        response
      end

      # Tool execution dispatcher with error handling and conversation integration
      # 
      # Non-obvious behaviors:
      # - Tool discovery uses schema introspection, not method reflection
      # - Always adds assistant message with tool_calls to conversation first
      # - Tool results are added as :tool role messages with specific IDs
      # - Returns boolean indicating if any tools were missing (triggers retry)
      def handle_tool_calls(tool_calls)
        # Record the assistant's tool call request
        @conversation.add_message(LlmTeam::ROLE_ASSISTANT, nil, tool_calls: tool_calls)

        tools_not_found = false

        tool_calls.each do |tool_call|
          function_name = tool_call.dig("function", "name")
          arguments_json = tool_call.dig("function", "arguments")
          arguments = JSON.parse(arguments_json, symbolize_names: true)

          puts "  🔧 #{name} → #{function_name}".magenta
          puts "    Args: #{arguments}".light_black

          # Find tool agent by matching schema function name (not method name)
          tool_agent = @available_tools.values.find { |agent| agent.class.tool_schema[:function][:name] == function_name }

          if tool_agent
            # Execute tool and capture output
            tool_output = execute_tool(tool_agent, function_name, arguments)

            # Add tool result to conversation with proper ID linking
            @conversation.add_message(
              LlmTeam::ROLE_TOOL,
              tool_output.to_s,
              tool_call_id: tool_call["id"],
              name: function_name
            )
          else
            # Handle missing tool gracefully
            error_message = "Error: Tool '#{function_name}' not found."
            puts "  ❌ #{error_message}".red
            @conversation.add_message(
              LlmTeam::ROLE_TOOL,
              error_message,
              tool_call_id: tool_call["id"],
              name: function_name
            )
            tools_not_found = true
          end
        end

        tools_not_found
      end

      # Dynamic tool method invocation with keyword argument spreading
      def execute_tool(tool_agent, function_name, arguments)
        tool_agent.new.public_send(function_name, **arguments)
      end

      # Extract tool execution results from conversation history
      # 
      # Non-obvious behavior:
      # - Maps tool names to their output content for result aggregation
      # - Used by primary agent to collect results from multiple tool calls
      def extract_agent_results_from_history
        @conversation.extract_agent_results_from_history
      end

      # Token usage tracking with per-agent accumulation
      def track_token_usage(response)
        return if response.nil?

        usage = response.dig("usage")
        if usage
          total_tokens = usage["total_tokens"] || 0
          @total_tokens_used += total_tokens

          prompt_tokens = usage["prompt_tokens"] || 0
          completion_tokens = usage["completion_tokens"] || 0

          puts "  📊 Tokens: #{total_tokens} (prompt: #{prompt_tokens}, completion: #{completion_tokens}) | Total: #{@total_tokens_used}".light_black
        end
      end

      # Complete conversation state reset (both ephemeral and persistent)
      def clear_conversation
        @conversation.clear_conversation
        reset_stats
        puts "🧹 #{name} conversation history cleared".green
      end

      # Performance metrics reset for fresh tracking
      def reset_stats
        @total_tokens_used = 0
        @total_latency_ms = 0
        @llm_calls_count = 0
      end

      # Latency formatting helper (ms to seconds)
      def format_latency(latency_ms)
        "#{(latency_ms / 1000.0).round(1)}s"
      end

      private

      # Load auxiliary agents from configured path
      def load_auxiliary_agents
        config = LlmTeam.configuration
        return unless config.auxiliary_agents_path
        
        auxiliary_agents_path = File.expand_path(config.auxiliary_agents_path)
        return unless Dir.exist?(auxiliary_agents_path)
        
        load_auxiliary_agents_from_path(auxiliary_agents_path)
      end

      # Scan directory and load all auxiliary agent files
      def load_auxiliary_agents_from_path(path)
        Dir.glob(File.join(path, "**", "*_agent.rb")).each do |file|
          load_auxiliary_agent_file(file)
        end
      end

      # Load and register a single auxiliary agent file
      def load_auxiliary_agent_file(file)
        begin
          config = LlmTeam.configuration
          auxiliary_agents_path = File.expand_path(config.auxiliary_agents_path)
          
          # Get the relative path from the auxiliary agents directory
          relative_path = file.sub(auxiliary_agents_path + "/", "").gsub(/\.rb$/, "")
          
          # Build namespace from directory structure and filename
          # Examples:
          # "primary_agent/extra_tool_agent.rb" -> ["PrimaryAgent", "ExtraToolAgent"]
          # "primary_agent/extra_tool_agent_subtool_agent.rb" -> ["PrimaryAgent", "ExtraToolAgent", "SubtoolAgent"]
          namespace_parts = relative_path.split("/").map do |part|
            part.split("_").map(&:capitalize).join
          end
          
          # Build full class name
          full_class_name = "LlmTeam::Agents::Auxiliary::#{namespace_parts.join("::")}"
          
          # Check if this auxiliary agent belongs to THIS agent's namespace
          # e.g., PrimaryAgent should only load agents under LlmTeam::Agents::Auxiliary::PrimaryAgent::*
          this_agent_class_name = self.class.name.split("::").last
          expected_namespace_prefix = "LlmTeam::Agents::Auxiliary::#{this_agent_class_name}::"
          
          unless full_class_name.start_with?(expected_namespace_prefix)
            puts "⚠️  Skipping #{File.basename(file)}: Namespace #{full_class_name} doesn't match this agent (#{this_agent_class_name})".yellow
            return
          end
          
          # Only require if namespace matches
          require file
          
          # Check if the expected class exists in the derived namespace
          begin
            agent_class = full_class_name.constantize
          rescue NameError
            puts "⚠️  Skipping #{File.basename(file)}: Expected class #{full_class_name} not found".yellow
            return
          end
          
          if validate_auxiliary_agent_class(agent_class)
            tool_name = agent_class.tool_schema[:function][:name].to_sym
            agent_instance = agent_class.new
            register_tool(tool_name, agent_instance)
            
            puts "✅ Loaded auxiliary agent: #{tool_name} (#{full_class_name})".green
          end
          
        rescue => e
          puts "⚠️  Failed to load #{File.basename(file)}: #{e.message}".yellow
        end
      end

      # Validate that the loaded class is a proper auxiliary agent
      def validate_auxiliary_agent_class(agent_class)
        return false unless agent_class < LlmTeam::Core::Agent
        return false unless agent_class.respond_to?(:tool_schema)
        return false unless agent_class.tool_schema.is_a?(Hash)
        return false unless agent_class.tool_schema.dig(:function, :name)
        true
      rescue
        false
      end
    end
  end
end
