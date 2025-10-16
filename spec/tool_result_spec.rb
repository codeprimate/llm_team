# frozen_string_literal: true

require "spec_helper"

RSpec.describe LlmTeam::Core::ToolResult do
  describe ".success" do
    it "creates a successful result with output" do
      result = described_class.success(
        function_name: "test_function",
        tool_call_id: "call_123",
        output: "Test output"
      )

      expect(result.success?).to be true
      expect(result.error?).to be false
      expect(result.function_name).to eq("test_function")
      expect(result.tool_call_id).to eq("call_123")
      expect(result.output).to eq("Test output")
      expect(result.error).to be_nil
      expect(result.message).to be_nil
    end
  end

  describe ".error" do
    it "creates an error result with error type and message" do
      result = described_class.error(
        function_name: "test_function",
        tool_call_id: "call_123",
        error: :tool_not_found,
        message: "Tool not found"
      )

      expect(result.success?).to be false
      expect(result.error?).to be true
      expect(result.function_name).to eq("test_function")
      expect(result.tool_call_id).to eq("call_123")
      expect(result.output).to be_nil
      expect(result.error).to eq(:tool_not_found)
      expect(result.message).to eq("Tool not found")
    end
  end

  describe "#initialize" do
    context "with valid success result" do
      it "creates a successful result" do
        result = described_class.new(
          success: true,
          function_name: "test_function",
          tool_call_id: "call_123",
          output: "Test output"
        )

        expect(result.success?).to be true
        expect(result.output).to eq("Test output")
      end
    end

    context "with valid error result" do
      it "creates an error result" do
        result = described_class.new(
          success: false,
          function_name: "test_function",
          tool_call_id: "call_123",
          error: :execution_error,
          message: "Execution failed"
        )

        expect(result.error?).to be true
        expect(result.error).to eq(:execution_error)
        expect(result.message).to eq("Execution failed")
      end
    end

    context "with invalid success result" do
      it "raises error when output is missing" do
        expect {
          described_class.new(
            success: true,
            function_name: "test_function",
            tool_call_id: "call_123"
          )
        }.to raise_error(ArgumentError, "Success result must have output")
      end

      it "raises error when error fields are present" do
        expect {
          described_class.new(
            success: true,
            function_name: "test_function",
            tool_call_id: "call_123",
            output: "Test output",
            error: :tool_not_found
          )
        }.to raise_error(ArgumentError, "Success result cannot have error or message")
      end
    end

    context "with invalid error result" do
      it "raises error when error type is missing" do
        expect {
          described_class.new(
            success: false,
            function_name: "test_function",
            tool_call_id: "call_123",
            message: "Error message"
          )
        }.to raise_error(ArgumentError, "Error result must have error type")
      end

      it "raises error when message is missing" do
        expect {
          described_class.new(
            success: false,
            function_name: "test_function",
            tool_call_id: "call_123",
            error: :execution_error
          )
        }.to raise_error(ArgumentError, "Error result must have message")
      end

      it "raises error when message is empty" do
        expect {
          described_class.new(
            success: false,
            function_name: "test_function",
            tool_call_id: "call_123",
            error: :execution_error,
            message: ""
          )
        }.to raise_error(ArgumentError, "Error result must have message")
      end

      it "raises error when output is present" do
        expect {
          described_class.new(
            success: false,
            function_name: "test_function",
            tool_call_id: "call_123",
            error: :execution_error,
            message: "Error message",
            output: "Some output"
          )
        }.to raise_error(ArgumentError, "Error result cannot have output")
      end

      it "raises error for invalid error type" do
        expect {
          described_class.new(
            success: false,
            function_name: "test_function",
            tool_call_id: "call_123",
            error: :invalid_error,
            message: "Error message"
          )
        }.to raise_error(ArgumentError, "Invalid error type: invalid_error. Must be one of: tool_not_found, execution_error, timeout")
      end
    end

    context "with missing required fields" do
      it "raises error when function_name is nil" do
        expect {
          described_class.new(
            success: true,
            function_name: nil,
            tool_call_id: "call_123",
            output: "Test output"
          )
        }.to raise_error(ArgumentError, "function_name cannot be nil or empty")
      end

      it "raises error when function_name is empty" do
        expect {
          described_class.new(
            success: true,
            function_name: "",
            tool_call_id: "call_123",
            output: "Test output"
          )
        }.to raise_error(ArgumentError, "function_name cannot be nil or empty")
      end

      it "raises error when tool_call_id is nil" do
        expect {
          described_class.new(
            success: true,
            function_name: "test_function",
            tool_call_id: nil,
            output: "Test output"
          )
        }.to raise_error(ArgumentError, "tool_call_id cannot be nil or empty")
      end

      it "raises error when tool_call_id is empty" do
        expect {
          described_class.new(
            success: true,
            function_name: "test_function",
            tool_call_id: "",
            output: "Test output"
          )
        }.to raise_error(ArgumentError, "tool_call_id cannot be nil or empty")
      end
    end
  end

  describe "#to_conversation_message" do
    context "with success result" do
      it "returns proper conversation message format" do
        result = described_class.success(
          function_name: "test_function",
          tool_call_id: "call_123",
          output: "Test output"
        )

        message = result.to_conversation_message

        expect(message).to eq({
          role: LlmTeam::ROLE_TOOL,
          content: "Test output",
          tool_call_id: "call_123",
          name: "test_function"
        })
      end
    end

    context "with error result" do
      it "returns proper conversation message format" do
        result = described_class.error(
          function_name: "test_function",
          tool_call_id: "call_123",
          error: :tool_not_found,
          message: "Tool not found"
        )

        message = result.to_conversation_message

        expect(message).to eq({
          role: LlmTeam::ROLE_TOOL,
          content: "Tool not found",
          tool_call_id: "call_123",
          name: "test_function"
        })
      end
    end
  end

  describe "#to_s" do
    it "returns string representation for success result" do
      result = described_class.success(
        function_name: "test_function",
        tool_call_id: "call_123",
        output: "Test output"
      )

      expect(result.to_s).to eq("ToolResult(success: test_function -> 11 chars)")
    end

    it "returns string representation for error result" do
      result = described_class.error(
        function_name: "test_function",
        tool_call_id: "call_123",
        error: :tool_not_found,
        message: "Tool not found"
      )

      expect(result.to_s).to eq("ToolResult(error: test_function -> tool_not_found: Tool not found)")
    end
  end

  describe "#==" do
    it "returns true for equal results" do
      result1 = described_class.success(
        function_name: "test_function",
        tool_call_id: "call_123",
        output: "Test output"
      )

      result2 = described_class.success(
        function_name: "test_function",
        tool_call_id: "call_123",
        output: "Test output"
      )

      expect(result1).to eq(result2)
    end

    it "returns false for different results" do
      result1 = described_class.success(
        function_name: "test_function",
        tool_call_id: "call_123",
        output: "Test output"
      )

      result2 = described_class.success(
        function_name: "test_function",
        tool_call_id: "call_123",
        output: "Different output"
      )

      expect(result1).not_to eq(result2)
    end

    it "returns false for different types" do
      result = described_class.success(
        function_name: "test_function",
        tool_call_id: "call_123",
        output: "Test output"
      )

      expect(result).not_to eq("not a result")
    end
  end

  describe "VALID_ERROR_TYPES" do
    it "contains all valid error types" do
      expect(described_class::VALID_ERROR_TYPES).to eq([:tool_not_found, :execution_error, :timeout])
    end
  end
end
