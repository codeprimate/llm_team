# frozen_string_literal: true

require "spec_helper"

RSpec.describe "LLM Client Provider Integration" do
  describe "OpenRouter provider" do
    let(:config) { test_configuration }
    let(:client) { LlmTeam::Core::LlmClientFactory.create(config) }

    before do
      config.llm_provider = :openrouter
      config.api_key = "test-key"
      config.api_base_url = "https://openrouter.ai/api/v1"
    end

    it "creates the correct client type" do
      expect(client).to be_a(OpenRouterClient)
    end

    it "can be used by an agent" do
      # Temporarily override the global configuration
      original_config = LlmTeam.configuration
      LlmTeam.instance_variable_set(:@configuration, config)

      agent = LlmTeam::Core::Agent.new("TestAgent")
      expect(agent.llm_client).to be_a(OpenRouterClient)

      # Restore original configuration
      LlmTeam.instance_variable_set(:@configuration, original_config)
    end
  end

  describe "Ollama provider" do
    let(:config) { test_configuration }
    let(:client) { LlmTeam::Core::LlmClientFactory.create(config) }

    before do
      config.llm_provider = :ollama
      config.api_base_url = "http://localhost:11434"
      config.model = "llama3.1"
    end

    it "creates the correct client type" do
      expect(client).to be_a(OllamaClient)
    end

    it "can be used by an agent" do
      # Temporarily override the global configuration
      original_config = LlmTeam.configuration
      LlmTeam.instance_variable_set(:@configuration, config)

      agent = LlmTeam::Core::Agent.new("TestAgent")
      expect(agent.llm_client).to be_a(OllamaClient)

      # Restore original configuration
      LlmTeam.instance_variable_set(:@configuration, original_config)
    end
  end

  describe "Configuration integration" do
    it "supports environment variable configuration" do
      # Test with OpenRouter
      allow(ENV).to receive(:fetch).with("LLM_TEAM_PROVIDER", anything).and_return("openrouter")
      allow(ENV).to receive(:[]).with("LLM_TEAM_API_KEY").and_return("test-key")
      allow(ENV).to receive(:fetch).and_call_original

      config = LlmTeam::Configuration.new
      expect(config.llm_provider).to eq(:openrouter)
      expect(config.api_key).to eq("test-key")

      client = LlmTeam::Core::LlmClientFactory.create(config)
      expect(client).to be_a(OpenRouterClient)
    end

    it "supports backward compatibility with OPENROUTER_API_KEY" do
      allow(ENV).to receive(:[]).with("LLM_TEAM_API_KEY").and_return(nil)
      allow(ENV).to receive(:[]).with("OPENROUTER_API_KEY").and_return("legacy-key")
      allow(ENV).to receive(:fetch).and_call_original

      config = LlmTeam::Configuration.new
      expect(config.api_key).to eq("legacy-key")
    end
  end

  describe "Error handling" do
    it "handles unsupported providers gracefully" do
      config = test_configuration
      config.llm_provider = :unsupported

      expect { LlmTeam::Core::LlmClientFactory.create(config) }.to raise_error(
        LlmTeam::ConfigurationError,
        /Unsupported LLM provider/
      )
    end

    it "validates configuration before creating clients" do
      config = test_configuration
      config.llm_provider = :openrouter
      config.api_key = nil

      expect { config.validate! }.to raise_error(LlmTeam::MissingAPIKeyError)
    end
  end
end
