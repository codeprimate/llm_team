# frozen_string_literal: true

require "spec_helper"

RSpec.describe LlmTeam::Core::LlmClientFactory do
  let(:config) { test_configuration }

  describe ".create" do
    context "with openrouter provider" do
      before { config.llm_provider = :openrouter }

      it "creates an OpenRouterClient" do
        client = described_class.create(config)
        expect(client).to be_a(OpenRouterClient)
      end
    end

    context "with openai provider" do
      before { config.llm_provider = :openai }

      it "creates an OpenAIClient" do
        client = described_class.create(config)
        expect(client).to be_a(OpenAIClient)
      end
    end

    context "with ollama provider" do
      before { config.llm_provider = :ollama }

      it "creates an OllamaClient" do
        client = described_class.create(config)
        expect(client).to be_a(OllamaClient)
      end
    end

    context "with unsupported provider" do
      before { config.llm_provider = :unsupported }

      it "raises ConfigurationError" do
        expect { described_class.create(config) }.to raise_error(
          LlmTeam::ConfigurationError,
          "Unsupported LLM provider: unsupported. Supported providers: openrouter, openai, ollama"
        )
      end
    end
  end
end
