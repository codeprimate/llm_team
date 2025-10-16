# frozen_string_literal: true

require "ruby/openai"

# OpenRouter/OpenAI client implementation
#
# This client wraps the existing OpenAI::Client to provide a consistent
# interface while maintaining backward compatibility with the current
# OpenRouter integration.
class OpenRouterClient < LlmTeam::Core::LlmClient
  def initialize(config)
    super
    @client = OpenAI::Client.new(
      access_token: config.api_key,
      uri_base: config.api_base_url
    )
  end
  
  # Make a chat completion request using the OpenAI client
  #
  # @param parameters [Hash] The parameters for the chat completion
  # @return [Hash] Response hash with "choices" and "usage" keys
  def chat(parameters:)
    @client.chat(parameters: parameters)
  end
end
