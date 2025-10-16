# frozen_string_literal: true

require "spec_helper"

RSpec.describe LlmTeam::Configuration do
  describe "#initialize" do
    context "with default environment" do
      it "sets default provider to openrouter" do
        config = described_class.new
        expect(config.llm_provider).to eq(:openrouter)
      end

      it "uses LLM_TEAM_API_KEY if available" do
        original_key = ENV["LLM_TEAM_API_KEY"]
        original_openrouter_key = ENV["OPENROUTER_API_KEY"]

        ENV["LLM_TEAM_API_KEY"] = "test-key"
        ENV["OPENROUTER_API_KEY"] = nil

        config = described_class.new
        expect(config.api_key).to eq("test-key")

        # Restore original values
        ENV["LLM_TEAM_API_KEY"] = original_key
        ENV["OPENROUTER_API_KEY"] = original_openrouter_key
      end

      it "falls back to OPENROUTER_API_KEY for backward compatibility" do
        original_key = ENV["LLM_TEAM_API_KEY"]
        original_openrouter_key = ENV["OPENROUTER_API_KEY"]

        ENV["LLM_TEAM_API_KEY"] = nil
        ENV["OPENROUTER_API_KEY"] = "legacy-key"

        config = described_class.new
        expect(config.api_key).to eq("legacy-key")

        # Restore original values
        ENV["LLM_TEAM_API_KEY"] = original_key
        ENV["OPENROUTER_API_KEY"] = original_openrouter_key
      end

      it "uses LLM_TEAM_BASE_URL if available" do
        original_base_url = ENV["LLM_TEAM_BASE_URL"]
        original_openrouter_base_url = ENV["OPENROUTER_API_BASE_URL"]

        ENV["LLM_TEAM_BASE_URL"] = "http://custom-base-url"
        ENV["OPENROUTER_API_BASE_URL"] = "http://legacy-base-url"

        config = described_class.new
        expect(config.api_base_url).to eq("http://custom-base-url")

        # Restore original values
        ENV["LLM_TEAM_BASE_URL"] = original_base_url
        ENV["OPENROUTER_API_BASE_URL"] = original_openrouter_base_url
      end

      it "falls back to OPENROUTER_API_BASE_URL for backward compatibility" do
        original_base_url = ENV["LLM_TEAM_BASE_URL"]
        original_openrouter_base_url = ENV["OPENROUTER_API_BASE_URL"]

        ENV["LLM_TEAM_BASE_URL"] = nil
        ENV["OPENROUTER_API_BASE_URL"] = "http://legacy-base-url"

        config = described_class.new
        expect(config.api_base_url).to eq("http://legacy-base-url")

        # Restore original values
        ENV["LLM_TEAM_BASE_URL"] = original_base_url
        ENV["OPENROUTER_API_BASE_URL"] = original_openrouter_base_url
      end
    end

    context "with custom environment variables" do
      it "sets provider from environment" do
        original_provider = ENV["LLM_TEAM_PROVIDER"]

        ENV["LLM_TEAM_PROVIDER"] = "ollama"

        config = described_class.new
        expect(config.llm_provider).to eq(:ollama)

        # Restore original value
        ENV["LLM_TEAM_PROVIDER"] = original_provider
      end

      it "sets base URL from environment" do
        original_base_url = ENV["LLM_TEAM_BASE_URL"]

        ENV["LLM_TEAM_BASE_URL"] = "http://localhost:11434"

        config = described_class.new
        expect(config.api_base_url).to eq("http://localhost:11434")

        # Restore original value
        ENV["LLM_TEAM_BASE_URL"] = original_base_url
      end
    end
  end

  describe "#validate!" do
    let(:config) { described_class.new }

    context "with valid configuration" do
      before do
        config.llm_provider = :openrouter
        config.api_key = "test-key"
      end

      it "does not raise an error" do
        expect { config.validate! }.not_to raise_error
      end
    end

    context "with invalid provider" do
      before do
        config.llm_provider = :invalid
      end

      it "raises ConfigurationError" do
        expect { config.validate! }.to raise_error(
          LlmTeam::ConfigurationError,
          "Invalid LLM provider: invalid. Must be :openrouter, :openai, or :ollama"
        )
      end
    end

    context "with openrouter provider and missing API key" do
      before do
        config.llm_provider = :openrouter
        config.api_key = nil
      end

      it "raises MissingAPIKeyError" do
        expect { config.validate! }.to raise_error(
          LlmTeam::MissingAPIKeyError,
          "API key is required for openrouter provider. Set LLM_TEAM_API_KEY or OPENROUTER_API_KEY environment variable."
        )
      end
    end

    context "with openai provider and missing API key" do
      before do
        config.llm_provider = :openai
        config.api_key = ""
      end

      it "raises MissingAPIKeyError" do
        expect { config.validate! }.to raise_error(
          LlmTeam::MissingAPIKeyError,
          "API key is required for openai provider. Set LLM_TEAM_API_KEY or OPENROUTER_API_KEY environment variable."
        )
      end
    end

    context "with ollama provider" do
      before do
        config.llm_provider = :ollama
        config.api_key = nil # API key not required for Ollama
      end

      it "does not require API key" do
        expect { config.validate! }.not_to raise_error
      end
    end
  end

  describe "#to_hash" do
    let(:config) { described_class.new }

    it "includes llm_provider in the hash" do
      hash = config.to_hash
      expect(hash).to have_key(:llm_provider)
      expect(hash[:llm_provider]).to eq(:openrouter)
    end
  end

  describe "provider-aware default base URLs" do
    it "uses OpenRouter default for openrouter provider" do
      original_provider = ENV["LLM_TEAM_PROVIDER"]
      original_base_url = ENV["LLM_TEAM_BASE_URL"]
      original_openrouter_base_url = ENV["OPENROUTER_API_BASE_URL"]

      ENV["LLM_TEAM_PROVIDER"] = "openrouter"
      ENV["LLM_TEAM_BASE_URL"] = nil
      ENV["OPENROUTER_API_BASE_URL"] = nil

      config = described_class.new
      expect(config.api_base_url).to eq("https://openrouter.ai/api/v1")

      # Restore original values
      ENV["LLM_TEAM_PROVIDER"] = original_provider
      ENV["LLM_TEAM_BASE_URL"] = original_base_url
      ENV["OPENROUTER_API_BASE_URL"] = original_openrouter_base_url
    end

    it "uses OpenRouter default for openai provider" do
      original_provider = ENV["LLM_TEAM_PROVIDER"]
      original_base_url = ENV["LLM_TEAM_BASE_URL"]
      original_openrouter_base_url = ENV["OPENROUTER_API_BASE_URL"]

      ENV["LLM_TEAM_PROVIDER"] = "openai"
      ENV["LLM_TEAM_BASE_URL"] = nil
      ENV["OPENROUTER_API_BASE_URL"] = nil

      config = described_class.new
      expect(config.api_base_url).to eq("https://openrouter.ai/api/v1")

      # Restore original values
      ENV["LLM_TEAM_PROVIDER"] = original_provider
      ENV["LLM_TEAM_BASE_URL"] = original_base_url
      ENV["OPENROUTER_API_BASE_URL"] = original_openrouter_base_url
    end

    it "uses Ollama default for ollama provider" do
      original_provider = ENV["LLM_TEAM_PROVIDER"]
      original_base_url = ENV["LLM_TEAM_BASE_URL"]
      original_openrouter_base_url = ENV["OPENROUTER_API_BASE_URL"]

      ENV["LLM_TEAM_PROVIDER"] = "ollama"
      ENV["LLM_TEAM_BASE_URL"] = nil
      ENV["OPENROUTER_API_BASE_URL"] = nil

      config = described_class.new
      expect(config.api_base_url).to eq("http://localhost:11434")

      # Restore original values
      ENV["LLM_TEAM_PROVIDER"] = original_provider
      ENV["LLM_TEAM_BASE_URL"] = original_base_url
      ENV["OPENROUTER_API_BASE_URL"] = original_openrouter_base_url
    end

    it "falls back to OpenRouter default for unknown provider" do
      original_provider = ENV["LLM_TEAM_PROVIDER"]
      original_base_url = ENV["LLM_TEAM_BASE_URL"]
      original_openrouter_base_url = ENV["OPENROUTER_API_BASE_URL"]

      ENV["LLM_TEAM_PROVIDER"] = "unknown"
      ENV["LLM_TEAM_BASE_URL"] = nil
      ENV["OPENROUTER_API_BASE_URL"] = nil

      config = described_class.new
      expect(config.api_base_url).to eq("https://openrouter.ai/api/v1")

      # Restore original values
      ENV["LLM_TEAM_PROVIDER"] = original_provider
      ENV["LLM_TEAM_BASE_URL"] = original_base_url
      ENV["OPENROUTER_API_BASE_URL"] = original_openrouter_base_url
    end
  end
end
