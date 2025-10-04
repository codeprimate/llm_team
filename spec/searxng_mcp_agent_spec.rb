# frozen_string_literal: true

require "spec_helper"
require_relative "../lib/llm_team/agents/auxiliary/research_agent/searxng_mcp_agent"

RSpec.describe LlmTeam::Agents::Auxiliary::ResearchAgent::SearxngMcpAgent do
  describe "Configuration" do
    let(:config) { described_class::Configuration.new }

    describe "#initialize" do
      it "sets default URL from environment variable" do
        expect(config.searxng_url).to eq("http://localhost:7778")
      end

      it "uses environment variable when set" do
        allow(ENV).to receive(:fetch).with("LLM_TEAM_SEARXNG_URL", "http://localhost:7778").and_return("http://custom:8080")
        custom_config = described_class::Configuration.new
        expect(custom_config.searxng_url).to eq("http://custom:8080")
      end
    end

    describe "#validate!" do
      it "passes validation for valid HTTP URL" do
        config.searxng_url = "http://localhost:7778"
        expect { config.validate! }.not_to raise_error
      end

      it "passes validation for valid HTTPS URL" do
        config.searxng_url = "https://searxng.example.com"
        expect { config.validate! }.not_to raise_error
      end

      it "passes validation for nil URL" do
        config.searxng_url = nil
        expect { config.validate! }.not_to raise_error
      end

      it "passes validation for empty URL" do
        config.searxng_url = ""
        expect { config.validate! }.not_to raise_error
      end

      it "raises error for invalid URL" do
        config.searxng_url = "not-a-url"
        expect { config.validate! }.to raise_error(ArgumentError, "SearXNG URL must be HTTP or HTTPS")
      end

      it "raises error for non-HTTP URL" do
        config.searxng_url = "ftp://localhost:7778"
        expect { config.validate! }.to raise_error(ArgumentError, "SearXNG URL must be HTTP or HTTPS")
      end
    end

    describe "#valid?" do
      it "returns true for valid URL" do
        config.searxng_url = "http://localhost:7778"
        expect(config.valid?).to be true
      end

      it "returns false for invalid URL" do
        config.searxng_url = "not-a-url"
        expect(config.valid?).to be false
      end
    end
  end

  describe "Agent" do
    let(:agent) { described_class.new }

    it "initializes with configuration" do
      expect(agent.instance_variable_get(:@config)).to be_a(described_class::Configuration)
    end

    it "uses configuration URL for MCP calls" do
      config = agent.instance_variable_get(:@config)
      expect(config.searxng_url).to eq("http://localhost:7778")
    end
  end
end
