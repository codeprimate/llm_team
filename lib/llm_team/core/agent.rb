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
      attr_reader :name, :llm_client, :available_tools, :conversation, :max_iterations, :current_iteration, :total_tool_calls

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
        @total_tool_calls = 0
        @current_iteration = nil

        # Always auto-load auxiliary agents
        load_auxiliary_agents
      end

      # Dynamic system prompt resolution - subclasses can define SYSTEM_PROMPT constant
      def system_prompt
        base_prompt = self.class.const_defined?(:SYSTEM_PROMPT) ? self.class::SYSTEM_PROMPT : nil
        return base_prompt unless @current_iteration

        # Prepend combined header when current_iteration is set
        header = "--- [#{agent_namespace}] Iteration #{@current_iteration.to_s.rjust(2, "0")}/#{@max_iterations.to_s.rjust(2, "0")} | Tool Calls: #{@total_tool_calls} ---\n\n"
        header + (base_prompt || "")
      end

      # Dynamic tool prompt resolution - subclasses can define TOOL_PROMPT constant
      def tool_prompt
        (self.class.const_defined?(:TOOL_PROMPT) ? self.class::TOOL_PROMPT : nil)
      end

      # Dynamic tool prompt resolution for registered tools
      def registered_tool_prompts
        @available_tools.values.map(&:tool_prompt).compact.join("\n")
      end

      # Generate agent namespace for iteration header
      def agent_namespace
        # Extract the relevant parts of the class name
        # Examples:
        # "LlmTeam::Agents::Core::PrimaryAgent" -> "PrimaryAgent"
        # "LlmTeam::Agents::Auxiliary::ResearchAgent::SymbolicMathAgent" -> "ResearchAgent::SymbolicMathAgent"
        class_name = self.class.name

        # Remove the base LlmTeam::Agents:: prefix
        if class_name.start_with?("LlmTeam::Agents::")
          namespace = class_name.sub("LlmTeam::Agents::", "")

          # For auxiliary agents, remove "Auxiliary::" but keep the parent::child structure
          if namespace.start_with?("Auxiliary::")
            # "Auxiliary::ResearchAgent::SymbolicMathAgent" -> "ResearchAgent::SymbolicMathAgent"
            namespace = namespace.sub("Auxiliary::", "")
          elsif namespace.start_with?("Core::")
            # "Core::PrimaryAgent" -> "PrimaryAgent"
            namespace = namespace.sub("Core::", "")
          end

          namespace
        else
          # Fallback to just the class name if it doesn't match expected pattern
          class_name.split("::").last
        end
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

        # Reset tool calls counter for this processing session
        @total_tool_calls = 0

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
          @current_iteration = iteration
          LlmTeam::Output.puts("#{name} - Iteration #{iteration}", type: :workflow)

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
            LlmTeam::Output.puts("#{name} failed to get valid response after retries", type: :error)
            return "Error: No response from LLM API after retries"
          end

          message = response.dig("choices", 0, "message")

          # Check if message is valid
          if message.nil?
            LlmTeam::Output.puts("#{name} received nil message from LLM response", type: :error)
            LlmTeam::Output.puts("Response structure: #{response.inspect}", type: :debug)
            return "Error: Invalid response structure from LLM"
          end

          if message["tool_calls"]
            # Execute tools and detect missing tool errors
            tools_not_found = handle_tool_calls(message["tool_calls"])

            # Retry mechanism: undo iteration increment and remove failed assistant message
            if tools_not_found
              LlmTeam::Output.puts("Retrying iteration due to tool not found errors", type: :retry)
              iteration -= 1  # Rewind iteration counter
              @current_iteration = iteration  # Update current_iteration to match
              # @conversation_history.pop  # Remove the failed assistant message
              next
            end
          elsif message["content"]
            # Final response
            @conversation.add_message(
              normalize_role(message["role"]),
              message["content"]
            )
            LlmTeam::Output.puts("#{name} completed with response", type: :status)
            LlmTeam::Output.puts("Total latency: #{format_latency(@total_latency_ms)} (#{@llm_calls_count} LLM calls)", type: :performance)
            LlmTeam::Output.puts(message["content"], type: :data, color: :light_black)
            LlmTeam::Output.puts("─" * 50, type: :data, color: :light_black)

            # Apply history cleanup based on behavior
            @conversation.cleanup_conversation_history(history_behavior)

            # Reset iteration tracking
            @current_iteration = nil
            return message["content"]
          else
            LlmTeam::Output.puts("#{name} received no tool call or content", type: :warning)
            @current_iteration = nil
            return "No response generated."
          end
        end

        LlmTeam::Output.puts("#{name} reached max iterations (#{current_max_iterations})", type: :warning)

        # Reset iteration tracking
        @current_iteration = nil

        # Extract and return information gathered during iterations
        gathered_information = extract_gathered_information

        # Apply history cleanup based on behavior even when max iterations reached
        @conversation.cleanup_conversation_history(history_behavior)

        if gathered_information.any?
          LlmTeam::Output.puts("#{name} returning gathered information from #{gathered_information.size} sources", type: :status)
          format_gathered_information(gathered_information)
        else
          "Max iterations reached without response."
        end
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
            LlmTeam::Output.puts("Retrying LLM call (#{retry_count}/#{max_retries})...", type: :retry)
            sleep(1)  # Fixed delay - could be exponential
          else
            LlmTeam::Output.puts("Max retries (#{max_retries}) exceeded", type: :error)
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
        LlmTeam::Output.puts("Calling LLM (#{messages.size} messages)", type: :technical)
        LlmTeam::Output.puts("Tools: #{tools.any? ? tools.map { |t| t[:function][:name] }.join(", ") : "None"}", type: :debug)

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
          LlmTeam::Output.puts("LLM API Error: #{e.class} - #{e.message}", type: :error)
          LlmTeam::Output.puts("Request params: #{request_params.inspect}", type: :debug)
          return nil
        end

        end_time = Time.now

        # Accumulate performance metrics
        latency_ms = ((end_time - start_time) * 1000).round(2)
        @total_latency_ms += latency_ms
        @llm_calls_count += 1

        LlmTeam::Output.puts("Latency: #{format_latency(latency_ms)} | Total: #{format_latency(@total_latency_ms)} (#{@llm_calls_count} calls)", type: :performance)

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

          # Increment tool calls counter
          @total_tool_calls += 1

          LlmTeam::Output.puts("#{name} → #{function_name}", type: :tool)
          LlmTeam::Output.puts("Args: #{arguments}", type: :debug)

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
            LlmTeam::Output.puts(error_message, type: :error)
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
        tool_agent.public_send(function_name, **arguments)
      end

      # Extract tool execution results from conversation history
      #
      # Non-obvious behavior:
      # - Maps tool names to their output content for result aggregation
      # - Used by primary agent to collect results from multiple tool calls
      def extract_agent_results_from_history
        @conversation.extract_agent_results_from_history
      end

      # Extract information gathered during iterations when max iterations is reached
      #
      # Non-obvious behavior:
      # - Collects tool results and assistant responses that contain substantive information
      # - Filters out system messages, datetime injections, and empty responses
      # - Returns array of information chunks for formatting
      def extract_gathered_information
        information = []

        @conversation.conversation_history.each do |message|
          case message[:role]
          when LlmTeam::ROLE_TOOL
            # Tool results often contain the most valuable information
            content = message[:content].to_s.strip
            if content.length > 10 && !content.include?("Error:")
              information << {
                type: :tool_result,
                source: message[:name],
                content: content
              }
            end
          when LlmTeam::ROLE_ASSISTANT
            # Assistant responses with content (not tool calls)
            if message[:content] && !message[:tool_calls] && !message[:content].include?("current date and time")
              content = message[:content].strip
              if content.length > 20
                information << {
                  type: :assistant_response,
                  source: "assistant",
                  content: content
                }
              end
            end
          end
        end

        information
      end

      # Format gathered information into a coherent response
      #
      # Non-obvious behavior:
      # - Groups information by source and type for better organization
      # - Provides clear structure for the user to understand what was found
      # - Includes context about the max iterations limitation
      def format_gathered_information(information)
        return "No information gathered." if information.empty?

        formatted_parts = []
        formatted_parts << "**Information gathered before reaching max iterations:**\n"

        # Group by source for better organization
        grouped_info = information.group_by { |info| info[:source] }

        grouped_info.each do |source, items|
          formatted_parts << "\n**From #{source}:**"
          items.each_with_index do |item, index|
            formatted_parts << "\n#{index + 1}. #{item[:content]}"
          end
        end

        formatted_parts << "\n\n*Note: This information was gathered before reaching the maximum iteration limit. Additional investigation may be needed for complete coverage.*"

        formatted_parts.join
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

          LlmTeam::Output.puts("Tokens: #{total_tokens} (prompt: #{prompt_tokens}, completion: #{completion_tokens}) | Total: #{@total_tokens_used}", type: :data)
        end
      end

      # Complete conversation state reset (both ephemeral and persistent)
      def clear_conversation
        @conversation.clear_conversation
        reset_stats
        LlmTeam::Output.puts("#{name} conversation history cleared", type: :debug, color: :green)
      end

      # Performance metrics reset for fresh tracking
      def reset_stats
        @total_tokens_used = 0
        @total_latency_ms = 0
        @llm_calls_count = 0
        @total_tool_calls = 0
      end

      # Latency formatting helper (ms to seconds)
      def format_latency(latency_ms)
        "#{(latency_ms / 1000.0).round(1)}s"
      end

      private

      # Load auxiliary agents from configured paths
      def load_auxiliary_agents
        config = LlmTeam.configuration
        return unless config.auxiliary_agents_paths&.any?

        config.auxiliary_agents_paths.each do |path|
          auxiliary_agents_path = File.expand_path(path)
          next unless Dir.exist?(auxiliary_agents_path)

          load_auxiliary_agents_from_path(auxiliary_agents_path)
        end
      end

      # Scan directory and load all auxiliary agent files
      def load_auxiliary_agents_from_path(path)
        Dir.glob(File.join(path, "**", "*_agent.rb")).each do |file|
          load_auxiliary_agent_file(file, path)
        end
      end

      # Load and register a single auxiliary agent file
      def load_auxiliary_agent_file(file, base_path)
        auxiliary_agents_path = File.expand_path(base_path)

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
          return
        end

        # Only require if namespace matches
        require file

        # Check if the expected class exists in the derived namespace
        begin
          agent_class = Object.const_get(full_class_name)
        rescue NameError
          LlmTeam::Output.puts("Skipping #{File.basename(file)}: Expected class #{full_class_name} not found", type: :warning)
          return
        end

        if validate_auxiliary_agent_class(agent_class)
          tool_name = agent_class.tool_schema[:function][:name].to_sym
          agent_instance = agent_class.new
          register_tool(tool_name, agent_instance)

          LlmTeam::Output.puts("Loaded auxiliary agent: #{tool_name} (#{full_class_name})", type: :debug, color: :green)
        end
      rescue => e
        LlmTeam::Output.puts("Failed to load #{File.basename(file)}: #{e.message}", type: :warning)
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
