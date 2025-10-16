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
    response = @client.chat(parameters: parameters)
    transform_tool_call_arguments(response)
  end

  private

  # Transform tool call arguments from JSON strings to Hash objects
  #
  # @param response [Hash] The raw response from OpenAI client
  # @return [Hash] Response with transformed tool call arguments
  def transform_tool_call_arguments(response)
    return response unless response.dig("choices", 0, "message", "tool_calls")

    response["choices"][0]["message"]["tool_calls"].each do |tool_call|
      if tool_call.dig("function", "arguments").is_a?(String)
        tool_call["function"]["arguments"] = JSON.parse(tool_call["function"]["arguments"])
      end
    end

    response
  end
end
