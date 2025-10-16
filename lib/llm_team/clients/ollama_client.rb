# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "securerandom"

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
    ollama_params = {
      model: params[:model],
      messages: params[:messages],
      temperature: params[:temperature],
      stream: false
    }

    # Include tools if provided (Ollama supports tool calling as of July 2024)
    if params[:tools] && !params[:tools].empty?
      ollama_params[:tools] = params[:tools]
    end

    ollama_params
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
    message = {
      "role" => "assistant",
      "content" => ollama_response["message"]["content"]
    }

    # Handle tool calls if present
    if ollama_response["message"]["tool_calls"]
      message["tool_calls"] = ollama_response["message"]["tool_calls"].map do |tool_call|
        {
          "id" => "call_#{SecureRandom.hex(8)}", # Generate a unique ID
          "type" => "function",
          "function" => {
            "name" => tool_call["function"]["name"],
            "arguments" => tool_call["function"]["arguments"]
          }
        }
      end
    end

    {
      "choices" => [
        {
          "message" => message
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
