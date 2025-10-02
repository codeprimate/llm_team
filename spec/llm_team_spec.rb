# frozen_string_literal: true

require "spec_helper"

RSpec.describe LlmTeam do
  describe "module loading and version" do
    it "has a version number" do
      expect(LlmTeam::VERSION).not_to be nil
      expect(LlmTeam::VERSION).to be_a(String)
    end

    it "loads all required constants" do
      expect(LlmTeam::ROLE_SYSTEM).to eq(:system)
      expect(LlmTeam::ROLE_USER).to eq(:user)
      expect(LlmTeam::ROLE_ASSISTANT).to eq(:assistant)
      expect(LlmTeam::ROLE_TOOL).to eq(:tool)
    end
  end

  describe "configuration DSL" do
    it "provides configuration access" do
      expect(LlmTeam.configuration).to be_a(LlmTeam::Configuration)
    end

    it "allows configuration via block" do
      expect { LlmTeam.configure { |config| } }.not_to raise_error
    end

    it "configures values via block" do
      LlmTeam.configure do |config|
        config.api_key = "test-key"
        config.model = "test-model"
      end

      expect(LlmTeam.configuration.api_key).to eq("test-key")
      expect(LlmTeam.configuration.model).to eq("test-model")
    end

    it "maintains configuration instance across calls" do
      config1 = LlmTeam.configuration
      config2 = LlmTeam.configuration
      expect(config1).to be(config2)
    end
  end

  describe "configuration system" do
    let(:config) { LlmTeam::Configuration.new }

    describe "initialization" do
      it "loads default values" do
        expect(config.model).to eq(LlmTeam::Configuration::DEFAULT_MODEL)
        expect(config.max_iterations).to eq(LlmTeam::Configuration::DEFAULT_MAX_ITERATIONS)
        expect(config.temperature).to eq(LlmTeam::Configuration::DEFAULT_TEMPERATURE)
        expect(config.default_history_behavior).to eq(LlmTeam::Configuration::DEFAULT_HISTORY_BEHAVIOR)
        expect(config.max_retries).to eq(LlmTeam::Configuration::DEFAULT_MAX_RETRIES)
        expect(config.retry_delay).to eq(LlmTeam::Configuration::DEFAULT_RETRY_DELAY)
        expect(config.timeout).to eq(LlmTeam::Configuration::DEFAULT_TIMEOUT)
        expect(config.log_level).to eq(LlmTeam::Configuration::DEFAULT_LOG_LEVEL)
        expect(config.api_base_url).to eq(LlmTeam::Configuration::DEFAULT_API_BASE_URL)
        expect(config.searxng_url).to eq(LlmTeam::Configuration::DEFAULT_SEARXNG_URL)
        expect(config.verbose).to eq(LlmTeam::Configuration::DEFAULT_VERBOSE)
        expect(config.quiet).to eq(LlmTeam::Configuration::DEFAULT_QUIET)
        expect(config.max_tool_call_response_length).to eq(LlmTeam::Configuration::DEFAULT_MAX_TOOL_CALL_RESPONSE_LENGTH)
      end

      it "loads from environment variables" do
        # Note: Environment variables are tested in integration tests
        # This test verifies the configuration object can be created
        expect(config).to be_a(LlmTeam::Configuration)
      end

      it "handles quiet mode overriding verbose" do
        config.quiet = true
        config.verbose = true
        config.send(:initialize) # Call private initialize to test the logic
        expect(config.verbose).to be false
      end
    end

    describe "validation" do
      it "validates successfully with valid configuration" do
        config.api_key = "test-api-key"
        expect { config.validate! }.not_to raise_error
      end

      it "raises error for missing API key" do
        config.api_key = nil
        expect { config.validate! }.to raise_error(LlmTeam::MissingAPIKeyError)
      end

      it "raises error for empty API key" do
        config.api_key = ""
        expect { config.validate! }.to raise_error(LlmTeam::MissingAPIKeyError)
      end

      it "raises error for invalid history behavior" do
        config.api_key = "test-api-key"
        config.default_history_behavior = :invalid
        expect { config.validate! }.to raise_error(LlmTeam::ConfigurationError)
      end

      it "raises error for invalid temperature" do
        config.api_key = "test-api-key"
        config.temperature = 3.0
        expect { config.validate! }.to raise_error(LlmTeam::ConfigurationError)
      end

      it "raises error for non-positive max iterations" do
        config.api_key = "test-api-key"
        config.max_iterations = 0
        expect { config.validate! }.to raise_error(LlmTeam::ConfigurationError)
      end
    end

    describe "auxiliary agents path management" do
      it "adds auxiliary agents path" do
        initial_paths = config.auxiliary_agents_paths.dup
        config.add_auxiliary_agents_path("/test/path")

        expect(config.auxiliary_agents_paths).to include("/test/path")
        expect(config.auxiliary_agents_paths.length).to eq(initial_paths.length + 1)
      end

      it "does not add duplicate auxiliary agents path" do
        config.add_auxiliary_agents_path("/test/path")
        initial_length = config.auxiliary_agents_paths.length
        config.add_auxiliary_agents_path("/test/path")

        expect(config.auxiliary_agents_paths.length).to eq(initial_length)
      end
    end

    describe "serialization" do
      it "converts to hash" do
        config.api_key = "test-key"
        config.model = "test-model"

        hash = config.to_hash

        expect(hash).to be_a(Hash)
        expect(hash[:api_key]).to eq("test-key")
        expect(hash[:model]).to eq("test-model")
        expect(hash[:max_iterations]).to eq(config.max_iterations)
        expect(hash[:temperature]).to eq(config.temperature)
      end
    end

    describe "reset functionality" do
      it "resets configuration to defaults" do
        config.api_key = "modified-key"
        config.model = "modified-model"

        config.reset!

        expect(config.api_key).to eq(ENV["OPENROUTER_API_KEY"])
        expect(config.model).to eq(LlmTeam::Configuration::DEFAULT_MODEL)
      end
    end
  end

  describe "CLI application" do
    let(:cli_app) { LlmTeam::CLI::Application.new }

    it "can be instantiated" do
      expect(cli_app).to be_a(LlmTeam::CLI::Application)
    end

    it "has required instance variables" do
      expect(cli_app.instance_variable_get(:@options)).to eq({})
      expect(cli_app.instance_variable_get(:@last_response)).to be_nil
      expect(cli_app.instance_variable_get(:@last_user_input)).to be_nil
    end

    # Note: CLI functionality is tested in integration tests
    # This test verifies the application can be instantiated
  end

  describe "error handling" do
    it "defines error classes" do
      expect(LlmTeam::MissingAPIKeyError).to be < StandardError
      expect(LlmTeam::ConfigurationError).to be < StandardError
      expect(LlmTeam::APIError).to be < StandardError
      expect(LlmTeam::AgentError).to be < StandardError
    end
  end
end
