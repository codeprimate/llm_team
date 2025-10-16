# frozen_string_literal: true

require "spec_helper"

RSpec.describe LlmTeam::Core::LlmClient do
  let(:config) { test_configuration }
  let(:client) { described_class.new(config) }

  describe "#initialize" do
    it "stores the configuration" do
      expect(client.instance_variable_get(:@config)).to eq(config)
    end
  end

  describe "#chat" do
    it "raises NotImplementedError" do
      expect { client.chat(parameters: {}) }.to raise_error(NotImplementedError, "Subclasses must implement #chat")
    end
  end
end
