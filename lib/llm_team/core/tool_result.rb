# frozen_string_literal: true

module LlmTeam
  module Core
    # Tool execution result container with type safety and validation
    #
    # Key behaviors:
    # - Validates result structure at creation time to prevent invalid combinations
    # - Provides clear success/error state checking with boolean methods
    # - Converts to conversation message format for Agent integration
    # - Handles both success and error cases with proper structure
    class ToolResult
      # Required attributes for all results
      attr_reader :success, :function_name, :tool_call_id

      # Conditional attributes (based on success state)
      attr_reader :output    # Present only when success: true
      attr_reader :error     # Present only when success: false (:tool_not_found, :execution_error, :timeout)
      attr_reader :message   # Present only when success: false

      # Valid error types
      VALID_ERROR_TYPES = [:tool_not_found, :execution_error, :timeout].freeze

      # Create a successful tool result
      #
      # @param function_name [String] The name of the function that was called
      # @param tool_call_id [String] The unique ID of the tool call
      # @param output [String] The output from the tool execution
      # @return [ToolResult] A successful result object
      def self.success(function_name:, tool_call_id:, output:)
        new(
          success: true,
          function_name: function_name,
          tool_call_id: tool_call_id,
          output: output
        )
      end

      # Create an error tool result
      #
      # @param function_name [String] The name of the function that was called
      # @param tool_call_id [String] The unique ID of the tool call
      # @param error [Symbol] The error type (:tool_not_found, :execution_error, :timeout)
      # @param message [String] The error message
      # @return [ToolResult] An error result object
      def self.error(function_name:, tool_call_id:, error:, message:)
        new(
          success: false,
          function_name: function_name,
          tool_call_id: tool_call_id,
          error: error,
          message: message
        )
      end

      # Initialize a tool result with validation
      #
      # @param success [Boolean] Whether the tool execution was successful
      # @param function_name [String] The name of the function that was called
      # @param tool_call_id [String] The unique ID of the tool call
      # @param output [String, nil] The output (required for success case)
      # @param error [Symbol, nil] The error type (required for error case)
      # @param message [String, nil] The error message (required for error case)
      # @raise [ArgumentError] If the result structure is invalid
      def initialize(success:, function_name:, tool_call_id:, output: nil, error: nil, message: nil)
        @success = success
        @function_name = function_name
        @tool_call_id = tool_call_id

        # Validate required fields
        raise ArgumentError, "function_name cannot be nil or empty" if function_name.nil? || function_name.empty?
        raise ArgumentError, "tool_call_id cannot be nil or empty" if tool_call_id.nil? || tool_call_id.empty?

        # Validate success/error state consistency
        if success
          # Success case: must have output, cannot have error fields
          raise ArgumentError, "Success result must have output" if output.nil?
          raise ArgumentError, "Success result cannot have error or message" if error || message
          @output = output
        else
          # Error case: must have error and message, cannot have output
          raise ArgumentError, "Error result must have error type" if error.nil?
          raise ArgumentError, "Error result must have message" if message.nil? || message.empty?
          raise ArgumentError, "Error result cannot have output" if output
          raise ArgumentError, "Invalid error type: #{error}. Must be one of: #{VALID_ERROR_TYPES.join(", ")}" unless VALID_ERROR_TYPES.include?(error)
          @error = error
          @message = message
        end
      end

      # Check if the result represents a successful execution
      #
      # @return [Boolean] True if successful, false otherwise
      def success?
        @success
      end

      # Check if the result represents an error
      #
      # @return [Boolean] True if error, false otherwise
      def error?
        !@success
      end

      # Convert to conversation message format for Agent integration
      #
      # @return [Hash] Conversation message hash compatible with Agent class
      def to_conversation_message
        if success?
          {
            role: LlmTeam::ROLE_TOOL,
            content: @output,
            tool_call_id: @tool_call_id,
            name: @function_name
          }
        else
          {
            role: LlmTeam::ROLE_TOOL,
            content: @message,
            tool_call_id: @tool_call_id,
            name: @function_name
          }
        end
      end

      # String representation for debugging
      #
      # @return [String] Human-readable representation of the result
      def to_s
        if success?
          "ToolResult(success: #{@function_name} -> #{@output.length} chars)"
        else
          "ToolResult(error: #{@function_name} -> #{@error}: #{@message})"
        end
      end

      # Equality comparison
      #
      # @param other [Object] The object to compare with
      # @return [Boolean] True if the results are equal
      def ==(other)
        return false unless other.is_a?(ToolResult)

        @success == other.success &&
          @function_name == other.function_name &&
          @tool_call_id == other.tool_call_id &&
          @output == other.output &&
          @error == other.error &&
          @message == other.message
      end
    end
  end
end
