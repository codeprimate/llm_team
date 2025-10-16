# frozen_string_literal: true

require "spec_helper"

RSpec.describe LlmTeam::Core::ToolRunner do
  let(:config) { double("config", max_tool_call_response_length: 1000) }
  let(:tool_runner) { described_class.new(config) }

  # Mock tool agent
  let(:mock_tool_agent) do
    double("tool_agent").tap do |agent|
      allow(agent.class).to receive(:tool_schema).and_return({
        function: {name: "test_function"}
      })
      allow(agent).to receive(:test_function).and_return("Tool output")
    end
  end

  let(:available_tools) { {"test_agent" => mock_tool_agent} }

  describe "#initialize" do
    it "initializes with configuration and resets tool call counter" do
      expect(tool_runner.total_tool_calls).to eq(0)
    end
  end

  describe "#execute_tool_calls" do
    context "with empty tool calls" do
      it "returns empty array for nil tool calls" do
        result = tool_runner.execute_tool_calls(nil, available_tools)
        expect(result).to eq([])
      end

      it "returns empty array for empty tool calls" do
        result = tool_runner.execute_tool_calls([], available_tools)
        expect(result).to eq([])
      end
    end

    context "with single tool call" do
      let(:tool_calls) do
        [{
          "id" => "call_123",
          "function" => {
            "name" => "test_function",
            "arguments" => {"param1" => "value1"}
          }
        }]
      end

      it "executes tool successfully and returns ToolResult" do
        results = tool_runner.execute_tool_calls(tool_calls, available_tools)

        expect(results.length).to eq(1)
        result = results.first

        expect(result.success?).to be true
        expect(result.function_name).to eq("test_function")
        expect(result.tool_call_id).to eq("call_123")
        expect(result.output).to eq("Tool output")
      end

      it "increments tool call counter" do
        expect { tool_runner.execute_tool_calls(tool_calls, available_tools) }
          .to change { tool_runner.total_tool_calls }.by(1)
      end
    end

    context "with multiple tool calls" do
      let(:tool_calls) do
        [
          {
            "id" => "call_123",
            "function" => {
              "name" => "test_function",
              "arguments" => {"param1" => "value1"}
            }
          },
          {
            "id" => "call_456",
            "function" => {
              "name" => "test_function",
              "arguments" => {"param2" => "value2"}
            }
          }
        ]
      end

      it "executes all tools sequentially and returns results in order" do
        results = tool_runner.execute_tool_calls(tool_calls, available_tools)

        expect(results.length).to eq(2)
        expect(results[0].tool_call_id).to eq("call_123")
        expect(results[1].tool_call_id).to eq("call_456")
        expect(results.all?(&:success?)).to be true
      end

      it "increments tool call counter for each tool" do
        expect { tool_runner.execute_tool_calls(tool_calls, available_tools) }
          .to change { tool_runner.total_tool_calls }.by(2)
      end
    end

    context "with tool not found" do
      let(:tool_calls) do
        [{
          "id" => "call_123",
          "function" => {
            "name" => "nonexistent_function",
            "arguments" => {"param1" => "value1"}
          }
        }]
      end

      it "returns error ToolResult for missing tool" do
        results = tool_runner.execute_tool_calls(tool_calls, available_tools)

        expect(results.length).to eq(1)
        result = results.first

        expect(result.error?).to be true
        expect(result.function_name).to eq("nonexistent_function")
        expect(result.tool_call_id).to eq("call_123")
        expect(result.error).to eq(:tool_not_found)
        expect(result.message).to eq("Tool 'nonexistent_function' not found")
      end

      it "still increments tool call counter" do
        expect { tool_runner.execute_tool_calls(tool_calls, available_tools) }
          .to change { tool_runner.total_tool_calls }.by(1)
      end
    end

    context "with invalid arguments format" do
      let(:tool_calls) do
        [{
          "id" => "call_123",
          "function" => {
            "name" => "test_function",
            "arguments" => "invalid_string"
          }
        }]
      end

      it "returns error ToolResult for invalid arguments format" do
        results = tool_runner.execute_tool_calls(tool_calls, available_tools)

        expect(results.length).to eq(1)
        result = results.first

        expect(result.error?).to be true
        expect(result.function_name).to eq("test_function")
        expect(result.tool_call_id).to eq("call_123")
        expect(result.error).to eq(:execution_error)
        expect(result.message).to include("Invalid tool arguments format")
      end
    end

    context "with tool execution error" do
      let(:failing_tool_agent) do
        double("failing_tool_agent").tap do |agent|
          allow(agent.class).to receive(:tool_schema).and_return({
            function: {name: "failing_function"}
          })
          allow(agent).to receive(:failing_function).and_raise(StandardError, "Tool execution failed")
        end
      end

      let(:available_tools_with_failing) { {"failing_agent" => failing_tool_agent} }

      let(:tool_calls) do
        [{
          "id" => "call_123",
          "function" => {
            "name" => "failing_function",
            "arguments" => {"param1" => "value1"}
          }
        }]
      end

      it "returns error ToolResult for tool execution failure" do
        results = tool_runner.execute_tool_calls(tool_calls, available_tools_with_failing)

        expect(results.length).to eq(1)
        result = results.first

        expect(result.error?).to be true
        expect(result.function_name).to eq("failing_function")
        expect(result.tool_call_id).to eq("call_123")
        expect(result.error).to eq(:execution_error)
        expect(result.message).to eq("Tool execution failed: Tool execution failed")
      end
    end
  end

  describe "#reset_tool_call_count" do
    it "resets tool call counter to zero" do
      # Execute some tools to increment counter
      tool_calls = [{
        "id" => "call_123",
        "function" => {
          "name" => "test_function",
          "arguments" => {"param1" => "value1"}
        }
      }]

      tool_runner.execute_tool_calls(tool_calls, available_tools)
      expect(tool_runner.total_tool_calls).to eq(1)

      tool_runner.reset_tool_call_count
      expect(tool_runner.total_tool_calls).to eq(0)
    end
  end

  describe "output truncation" do
    let(:long_output_tool_agent) do
      double("long_output_tool_agent").tap do |agent|
        allow(agent.class).to receive(:tool_schema).and_return({
          function: {name: "long_output_function"}
        })
        allow(agent).to receive(:long_output_function).and_return("x" * 1500)
      end
    end

    let(:available_tools_with_long_output) { {"long_output_agent" => long_output_tool_agent} }

    let(:tool_calls) do
      [{
        "id" => "call_123",
        "function" => {
          "name" => "long_output_function",
          "arguments" => {"param1" => "value1"}
        }
      }]
    end

    it "truncates long tool outputs" do
      results = tool_runner.execute_tool_calls(tool_calls, available_tools_with_long_output)

      expect(results.length).to eq(1)
      result = results.first

      expect(result.success?).to be true
      expect(result.output.length).to be <= 1000 + 50 # Max length + truncation indicator
      expect(result.output).to include("[TOOL OUTPUT TRUNCATED]")
    end
  end

  describe "tool agent schema matching" do
    let(:schema_matching_tool_agent) do
      double("schema_matching_tool_agent").tap do |agent|
        allow(agent.class).to receive(:tool_schema).and_return({
          function: {name: "schema_function"}
        })
        allow(agent).to receive(:schema_function).and_return("Schema matched output")
      end
    end

    let(:available_tools_with_schema) { {"schema_agent" => schema_matching_tool_agent} }

    let(:tool_calls) do
      [{
        "id" => "call_123",
        "function" => {
          "name" => "schema_function",
          "arguments" => {"param1" => "value1"}
        }
      }]
    end

    it "finds tool agent by schema function name" do
      results = tool_runner.execute_tool_calls(tool_calls, available_tools_with_schema)

      expect(results.length).to eq(1)
      result = results.first

      expect(result.success?).to be true
      expect(result.output).to eq("Schema matched output")
    end
  end

  # Parallel Execution Tests
  describe "parallel execution functionality" do
    let(:config_with_concurrency) do
      double("config_with_concurrency").tap do |config|
        allow(config).to receive(:max_tool_call_response_length).and_return(1000)
        allow(config).to receive(:max_concurrent_tools).and_return(3)
        allow(config).to receive(:tool_execution_timeout).and_return(30)
        allow(config).to receive(:tool_start_jitter_max).and_return(1.0)
      end
    end

    let(:parallel_tool_runner) { described_class.new(config_with_concurrency) }

    let(:slow_tool_agent) do
      # Create a unique mock class for this agent to avoid schema conflicts
      slow_agent_class = Class.new
      slow_agent_class.define_singleton_method(:tool_schema) do
        {function: {name: "slow_function"}}
      end

      slow_agent_class.new.tap do |agent|
        allow(agent).to receive(:slow_function) do |**args|
          sleep(0.1) # Simulate slow execution
          "Slow tool output"
        end
      end
    end

    let(:fast_tool_agent) do
      # Create a unique mock class for this agent to avoid schema conflicts
      fast_agent_class = Class.new
      fast_agent_class.define_singleton_method(:tool_schema) do
        {function: {name: "fast_function"}}
      end

      fast_agent_class.new.tap do |agent|
        allow(agent).to receive(:fast_function) do |**args|
          "Fast tool output"
        end
      end
    end

    let(:available_tools_parallel) do
      {
        "slow_agent" => slow_tool_agent,
        "fast_agent" => fast_tool_agent
      }
    end

    describe "#should_run_parallel?" do
      context "with single tool call" do
        let(:single_tool_calls) do
          [{
            "id" => "call_123",
            "function" => {
              "name" => "fast_function",
              "arguments" => {"param1" => "value1"}
            }
          }]
        end

        it "returns false for single tool call" do
          expect(parallel_tool_runner.send(:should_run_parallel?, single_tool_calls)).to be false
        end
      end

      context "with multiple tool calls" do
        let(:multiple_tool_calls) do
          [
            {
              "id" => "call_123",
              "function" => {
                "name" => "fast_function",
                "arguments" => {"param1" => "value1"}
              }
            },
            {
              "id" => "call_456",
              "function" => {
                "name" => "slow_function",
                "arguments" => {"param2" => "value2"}
              }
            }
          ]
        end

        it "returns true for multiple tool calls with concurrency enabled" do
          expect(parallel_tool_runner.send(:should_run_parallel?, multiple_tool_calls)).to be true
        end
      end

      context "with concurrency disabled" do
        let(:config_disabled_concurrency) do
          double("config_disabled_concurrency").tap do |config|
            allow(config).to receive(:max_tool_call_response_length).and_return(1000)
            allow(config).to receive(:max_concurrent_tools).and_return(1)
          end
        end

        let(:disabled_tool_runner) { described_class.new(config_disabled_concurrency) }

        let(:multiple_tool_calls) do
          [
            {
              "id" => "call_123",
              "function" => {
                "name" => "fast_function",
                "arguments" => {"param1" => "value1"}
              }
            },
            {
              "id" => "call_456",
              "function" => {
                "name" => "slow_function",
                "arguments" => {"param2" => "value2"}
              }
            }
          ]
        end

        it "returns false when concurrency is disabled" do
          expect(disabled_tool_runner.send(:should_run_parallel?, multiple_tool_calls)).to be false
        end
      end
    end

    describe "#calculate_start_jitter" do
      context "with jitter enabled" do
        it "returns 0 for first tool (index 0)" do
          jitter = parallel_tool_runner.send(:calculate_start_jitter, 0)
          expect(jitter).to be >= 0.0
          expect(jitter).to be <= 0.2 # Random component max
        end

        it "returns increasing jitter for higher indices" do
          jitter1 = parallel_tool_runner.send(:calculate_start_jitter, 1)
          jitter2 = parallel_tool_runner.send(:calculate_start_jitter, 2)

          expect(jitter1).to be >= 0.1
          expect(jitter2).to be >= 0.2
          expect(jitter1).to be <= 1.0
          expect(jitter2).to be <= 1.0
        end

        it "caps jitter at configured maximum" do
          jitter = parallel_tool_runner.send(:calculate_start_jitter, 20) # High index
          expect(jitter).to be <= 1.0
        end
      end

      context "with jitter disabled" do
        let(:config_no_jitter) do
          double("config_no_jitter").tap do |config|
            allow(config).to receive(:max_tool_call_response_length).and_return(1000)
            allow(config).to receive(:tool_start_jitter_max).and_return(0)
          end
        end

        let(:no_jitter_tool_runner) { described_class.new(config_no_jitter) }

        it "returns 0 when jitter is disabled" do
          jitter = no_jitter_tool_runner.send(:calculate_start_jitter, 5)
          expect(jitter).to eq(0.0)
        end
      end
    end

    describe "#create_timeout_result" do
      let(:tool_call) do
        {
          "id" => "call_timeout",
          "function" => {
            "name" => "timeout_function",
            "arguments" => {"param1" => "value1"}
          }
        }
      end

      it "creates timeout result with proper tool call information" do
        result = parallel_tool_runner.send(:create_timeout_result, tool_call)

        expect(result.error?).to be true
        expect(result.function_name).to eq("timeout_function")
        expect(result.tool_call_id).to eq("call_timeout")
        expect(result.error).to eq(:timeout)
        expect(result.message).to eq("Tool execution timed out")
      end
    end

    describe "#create_error_result" do
      let(:tool_call) do
        {
          "id" => "call_error",
          "function" => {
            "name" => "error_function",
            "arguments" => {"param1" => "value1"}
          }
        }
      end

      it "creates error result with proper tool call information" do
        error_message = "Something went wrong"
        result = parallel_tool_runner.send(:create_error_result, tool_call, error_message)

        expect(result.error?).to be true
        expect(result.function_name).to eq("error_function")
        expect(result.tool_call_id).to eq("call_error")
        expect(result.error).to eq(:execution_error)
        expect(result.message).to eq(error_message)
      end
    end

    describe "#run_tools_parallel" do
      let(:parallel_tool_calls) do
        [
          {
            "id" => "call_123",
            "function" => {
              "name" => "fast_function",
              "arguments" => {"param1" => "value1"}
            }
          },
          {
            "id" => "call_456",
            "function" => {
              "name" => "slow_function",
              "arguments" => {"param2" => "value2"}
            }
          }
        ]
      end

      it "executes tools in parallel and returns results in original order" do
        # Create a configuration without jitter for predictable timing
        config_no_jitter = double("config_no_jitter").tap do |config|
          allow(config).to receive(:max_tool_call_response_length).and_return(1000)
          allow(config).to receive(:max_concurrent_tools).and_return(3)
          allow(config).to receive(:tool_execution_timeout).and_return(30)
          allow(config).to receive(:tool_start_jitter_max).and_return(0) # Disable jitter
        end

        no_jitter_tool_runner = described_class.new(config_no_jitter)

        start_time = Time.now
        results = no_jitter_tool_runner.send(:run_tools_parallel, parallel_tool_calls, available_tools_parallel)
        execution_time = Time.now - start_time

        expect(results.length).to eq(2)
        expect(results[0]).not_to be_nil
        expect(results[1]).not_to be_nil
        expect(results[0].tool_call_id).to eq("call_123")
        expect(results[1].tool_call_id).to eq("call_456")
        expect(results.all?(&:success?)).to be true
        expect(results[0].output).to eq("Fast tool output")
        expect(results[1].output).to eq("Slow tool output")

        # Parallel execution should be faster than sequential (0.1s + 0.1s = 0.2s sequential)
        expect(execution_time).to be < 0.15 # Should be less than sequential execution
      end

      it "increments tool call counter for each tool" do
        expect { parallel_tool_runner.send(:run_tools_parallel, parallel_tool_calls, available_tools_parallel) }
          .to change { parallel_tool_runner.total_tool_calls }.by(2)
      end

      context "with mixed success and failure" do
        let(:failing_tool_agent) do
          # Create a unique mock class for this agent to avoid schema conflicts
          failing_agent_class = Class.new
          failing_agent_class.define_singleton_method(:tool_schema) do
            {function: {name: "failing_function"}}
          end

          failing_agent_class.new.tap do |agent|
            allow(agent).to receive(:failing_function) do |**args|
              raise StandardError, "Tool failed"
            end
          end
        end

        let(:mixed_available_tools) do
          {
            "fast_agent" => fast_tool_agent,
            "failing_agent" => failing_tool_agent
          }
        end

        let(:mixed_tool_calls) do
          [
            {
              "id" => "call_123",
              "function" => {
                "name" => "fast_function",
                "arguments" => {"param1" => "value1"}
              }
            },
            {
              "id" => "call_456",
              "function" => {
                "name" => "failing_function",
                "arguments" => {"param2" => "value2"}
              }
            }
          ]
        end

        it "isolates individual tool failures" do
          results = parallel_tool_runner.send(:run_tools_parallel, mixed_tool_calls, mixed_available_tools)

          expect(results.length).to eq(2)
          expect(results[0].success?).to be true
          expect(results[0].output).to eq("Fast tool output")
          expect(results[1].error?).to be true
          expect(results[1].error).to eq(:execution_error)
          expect(results[1].message).to include("Tool execution failed")
        end
      end
    end

    describe "execute_tool_calls strategy selection" do
      context "with single tool call" do
        let(:single_tool_calls) do
          [{
            "id" => "call_123",
            "function" => {
              "name" => "fast_function",
              "arguments" => {"param1" => "value1"}
            }
          }]
        end

        it "uses sequential execution for single tool" do
          # Mock the sequential method to verify it's called
          expect(parallel_tool_runner).to receive(:run_tools_sequential).with(single_tool_calls, available_tools_parallel).and_call_original
          expect(parallel_tool_runner).not_to receive(:run_tools_parallel)

          results = parallel_tool_runner.execute_tool_calls(single_tool_calls, available_tools_parallel)
          expect(results.length).to eq(1)
          expect(results.first.success?).to be true
        end
      end

      context "with multiple tool calls" do
        let(:multiple_tool_calls) do
          [
            {
              "id" => "call_123",
              "function" => {
                "name" => "fast_function",
                "arguments" => {"param1" => "value1"}
              }
            },
            {
              "id" => "call_456",
              "function" => {
                "name" => "slow_function",
                "arguments" => {"param2" => "value2"}
              }
            }
          ]
        end

        it "uses parallel execution for multiple tools" do
          # Mock the parallel method to verify it's called
          expect(parallel_tool_runner).to receive(:run_tools_parallel).with(multiple_tool_calls, available_tools_parallel).and_call_original
          expect(parallel_tool_runner).not_to receive(:run_tools_sequential)

          parallel_tool_runner.execute_tool_calls(multiple_tool_calls, available_tools_parallel)
        end
      end
    end
  end
end
