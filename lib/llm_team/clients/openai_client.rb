# frozen_string_literal: true

require "ruby/openai"

# OpenAI client implementation
#
# This client connects directly to OpenAI's API for models like GPT-4, GPT-3.5, etc.
# It uses the same OpenAI::Client as OpenRouter but with OpenAI's endpoint.
class OpenAIClient < LlmTeam::Core::LlmClient
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
