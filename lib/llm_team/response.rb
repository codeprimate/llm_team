# frozen_string_literal: true

module LlmTeam
  # Structured response object containing answer, performance metrics, and conversation context
  #
  # This class aggregates data from PrimaryAgent instance variables and provides
  # a clean interface for accessing response data, performance metrics, and
  # conversation context for debugging and analysis.
  class Response
    attr_reader :answer, :tokens_used, :latency_ms, :agent_info, :conversation_context, :error

    def initialize(primary_agent, answer, error: nil)
      @answer = answer
      @error = error

      # Extract performance data from PrimaryAgent instance
      @tokens_used = extract_total_tokens(primary_agent)
      @latency_ms = extract_total_latency(primary_agent)
      @agent_info = extract_agent_info(primary_agent)
      @conversation_context = extract_conversation_context(primary_agent)

      # Freeze the object to make it immutable
      freeze
    end

    # Convert response to hash for serialization
    def to_hash
      {
        answer: @answer,
        tokens_used: @tokens_used,
        latency_ms: @latency_ms,
        agent_info: @agent_info,
        conversation_context: @conversation_context,
        error: @error
      }
    end

    # Check if response contains an error
    def error?
      !@error.nil?
    end

    # Check if response was successful
    def success?
      @error.nil?
    end

    private

    # Extract total token usage from primary agent and all tool agents
    def extract_total_tokens(primary_agent)
      return 0 unless primary_agent.respond_to?(:get_total_token_usage)

      begin
        primary_agent.get_total_token_usage
      rescue => e
        # Handle cases where performance data is unavailable
        0
      end
    end

    # Extract total latency from primary agent and all tool agents
    def extract_total_latency(primary_agent)
      return 0 unless primary_agent.instance_variable_defined?(:@total_latency_ms)

      begin
        primary_latency = primary_agent.instance_variable_get(:@total_latency_ms) || 0

        # Add tool agent latencies
        tool_latency = 0
        if primary_agent.instance_variable_defined?(:@available_tools)
          available_tools = primary_agent.instance_variable_get(:@available_tools) || {}
          tool_latency = available_tools.values.sum do |agent|
            agent.instance_variable_get(:@total_latency_ms) || 0
          end
        end

        primary_latency + tool_latency
      rescue => e
        # Handle cases where performance data is unavailable
        0
      end
    end

    # Extract detailed agent information including individual performance metrics
    def extract_agent_info(primary_agent)
      agent_info = {}

      begin
        # Primary agent info
        agent_info[:primary_agent] = {
          name: primary_agent.name,
          tokens_used: primary_agent.instance_variable_get(:@total_tokens_used) || 0,
          latency_ms: primary_agent.instance_variable_get(:@total_latency_ms) || 0,
          llm_calls_count: primary_agent.instance_variable_get(:@llm_calls_count) || 0,
          tool_calls_count: primary_agent.instance_variable_get(:@total_tool_calls) || 0
        }

        # Tool agents info
        if primary_agent.instance_variable_defined?(:@available_tools)
          available_tools = primary_agent.instance_variable_get(:@available_tools) || {}
          agent_info[:tool_agents] = {}

          available_tools.each do |tool_name, agent|
            agent_info[:tool_agents][tool_name] = {
              name: agent.name,
              tokens_used: agent.instance_variable_get(:@total_tokens_used) || 0,
              latency_ms: agent.instance_variable_get(:@total_latency_ms) || 0,
              llm_calls_count: agent.instance_variable_get(:@llm_calls_count) || 0,
              tool_calls_count: agent.instance_variable_get(:@total_tool_calls) || 0
            }
          end
        end

        # Summary statistics
        total_tokens = agent_info[:primary_agent][:tokens_used] +
          agent_info[:tool_agents].values.sum { |info| info[:tokens_used] }
        total_latency = agent_info[:primary_agent][:latency_ms] +
          agent_info[:tool_agents].values.sum { |info| info[:latency_ms] }
        total_calls = agent_info[:primary_agent][:llm_calls_count] +
          agent_info[:tool_agents].values.sum { |info| info[:llm_calls_count] }

        agent_info[:summary] = {
          total_tokens_used: total_tokens,
          total_latency_ms: total_latency,
          total_llm_calls: total_calls,
          tool_agents_count: agent_info[:tool_agents].size
        }
      rescue => e
        # Handle cases where performance data is unavailable
        agent_info = {
          primary_agent: {name: primary_agent.name, error: "Performance data unavailable"},
          tool_agents: {},
          summary: {error: "Performance data extraction failed"}
        }
      end

      agent_info
    end

    # Extract full conversation context for debugging and analysis
    def extract_conversation_context(primary_agent)
      return [] unless primary_agent.instance_variable_defined?(:@conversation)

      begin
        conversation = primary_agent.instance_variable_get(:@conversation)
        return [] unless conversation.respond_to?(:conversation_history)

        # Get conversation history with proper error handling
        conversation.conversation_history || []
      rescue => e
        # Handle cases where conversation data is unavailable
        []
      end
    end
  end
end
