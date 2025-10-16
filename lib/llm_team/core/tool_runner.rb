# frozen_string_literal: true

module LlmTeam
  module Core
    # Tool execution engine with sequential and parallel execution capabilities
    #
    # Key behaviors:
    # - Extracts tool execution logic from Agent class for better separation of concerns
    # - Supports both sequential and parallel execution strategies
    # - Maintains tool call counting and metrics tracking
    # - Provides structured error handling and result processing
    # - Does NOT manage conversation state (Agent's responsibility)
    class ToolRunner
      attr_reader :total_tool_calls

      # Initialize ToolRunner with configuration
      #
      # @param config [LlmTeam::Configuration] Configuration object containing tool execution settings
      def initialize(config)
        @config = config
        @total_tool_calls = 0
      end

      # Execute tool calls using appropriate strategy (sequential or parallel)
      #
      # @param tool_calls [Array<Hash>] Array of tool call objects from LLM
      # @param available_tools [Hash] Hash of available tool agents (name => agent_instance)
      # @return [Array<ToolResult>] Array of ToolResult objects in execution order
      def execute_tool_calls(tool_calls, available_tools)
        return [] if tool_calls.nil? || tool_calls.empty?

        # Choose execution strategy based on tool count and configuration
        if should_run_parallel?(tool_calls)
          run_tools_parallel(tool_calls, available_tools)
        else
          run_tools_sequential(tool_calls, available_tools)
        end
      end

      # Reset tool call counter
      #
      # @return [void]
      def reset_tool_call_count
        @total_tool_calls = 0
      end

      private

      # Execute tool calls sequentially (one at a time)
      #
      # @param tool_calls [Array<Hash>] Array of tool call objects
      # @param available_tools [Hash] Hash of available tool agents
      # @return [Array<ToolResult>] Array of ToolResult objects in execution order
      def run_tools_sequential(tool_calls, available_tools)
        results = []

        tool_calls.each do |tool_call|
          result = run_single_tool(tool_call, available_tools)
          results << result
        end

        results
      end

      # Execute tool calls in parallel using thread pool
      #
      # @param tool_calls [Array<Hash>] Array of tool call objects
      # @param available_tools [Hash] Hash of available tool agents
      # @return [Array<ToolResult>] Array of ToolResult objects in original order
      def run_tools_parallel(tool_calls, available_tools)
        require "concurrent"

        # Create fixed-size thread pool for controlled concurrency
        max_concurrent = @config.respond_to?(:max_concurrent_tools) ? @config.max_concurrent_tools : 3
        thread_pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 1,
          max_threads: max_concurrent,
          max_queue: tool_calls.length,
          auto_terminate: true
        )

        begin
          # Submit all tool calls to thread pool with staggered start times
          # Store tool call info with each future for proper error handling
          future_tool_pairs = tool_calls.map.with_index do |tool_call, index|
            # Calculate jitter for staggered start times
            jitter = calculate_start_jitter(index)

            # Submit tool execution to thread pool
            future = Concurrent::Future.execute(executor: thread_pool) do
              # Apply jitter delay if configured
              sleep(jitter) if jitter > 0

              # Execute tool with error isolation
              run_single_tool(tool_call, available_tools)
            end

            # Return both future and tool_call for proper error handling
            [future, tool_call]
          end

          # Collect results as they complete, maintaining original order
          results = future_tool_pairs.map do |future, tool_call|
            # Wait for result with timeout
            timeout = @config.respond_to?(:tool_execution_timeout) ? @config.tool_execution_timeout : 60
            result = future.value(timeout)
            result
          rescue Concurrent::TimeoutError
            # Create timeout result with proper tool call information
            create_timeout_result(tool_call)
          rescue => e
            # Create error result with proper tool call information
            create_error_result(tool_call, e.message)
          end

          results
        ensure
          # Ensure proper cleanup of thread pool
          thread_pool.shutdown
          thread_pool.wait_for_termination(5) # Wait up to 5 seconds for cleanup
        end
      end

      # Determine if tools should run in parallel
      #
      # @param tool_calls [Array<Hash>] Array of tool call objects
      # @return [Boolean] True if parallel execution should be used
      def should_run_parallel?(tool_calls)
        # Return false for single tool calls
        return false if tool_calls.length <= 1

        # Return false if concurrency is disabled (max_concurrent_tools <= 1)
        max_concurrent = @config.respond_to?(:max_concurrent_tools) ? @config.max_concurrent_tools : 3
        return false if max_concurrent <= 1

        # Return true for multiple tools with concurrency enabled
        true
      end

      # Calculate start jitter for staggered tool execution
      #
      # @param index [Integer] Index of the tool call
      # @return [Float] Jitter delay in seconds
      def calculate_start_jitter(index)
        # Return 0 if jitter is disabled
        jitter_max = @config.respond_to?(:tool_start_jitter_max) ? @config.tool_start_jitter_max : 1.0
        return 0.0 if jitter_max <= 0

        # Use index-based staggering (0.1s increments) for consistent distribution
        base_jitter = index * 0.1

        # Add random component (0-0.2s) to prevent predictable patterns
        random_jitter = rand(0.0..0.2)

        # Cap total jitter at configured maximum
        total_jitter = base_jitter + random_jitter
        [total_jitter, jitter_max].min
      end

      # Create timeout result for tool call
      #
      # @param tool_call [Hash] Tool call object
      # @return [ToolResult] Timeout error result
      def create_timeout_result(tool_call)
        function_name = tool_call.dig("function", "name") || "unknown"
        tool_call_id = tool_call["id"] || "timeout"

        ToolResult.error(
          function_name: function_name,
          tool_call_id: tool_call_id,
          error: :timeout,
          message: "Tool execution timed out"
        )
      end

      # Create error result for tool call
      #
      # @param tool_call [Hash] Tool call object
      # @param error_message [String] Error message
      # @return [ToolResult] Error result
      def create_error_result(tool_call, error_message)
        function_name = tool_call.dig("function", "name") || "unknown"
        tool_call_id = tool_call["id"] || "error"

        ToolResult.error(
          function_name: function_name,
          tool_call_id: tool_call_id,
          error: :execution_error,
          message: error_message
        )
      end

      # Execute a single tool call
      #
      # @param tool_call [Hash] Single tool call object
      # @param available_tools [Hash] Hash of available tool agents
      # @return [ToolResult] ToolResult object representing the execution outcome
      def run_single_tool(tool_call, available_tools)
        function_name = tool_call.dig("function", "name")
        arguments_json = tool_call.dig("function", "arguments")
        tool_call_id = tool_call["id"]

        # Increment tool calls counter
        @total_tool_calls += 1

        # Parse arguments from JSON
        begin
          arguments = JSON.parse(arguments_json, symbolize_names: true)
        rescue JSON::ParserError => e
          return ToolResult.error(
            function_name: function_name,
            tool_call_id: tool_call_id,
            error: :execution_error,
            message: "Failed to parse tool arguments: #{e.message}"
          )
        end

        # Find tool agent by matching schema function name (not method name)
        tool_agent = available_tools.values.find { |agent| agent.class.tool_schema[:function][:name] == function_name }

        unless tool_agent
          return ToolResult.error(
            function_name: function_name,
            tool_call_id: tool_call_id,
            error: :tool_not_found,
            message: "Tool '#{function_name}' not found"
          )
        end

        # Execute tool with error handling
        begin
          tool_output = execute_tool(tool_agent, function_name, arguments)
          processed_output = process_tool_result(tool_output)

          ToolResult.success(
            function_name: function_name,
            tool_call_id: tool_call_id,
            output: processed_output
          )
        rescue => e
          ToolResult.error(
            function_name: function_name,
            tool_call_id: tool_call_id,
            error: :execution_error,
            message: "Tool execution failed: #{e.message}"
          )
        end
      end

      # Execute tool method on agent with keyword argument spreading
      #
      # @param tool_agent [Object] The tool agent instance
      # @param function_name [String] The name of the function to call
      # @param arguments [Hash] The arguments to pass to the function
      # @return [String] The tool output
      def execute_tool(tool_agent, function_name, arguments)
        tool_agent.public_send(function_name, **arguments)
      end

      # Process tool result with truncation if needed
      #
      # @param output [String] The raw tool output
      # @return [String] The processed tool output
      def process_tool_result(output)
        max_length = @config.max_tool_call_response_length

        if output.length > max_length
          truncated_output = output[0, max_length]
          truncated_output + "\n---\n[TOOL OUTPUT TRUNCATED]\n---\n"
        else
          output
        end
      end
    end
  end
end
