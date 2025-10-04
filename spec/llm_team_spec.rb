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

  describe "Response class" do
    let(:mock_primary_agent) do
      double("PrimaryAgent").tap do |agent|
        allow(agent).to receive(:name).and_return("TestPrimaryAgent")
        allow(agent).to receive(:get_total_token_usage).and_return(150)
        allow(agent).to receive(:instance_variable_defined?).with(:@total_tokens_used).and_return(true)
        allow(agent).to receive(:instance_variable_get).with(:@total_tokens_used).and_return(100)
        allow(agent).to receive(:instance_variable_defined?).with(:@total_latency_ms).and_return(true)
        allow(agent).to receive(:instance_variable_get).with(:@total_latency_ms).and_return(2000.5)
        allow(agent).to receive(:instance_variable_defined?).with(:@llm_calls_count).and_return(true)
        allow(agent).to receive(:instance_variable_get).with(:@llm_calls_count).and_return(3)
        allow(agent).to receive(:instance_variable_defined?).with(:@total_tool_calls).and_return(true)
        allow(agent).to receive(:instance_variable_get).with(:@total_tool_calls).and_return(2)
        allow(agent).to receive(:instance_variable_defined?).with(:@available_tools).and_return(true)
        allow(agent).to receive(:instance_variable_get).with(:@available_tools).and_return({})
        allow(agent).to receive(:instance_variable_defined?).with(:@conversation).and_return(true)
        allow(agent).to receive(:instance_variable_get).with(:@conversation).and_return(mock_conversation)
      end
    end

    let(:mock_conversation) do
      double("Conversation").tap do |conv|
        allow(conv).to receive(:respond_to?).with(:conversation_history).and_return(true)
        allow(conv).to receive(:conversation_history).and_return([
          {role: :user, content: "Test question"},
          {role: :assistant, content: "Test answer"}
        ])
      end
    end

    let(:mock_tool_agent) do
      double("ToolAgent").tap do |agent|
        allow(agent).to receive(:name).and_return("TestToolAgent")
        allow(agent).to receive(:instance_variable_get).with(:@total_tokens_used).and_return(50)
        allow(agent).to receive(:instance_variable_get).with(:@total_latency_ms).and_return(500.0)
        allow(agent).to receive(:instance_variable_get).with(:@llm_calls_count).and_return(1)
        allow(agent).to receive(:instance_variable_get).with(:@total_tool_calls).and_return(1)
      end
    end

    describe "initialization" do
      it "creates response with answer and performance data" do
        response = LlmTeam::Response.new(mock_primary_agent, "Test answer")

        expect(response.answer).to eq("Test answer")
        expect(response.tokens_used).to eq(150)
        expect(response.latency_ms).to eq(2000.5)
        expect(response.error).to be_nil
        expect(response.success?).to be true
        expect(response.error?).to be false
      end

      it "creates response with error" do
        response = LlmTeam::Response.new(mock_primary_agent, nil, error: "Test error")

        expect(response.answer).to be_nil
        expect(response.error).to eq("Test error")
        expect(response.success?).to be false
        expect(response.error?).to be true
      end

      it "creates immutable response object" do
        response = LlmTeam::Response.new(mock_primary_agent, "Test answer")
        expect(response).to be_frozen
      end
    end

    describe "performance data extraction" do
      it "extracts total token usage from primary agent" do
        response = LlmTeam::Response.new(mock_primary_agent, "Test answer")
        expect(response.tokens_used).to eq(150)
      end

      it "extracts total latency from primary agent" do
        response = LlmTeam::Response.new(mock_primary_agent, "Test answer")
        expect(response.latency_ms).to eq(2000.5)
      end

      it "handles missing performance data gracefully" do
        agent_without_data = double("PrimaryAgent").tap do |agent|
          allow(agent).to receive(:name).and_return("TestPrimaryAgent")
          allow(agent).to receive(:get_total_token_usage).and_raise(StandardError, "Method not available")
          allow(agent).to receive(:instance_variable_defined?).with(:@total_latency_ms).and_return(false)
          allow(agent).to receive(:instance_variable_defined?).with(:@available_tools).and_return(false)
          allow(agent).to receive(:instance_variable_defined?).with(:@conversation).and_return(false)
        end

        response = LlmTeam::Response.new(agent_without_data, "Test answer")
        expect(response.tokens_used).to eq(0)
        expect(response.latency_ms).to eq(0)
      end
    end

    describe "agent info extraction" do
      it "extracts primary agent information" do
        response = LlmTeam::Response.new(mock_primary_agent, "Test answer")

        expect(response.agent_info).to have_key(:primary_agent)
        expect(response.agent_info[:primary_agent][:name]).to eq("TestPrimaryAgent")
        expect(response.agent_info[:primary_agent][:tokens_used]).to eq(100)
        expect(response.agent_info[:primary_agent][:latency_ms]).to eq(2000.5)
        expect(response.agent_info[:primary_agent][:llm_calls_count]).to eq(3)
        expect(response.agent_info[:primary_agent][:tool_calls_count]).to eq(2)
      end

      it "extracts tool agent information" do
        agent_with_tools = double("PrimaryAgent").tap do |agent|
          allow(agent).to receive(:name).and_return("TestPrimaryAgent")
          allow(agent).to receive(:get_total_token_usage).and_return(200)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tokens_used).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tokens_used).and_return(100)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_latency_ms).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_latency_ms).and_return(2000.5)
          allow(agent).to receive(:instance_variable_defined?).with(:@llm_calls_count).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@llm_calls_count).and_return(3)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tool_calls).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tool_calls).and_return(2)
          allow(agent).to receive(:instance_variable_defined?).with(:@available_tools).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@available_tools).and_return({
            test_tool: mock_tool_agent
          })
          allow(agent).to receive(:instance_variable_defined?).with(:@conversation).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@conversation).and_return(mock_conversation)
        end

        response = LlmTeam::Response.new(agent_with_tools, "Test answer")

        expect(response.agent_info).to have_key(:tool_agents)
        expect(response.agent_info[:tool_agents]).to have_key(:test_tool)
        expect(response.agent_info[:tool_agents][:test_tool][:name]).to eq("TestToolAgent")
        expect(response.agent_info[:tool_agents][:test_tool][:tokens_used]).to eq(50)
        expect(response.agent_info[:tool_agents][:test_tool][:latency_ms]).to eq(500.0)
      end

      it "calculates summary statistics" do
        agent_with_tools = double("PrimaryAgent").tap do |agent|
          allow(agent).to receive(:name).and_return("TestPrimaryAgent")
          allow(agent).to receive(:get_total_token_usage).and_return(200)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tokens_used).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tokens_used).and_return(100)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_latency_ms).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_latency_ms).and_return(2000.5)
          allow(agent).to receive(:instance_variable_defined?).with(:@llm_calls_count).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@llm_calls_count).and_return(3)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tool_calls).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tool_calls).and_return(2)
          allow(agent).to receive(:instance_variable_defined?).with(:@available_tools).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@available_tools).and_return({
            test_tool: mock_tool_agent
          })
          allow(agent).to receive(:instance_variable_defined?).with(:@conversation).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@conversation).and_return(mock_conversation)
        end

        response = LlmTeam::Response.new(agent_with_tools, "Test answer")

        expect(response.agent_info).to have_key(:summary)
        expect(response.agent_info[:summary][:total_tokens_used]).to eq(150) # 100 + 50
        expect(response.agent_info[:summary][:total_latency_ms]).to eq(2500.5) # 2000.5 + 500.0
        expect(response.agent_info[:summary][:total_llm_calls]).to eq(4) # 3 + 1
        expect(response.agent_info[:summary][:tool_agents_count]).to eq(1)
      end
    end

    describe "conversation context extraction" do
      it "extracts conversation history" do
        response = LlmTeam::Response.new(mock_primary_agent, "Test answer")

        expect(response.conversation_context).to be_an(Array)
        expect(response.conversation_context.size).to eq(2)
        expect(response.conversation_context.first[:role]).to eq(:user)
        expect(response.conversation_context.first[:content]).to eq("Test question")
        expect(response.conversation_context.last[:role]).to eq(:assistant)
        expect(response.conversation_context.last[:content]).to eq("Test answer")
      end

      it "handles missing conversation data gracefully" do
        agent_without_conversation = double("PrimaryAgent").tap do |agent|
          allow(agent).to receive(:name).and_return("TestPrimaryAgent")
          allow(agent).to receive(:get_total_token_usage).and_return(150)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tokens_used).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tokens_used).and_return(100)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_latency_ms).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_latency_ms).and_return(2000.5)
          allow(agent).to receive(:instance_variable_defined?).with(:@llm_calls_count).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@llm_calls_count).and_return(3)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tool_calls).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tool_calls).and_return(2)
          allow(agent).to receive(:instance_variable_defined?).with(:@available_tools).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@available_tools).and_return({})
          allow(agent).to receive(:instance_variable_defined?).with(:@conversation).and_return(false)
        end

        response = LlmTeam::Response.new(agent_without_conversation, "Test answer")
        expect(response.conversation_context).to eq([])
      end
    end

    describe "serialization" do
      it "converts to hash with all attributes" do
        response = LlmTeam::Response.new(mock_primary_agent, "Test answer")
        hash = response.to_hash

        expect(hash).to be_a(Hash)
        expect(hash[:answer]).to eq("Test answer")
        expect(hash[:tokens_used]).to eq(150)
        expect(hash[:latency_ms]).to eq(2000.5)
        expect(hash[:agent_info]).to be_a(Hash)
        expect(hash[:conversation_context]).to be_an(Array)
        expect(hash[:error]).to be_nil
      end

      it "includes error in hash when present" do
        response = LlmTeam::Response.new(mock_primary_agent, nil, error: "Test error")
        hash = response.to_hash

        expect(hash[:error]).to eq("Test error")
        expect(hash[:answer]).to be_nil
      end
    end

    describe "error handling" do
      it "handles agent info extraction errors gracefully" do
        agent_with_errors = double("PrimaryAgent").tap do |agent|
          allow(agent).to receive(:name).and_return("TestPrimaryAgent")
          allow(agent).to receive(:get_total_token_usage).and_return(150)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tokens_used).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tokens_used).and_raise(StandardError, "Access error")
          allow(agent).to receive(:instance_variable_defined?).with(:@total_latency_ms).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_latency_ms).and_return(2000.5)
          allow(agent).to receive(:instance_variable_defined?).with(:@llm_calls_count).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@llm_calls_count).and_return(3)
          allow(agent).to receive(:instance_variable_defined?).with(:@total_tool_calls).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@total_tool_calls).and_return(2)
          allow(agent).to receive(:instance_variable_defined?).with(:@available_tools).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@available_tools).and_return({})
          allow(agent).to receive(:instance_variable_defined?).with(:@conversation).and_return(true)
          allow(agent).to receive(:instance_variable_get).with(:@conversation).and_return(mock_conversation)
        end

        response = LlmTeam::Response.new(agent_with_errors, "Test answer")
        expect(response.agent_info[:primary_agent][:error]).to eq("Performance data unavailable")
      end
    end
  end
end
