# frozen_string_literal: true

require "spec_helper"

RSpec.describe LlmTeam::API do
  describe ".ask" do
    let(:test_query) { "What is the capital of France?" }
    let(:mock_primary_agent) do
      double("PrimaryAgent").tap do |agent|
        allow(agent).to receive(:respond).with(test_query).and_return("Paris is the capital of France.")
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
          {role: :user, content: test_query},
          {role: :assistant, content: "Paris is the capital of France."}
        ])
      end
    end

    before do
      # Mock PrimaryAgent constructor
      allow(LlmTeam::Agents::Core::PrimaryAgent).to receive(:new).and_return(mock_primary_agent)
    end

    describe "successful execution" do
      it "returns a Response object with answer and performance data" do
        response = LlmTeam::API.ask(test_query)

        expect(response).to be_a(LlmTeam::Response)
        expect(response.answer).to eq("Paris is the capital of France.")
        expect(response.tokens_used).to eq(150)
        expect(response.latency_ms).to eq(2000.5)
        expect(response.error).to be_nil
        expect(response.success?).to be true
      end

      it "creates PrimaryAgent with current configuration" do
        expect(LlmTeam::Agents::Core::PrimaryAgent).to receive(:new).and_return(mock_primary_agent)

        LlmTeam::API.ask(test_query)
      end

      it "calls respond method on PrimaryAgent with the query" do
        expect(mock_primary_agent).to receive(:respond).with(test_query).and_return("Paris is the capital of France.")

        LlmTeam::API.ask(test_query)
      end

      it "includes conversation context in response" do
        response = LlmTeam::API.ask(test_query)

        expect(response.conversation_context).to be_an(Array)
        expect(response.conversation_context.size).to eq(2)
        expect(response.conversation_context.first[:role]).to eq(:user)
        expect(response.conversation_context.first[:content]).to eq(test_query)
      end
    end

    describe "configuration validation" do
      it "validates configuration before proceeding" do
        expect(LlmTeam.configuration).to receive(:validate!)

        LlmTeam::API.ask(test_query)
      end

      it "handles configuration validation errors" do
        # Set up a configuration that will fail validation
        LlmTeam.configure do |config|
          config.api_key = nil
        end

        response = LlmTeam::API.ask(test_query)

        expect(response).to be_a(LlmTeam::Response)
        expect(response.answer).to be_nil
        expect(response.error).to include("API key is required")
        expect(response.error?).to be true
      end
    end

    describe "error handling" do
      it "handles PrimaryAgent respond method errors" do
        allow(mock_primary_agent).to receive(:respond).and_raise(StandardError, "API call failed")

        response = LlmTeam::API.ask(test_query)

        expect(response).to be_a(LlmTeam::Response)
        expect(response.answer).to be_nil
        expect(response.error).to eq("API call failed")
        expect(response.error?).to be true
      end
    end

    describe "configuration preservation" do
      it "does not modify global configuration state" do
        original_quiet = LlmTeam.configuration.quiet
        original_verbose = LlmTeam.configuration.verbose

        LlmTeam::API.ask(test_query)

        expect(LlmTeam.configuration.quiet).to eq(original_quiet)
        expect(LlmTeam.configuration.verbose).to eq(original_verbose)
      end

      it "preserves configuration across multiple calls" do
        LlmTeam.configure do |config|
          config.model = "test-model"
          config.temperature = 0.7
        end

        # Mock the respond method to handle different queries
        allow(mock_primary_agent).to receive(:respond).with(test_query).and_return("Paris is the capital of France.")
        allow(mock_primary_agent).to receive(:respond).with("Another question").and_return("Another answer")

        LlmTeam::API.ask(test_query)
        LlmTeam::API.ask("Another question")

        expect(LlmTeam.configuration.model).to eq("test-model")
        expect(LlmTeam.configuration.temperature).to eq(0.7)
      end
    end

    describe "edge cases" do
      it "handles empty query string" do
        allow(mock_primary_agent).to receive(:respond).with("").and_return("Empty query response")

        response = LlmTeam::API.ask("")

        expect(response).to be_a(LlmTeam::Response)
        expect(response.answer).to eq("Empty query response")
      end

      it "handles nil query" do
        allow(mock_primary_agent).to receive(:respond).with(nil).and_return("Nil query response")

        response = LlmTeam::API.ask(nil)

        expect(response).to be_a(LlmTeam::Response)
        expect(response.answer).to eq("Nil query response")
      end

      it "handles very long queries" do
        long_query = "What is the capital of France? " * 1000
        allow(mock_primary_agent).to receive(:respond).with(long_query).and_return("Paris")

        response = LlmTeam::API.ask(long_query)

        expect(response).to be_a(LlmTeam::Response)
        expect(response.answer).to eq("Paris")
      end
    end

    describe "performance data extraction" do
      it "extracts performance data from PrimaryAgent" do
        response = LlmTeam::API.ask(test_query)

        expect(response.agent_info).to have_key(:primary_agent)
        expect(response.agent_info[:primary_agent][:name]).to eq("TestPrimaryAgent")
        expect(response.agent_info[:primary_agent][:tokens_used]).to eq(100)
        expect(response.agent_info[:primary_agent][:latency_ms]).to eq(2000.5)
        expect(response.agent_info[:primary_agent][:llm_calls_count]).to eq(3)
        expect(response.agent_info[:primary_agent][:tool_calls_count]).to eq(2)
      end

      it "handles missing performance data gracefully" do
        agent_without_data = double("PrimaryAgent").tap do |agent|
          allow(agent).to receive(:respond).with(test_query).and_return("Paris")
          allow(agent).to receive(:name).and_return("TestPrimaryAgent")
          allow(agent).to receive(:get_total_token_usage).and_raise(StandardError, "Method not available")
          allow(agent).to receive(:instance_variable_defined?).with(:@total_latency_ms).and_return(false)
          allow(agent).to receive(:instance_variable_defined?).with(:@available_tools).and_return(false)
          allow(agent).to receive(:instance_variable_defined?).with(:@conversation).and_return(false)
        end

        allow(LlmTeam::Agents::Core::PrimaryAgent).to receive(:new).and_return(agent_without_data)

        response = LlmTeam::API.ask(test_query)

        expect(response).to be_a(LlmTeam::Response)
        expect(response.answer).to eq("Paris")
        expect(response.tokens_used).to eq(0)
        expect(response.latency_ms).to eq(0)
      end
    end
  end
end
