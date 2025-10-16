# frozen_string_literal: true

module LlmTeam
  module Core
    # Abstract base class for all LLM client implementations
    #
    # This class defines the common interface that all LLM providers must implement.
    # It ensures consistent behavior across different providers while allowing
    # provider-specific implementations.
    class LlmClient
      def initialize(config)
        @config = config
      end

      # Main method for making chat completions to the LLM
      #
      # @param parameters [Hash] The parameters for the chat completion
      # @option parameters [String] :model The model to use
      # @option parameters [Array] :messages Array of message hashes
      # @option parameters [Float] :temperature Temperature setting (0.0-2.0)
      # @option parameters [Array] :tools Array of tool definitions (optional)
      # @option parameters [Symbol,String] :tool_choice Tool choice setting (optional)
      # @return [Hash] Response hash with "choices" and "usage" keys
      def chat(parameters:)
        raise NotImplementedError, "Subclasses must implement #chat"
      end
    end
  end
end
