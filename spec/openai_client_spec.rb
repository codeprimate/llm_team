# frozen_string_literal: true

require "spec_helper"

RSpec.describe OpenAIClient do
  let(:config) { test_configuration }
  let(:client) { described_class.new(config) }
  let(:mock_openai_client) { double("OpenAI::Client") }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(mock_openai_client)
  end

  describe "#initialize" do
    it "creates an OpenAI::Client with correct parameters" do
      expect(OpenAI::Client).to receive(:new).with(
        access_token: config.api_key,
        uri_base: config.api_base_url
      )
      described_class.new(config)
    end

    it "stores the OpenAI client" do
      expect(client.instance_variable_get(:@client)).to eq(mock_openai_client)
    end
  end

  describe "#chat" do
    let(:parameters) { {model: "gpt-4", messages: [{role: "user", content: "Hello"}]} }
    let(:expected_response) do
      {
        "choices" => [
          {
            "message" => {
              "content" => "Test response from OpenAI",
              "role" => "assistant"
            }
          }
        ],
        "usage" => {
          "total_tokens" => 100,
          "prompt_tokens" => 50,
          "completion_tokens" => 50
        }
      }
    end

    it "delegates to the OpenAI client" do
      expect(mock_openai_client).to receive(:chat).with(parameters: parameters).and_return(expected_response)
      result = client.chat(parameters: parameters)
      expect(result).to eq(expected_response)
    end
  end
end
