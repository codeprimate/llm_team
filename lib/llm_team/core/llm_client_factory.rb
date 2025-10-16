# frozen_string_literal: true

module LlmTeam
  module Core
    # Factory class for creating provider-specific LLM clients
    #
    # This factory handles the creation of appropriate LLM client instances
    # based on the configured provider. It provides a clean abstraction
    # for switching between different LLM providers.
    class LlmClientFactory
      # Create an LLM client instance based on the configuration
      #
      # @param config [LlmTeam::Configuration] The configuration object
      # @return [LlmTeam::Core::LlmClient] An instance of the appropriate client
      # @raise [LlmTeam::ConfigurationError] If the provider is not supported
      def self.create(config)
        case config.llm_provider
        when :openrouter, :openai
          require_relative "../clients/openrouter_client"
          OpenRouterClient.new(config)
        when :ollama
          require_relative "../clients/ollama_client"
          OllamaClient.new(config)
        else
          raise LlmTeam::ConfigurationError, "Unsupported LLM provider: #{config.llm_provider}. Supported providers: openrouter, openai, ollama"
        end
      end
    end
  end
end
