# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# Ollama client implementation
#
# This client implements the Ollama API for local LLM inference.
# It transforms OpenAI-compatible requests to Ollama format and
# normalizes responses back to the expected format.
class OllamaClient < LlmTeam::Core::LlmClient
  def initialize(config)
    super
    @base_url = config.api_base_url
  end

  # Make a chat completion request using the Ollama API
  #
  # @param parameters [Hash] The parameters for the chat completion
  # @return [Hash] Response hash with "choices" and "usage" keys
  def chat(parameters:)
    ollama_params = transform_to_ollama_format(parameters)
    response = make_ollama_request(ollama_params)
    transform_to_openai_format(response)
  end

  private

  # Transform OpenAI-compatible parameters to Ollama format
  #
  # @param params [Hash] OpenAI-compatible parameters
  # @return [Hash] Ollama-compatible parameters
  def transform_to_ollama_format(params)
    {
      model: params[:model],
      messages: params[:messages],
      temperature: params[:temperature],
      stream: false
      # Note: Ollama tool calling is handled differently and may not be supported
      # in all models. For now, we'll skip tool parameters.
    }
  end

  # Make HTTP request to Ollama API
  #
  # @param params [Hash] Ollama-compatible parameters
  # @return [Hash] Raw Ollama response
  def make_ollama_request(params)
    uri = URI("#{@base_url}/api/chat")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"

    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = params.to_json

    response = http.request(request)

    if response.code.to_i == 200
      JSON.parse(response.body)
    else
      raise LlmTeam::APIError, "Ollama API error: #{response.code} - #{response.body}"
    end
  rescue JSON::ParserError => e
    raise LlmTeam::APIError, "Invalid JSON response from Ollama: #{e.message}"
  rescue LlmTeam::APIError
    # Re-raise API errors as-is
    raise
  rescue => e
    raise LlmTeam::APIError, "Ollama request failed: #{e.message}"
  end

  # Transform Ollama response to OpenAI-compatible format
  #
  # @param ollama_response [Hash] Raw Ollama response
  # @return [Hash] OpenAI-compatible response
  def transform_to_openai_format(ollama_response)
    {
      "choices" => [
        {
          "message" => {
            "role" => "assistant",
            "content" => ollama_response["message"]["content"]
          }
        }
      ],
      "usage" => {
        "total_tokens" => 0, # Ollama doesn't provide token counts
        "prompt_tokens" => 0,
        "completion_tokens" => 0
      }
    }
  end
end
