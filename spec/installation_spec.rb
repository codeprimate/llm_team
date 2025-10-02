# frozen_string_literal: true

require "spec_helper"

RSpec.describe "LlmTeam Installation" do
  describe "gem loading" do
    it "loads the gem successfully" do
      expect { require "llm_team" }.not_to raise_error
    end

    it "provides version information" do
      expect(LlmTeam::VERSION).to be_a(String)
      expect(LlmTeam::VERSION).not_to be_empty
    end

    it "loads all core modules" do
      expect(LlmTeam).to be_a(Module)
      expect(LlmTeam::Configuration).to be_a(Class)
      expect(LlmTeam::CLI::Application).to be_a(Class)
    end
  end

  describe "dependency loading" do
    it "loads required external dependencies" do
      expect { require "ruby/openai" }.not_to raise_error
      expect { require "json" }.not_to raise_error
      expect { require "colorize" }.not_to raise_error
    end

    it "loads core classes" do
      expect(LlmTeam::Core::Conversation).to be_a(Class)
      expect(LlmTeam::Core::Agent).to be_a(Class)
    end

    it "loads agent classes" do
      expect(LlmTeam::Agents::Core::ResearchAgent).to be_a(Class)
      expect(LlmTeam::Agents::Core::CriticAgent).to be_a(Class)
      expect(LlmTeam::Agents::Core::PresenterAgent).to be_a(Class)
      expect(LlmTeam::Agents::Core::PrimaryAgent).to be_a(Class)
    end
  end

  describe "configuration access" do
    it "provides global configuration" do
      expect(LlmTeam.configuration).to be_a(LlmTeam::Configuration)
    end

    it "allows configuration via DSL" do
      expect { LlmTeam.configure { |config| } }.not_to raise_error
    end

    it "maintains configuration state" do
      original_config = LlmTeam.configuration
      LlmTeam.configure do |config|
        config.api_key = "test-key"
      end

      expect(LlmTeam.configuration.api_key).to eq("test-key")
      expect(LlmTeam.configuration).to be(original_config)
    end
  end

  describe "CLI functionality" do
    it "can instantiate CLI application" do
      expect { LlmTeam::CLI::Application.new }.not_to raise_error
    end

    it "provides CLI application with required methods" do
      cli = LlmTeam::CLI::Application.new
      expect(cli).to respond_to(:run)
    end
  end

  describe "error handling" do
    it "defines all required error classes" do
      expect(LlmTeam::MissingAPIKeyError).to be < StandardError
      expect(LlmTeam::ConfigurationError).to be < StandardError
      expect(LlmTeam::APIError).to be < StandardError
      expect(LlmTeam::AgentError).to be < StandardError
    end

    it "handles configuration errors gracefully" do
      config = LlmTeam::Configuration.new
      config.api_key = nil

      expect { config.validate! }.to raise_error(LlmTeam::MissingAPIKeyError)
    end
  end

  describe "auxiliary agent system" do
    it "can access auxiliary agent paths" do
      config = LlmTeam::Configuration.new
      expect(config.auxiliary_agents_paths).to be_an(Array)
      expect(config.auxiliary_agents_paths).not_to be_empty
    end

    it "can add auxiliary agent paths" do
      config = LlmTeam::Configuration.new
      initial_count = config.auxiliary_agents_paths.length

      config.add_auxiliary_agents_path("/test/path")

      expect(config.auxiliary_agents_paths.length).to eq(initial_count + 1)
      expect(config.auxiliary_agents_paths).to include("/test/path")
    end
  end

  describe "integration with existing functionality" do
    it "can create configuration with test values" do
      config = test_configuration
      expect(config.api_key).to eq("test-api-key")
      expect(config.model).to eq("test-model")
      expect(config.verbose).to be false
      expect(config.quiet).to be true
    end

    it "validates configuration with test values" do
      config = test_configuration
      expect { config.validate! }.not_to raise_error
    end

    it "can serialize configuration to hash" do
      config = test_configuration
      hash = config.to_hash

      expect(hash).to be_a(Hash)
      expect(hash[:api_key]).to eq("test-api-key")
      expect(hash[:model]).to eq("test-model")
    end
  end

  describe "performance tracking" do
    it "has performance tracking constants" do
      # These constants should be available for performance tracking
      expect(LlmTeam::ROLE_SYSTEM).to eq(:system)
      expect(LlmTeam::ROLE_USER).to eq(:user)
      expect(LlmTeam::ROLE_ASSISTANT).to eq(:assistant)
      expect(LlmTeam::ROLE_TOOL).to eq(:tool)
    end
  end

  describe "output system" do
    it "loads output system" do
      expect(LlmTeam::Output).to be_a(Module)
    end

    it "provides output methods" do
      expect(LlmTeam::Output).to respond_to(:puts)
    end
  end
end
