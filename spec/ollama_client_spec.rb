# frozen_string_literal: true

require "spec_helper"

RSpec.describe OllamaClient do
  let(:config) { test_configuration }
  let(:client) { described_class.new(config) }

  before do
    config.api_base_url = "http://localhost:11434"
  end

  describe "#initialize" do
    it "stores the base URL" do
      expect(client.instance_variable_get(:@base_url)).to eq("http://localhost:11434")
    end
  end

  describe "#chat" do
    let(:parameters) do
      {
        model: "llama3.1",
        messages: [{role: "user", content: "Hello"}],
        temperature: 0.7
      }
    end

    let(:ollama_response) do
      {
        "message" => {
          "content" => "Hello! How can I help you today?",
          "role" => "assistant"
        }
      }
    end

    let(:expected_openai_format) do
      {
        "choices" => [
          {
            "message" => {
              "role" => "assistant",
              "content" => "Hello! How can I help you today?"
            }
          }
        ],
        "usage" => {
          "total_tokens" => 0,
          "prompt_tokens" => 0,
          "completion_tokens" => 0
        }
      }
    end

    before do
      # Mock the HTTP request
      mock_response = double("HTTP::Response")
      allow(mock_response).to receive(:code).and_return("200")
      allow(mock_response).to receive(:body).and_return(ollama_response.to_json)

      mock_http = double("Net::HTTP")
      allow(mock_http).to receive(:use_ssl=)
      allow(mock_http).to receive(:request).and_return(mock_response)

      allow(Net::HTTP).to receive(:new).and_return(mock_http)
    end

    it "transforms parameters and makes HTTP request" do
      result = client.chat(parameters: parameters)
      expect(result).to eq(expected_openai_format)
    end

    context "when HTTP request fails" do
      before do
        mock_response = double("HTTP::Response")
        allow(mock_response).to receive(:code).and_return("500")
        allow(mock_response).to receive(:body).and_return("Internal Server Error")

        mock_http = double("Net::HTTP")
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:request).and_return(mock_response)

        allow(Net::HTTP).to receive(:new).and_return(mock_http)
      end

      it "raises APIError" do
        expect { client.chat(parameters: parameters) }.to raise_error(
          LlmTeam::APIError,
          "Ollama API error: 500 - Internal Server Error"
        )
      end
    end

    context "when response is invalid JSON" do
      before do
        mock_response = double("HTTP::Response")
        allow(mock_response).to receive(:code).and_return("200")
        allow(mock_response).to receive(:body).and_return("invalid json")

        mock_http = double("Net::HTTP")
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:request).and_return(mock_response)

        allow(Net::HTTP).to receive(:new).and_return(mock_http)
      end

      it "raises APIError" do
        expect { client.chat(parameters: parameters) }.to raise_error(
          LlmTeam::APIError,
          /Invalid JSON response from Ollama/
        )
      end
    end
  end

  describe "private methods" do
    describe "#transform_to_ollama_format" do
      let(:openai_params) do
        {
          model: "llama3.1",
          messages: [{role: "user", content: "Hello"}],
          temperature: 0.7,
          tools: [{type: "function", function: {name: "test_tool"}}]
        }
      end

      it "transforms OpenAI parameters to Ollama format" do
        result = client.send(:transform_to_ollama_format, openai_params)
        expect(result).to eq({
          model: "llama3.1",
          messages: [{role: "user", content: "Hello"}],
          temperature: 0.7,
          stream: false,
          tools: [{type: "function", function: {name: "test_tool"}}]
        })
      end
    end

    describe "#transform_to_openai_format" do
      let(:ollama_response) do
        {
          "message" => {
            "content" => "Test response",
            "role" => "assistant"
          }
        }
      end

      it "transforms Ollama response to OpenAI format" do
        result = client.send(:transform_to_openai_format, ollama_response)
        expect(result).to eq({
          "choices" => [
            {
              "message" => {
                "role" => "assistant",
                "content" => "Test response"
              }
            }
          ],
          "usage" => {
            "total_tokens" => 0,
            "prompt_tokens" => 0,
            "completion_tokens" => 0
          }
        })
      end
    end
  end
end
