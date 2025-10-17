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
    # Don't transform error responses - let them flow through to agent error handling
    return response if response["error"]
    return response unless response.dig("choices", 0, "message", "tool_calls")

    response["choices"][0]["message"]["tool_calls"].each do |tool_call|
      args = tool_call.dig("function", "arguments")
      if args.is_a?(String)
        begin
          tool_call["function"]["arguments"] = JSON.parse(args)
        rescue JSON::ParserError
          # Keep as string if invalid JSON - ToolRunner will handle the error
          # This prevents crashes but allows proper error reporting downstream
        end
      end
    end

    response
  end
end
