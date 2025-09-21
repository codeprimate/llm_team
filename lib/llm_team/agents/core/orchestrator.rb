# frozen_string_literal: true

require_relative "../../core/agent"
require_relative "research_agent"
require_relative "critic_agent"
require_relative "presenter_agent"

module LlmTeam
  module Agents
    module Core
      # Orchestrator implementing structured research-critique-synthesis workflow
      # 
      # Non-obvious behaviors:
      # - Uses :last history behavior to maintain context across iterations
      # - Implements 3-cycle limit to prevent infinite loops
      # - Special execute_tool override for presenter to extract conversation context
      # - Aggregates performance metrics across all tool agents
      # - Never critiques the critic's output (prevents recursive loops)
      class Orchestrator < LlmTeam::Core::Agent
        SYSTEM_PROMPT = <<~PROMPT
          You are an intelligent orchestrator managing a team of specialized AI agents.
          Your role is to follow a systematic decision tree workflow to provide comprehensive responses.

          DECISION TREE WORKFLOW:
          Follow this exact decision tree to determine your next action:
          
          START: User asks a question
          ↓
          Use research tool to gather initial information
          ↓
          Use presenter tool to synthesize a comprehensive response from available information
          ↓
          ALWAYS: Use critic tool to review the synthesized response
          ↓
          Check the critic's "ITERATION RECOMMENDATION":
          ├─ "Continue with another research/response/critique cycle" → 
          │   ├─ Check "RESEARCH NEEDED" section for specific areas
          │   ├─ Use research tool for those specific areas
          │   ├─ Use presenter tool to synthesize improved response
          │   ├─ ALWAYS: Use critic tool to review the improved response
          │   └─ Repeat until critic says "Ready for final synthesis"
          │
          └─ "Ready for final synthesis" → 
              ↓
              END: Present the synthesized response as final answer
          
          TERMINATION SAFEGUARDS:
          - Maximum 3 research/critique cycles to prevent infinite loops
          - If you reach 3 cycles, proceed to final synthesis regardless
          - Never critique the critic's output (prevents recursive loops)

          CRITICAL RULES:
          1. ALWAYS follow the decision tree exactly - do not skip steps
          2. ALWAYS use the critic tool after every synthesis
          3. ALWAYS check the critic's "ITERATION RECOMMENDATION" before proceeding
          4. If the critic says "Continue", do more research on the specific areas it identifies
          5. If the critic says "Ready for final synthesis", present the current response as final
          6. Never critique the critic's output - this prevents infinite loops
          7. After 3 complete cycles, stop iterating and present the current response as final

          TOOL USAGE:
          - Research tools: Gather information on topics or specific areas identified by the critic
          - Presenter tool: Synthesize information into coherent responses
          - Critic tool: Review responses and determine if more work is needed
          - Never use tools outside of this decision tree workflow
        PROMPT

        def initialize(history_behavior: :last, max_iterations: 10, model: nil)
          super("Orchestrator", history_behavior: history_behavior, max_iterations: max_iterations, model: model)

          # Register tool agents for orchestration
          register_tool(:research, ResearchAgent.new(model: model))
          register_tool(:critic, CriticAgent.new(model: model))
          register_tool(:presenter, PresenterAgent.new(model: model))
        end

        # Main orchestration entry point with performance reporting
        def respond(user_query)
          puts "\n🎯 Processing query: #{user_query}".blue.bold

          # Execute structured workflow via tool calling
          result = process_with_tools(user_query, temperature: 0.7)

          puts "\n🎯 CONVERSATION COMPLETE - Total tokens used: #{get_total_token_usage}".green.bold

          report_latency
          result
        end

        # Special tool execution override for presenter agent context extraction
        # 
        # Non-obvious behavior:
        # - Presenter needs original query and accumulated tool results from conversation history
        # - Other tools use standard argument passing from LLM function calls
        def execute_tool(tool_agent, function_name, arguments)
          if function_name == "synthesize_response"
            # Extract context from conversation history for presenter
            original_query = @conversation.last_user_message&.dig(:content)
            agent_results = extract_agent_results_from_history
            tool_agent.public_send(function_name, original_query: original_query, agent_results: agent_results)
          else
            tool_agent.public_send(function_name, **arguments)
          end
        end

        # Aggregate token usage across orchestrator and all tool agents
        def get_total_token_usage
          orchestrator_tokens = @total_tokens_used
          tool_agent_tokens = @available_tools.values.sum { |agent| agent.instance_variable_get(:@total_tokens_used) }
          orchestrator_tokens + tool_agent_tokens
        end

        # Reset performance metrics for orchestrator and all tool agents
        def reset_all_stats
          puts "\n🔄 Resetting statistics for all agents...".blue.bold
          reset_stats
          @available_tools.each do |tool_name, agent|
            agent.reset_stats
          end
          puts "✅ All agent statistics have been reset".green.bold
        end

        # Clear conversation state for orchestrator and all tool agents
        def clear_conversation
          puts "\n🧹 Clearing conversation history for all agents...".blue.bold
          super # Clear orchestrator's own conversation history
          @available_tools.each do |tool_name, agent|
            agent.clear_conversation
          end
          puts "✅ All agent conversation histories have been cleared".green.bold
        end

        # Comprehensive latency reporting across all agents with averages
        def report_latency
          puts "\n📊 LATENCY REPORT".blue.bold
          puts "─" * 30

          # Orchestrator latency
          puts "🎯 Orchestrator: #{format_latency(@total_latency_ms)} (#{@llm_calls_count} calls)".cyan

          # Tool agents latency aggregation
          total_tool_latency = 0
          total_tool_calls = 0

          @available_tools.each do |tool_name, agent|
            agent_latency = agent.instance_variable_get(:@total_latency_ms)
            agent_calls = agent.instance_variable_get(:@llm_calls_count)

            if agent_latency > 0
              puts "🔧 #{agent.name}: #{format_latency(agent_latency)} (#{agent_calls} calls)".light_black
              total_tool_latency += agent_latency
              total_tool_calls += agent_calls
            end
          end

          # Total system latency
          total_latency = @total_latency_ms + total_tool_latency
          total_calls = @llm_calls_count + total_tool_calls

          puts "─" * 30
          puts "📈 TOTAL: #{format_latency(total_latency)} (#{total_calls} LLM calls)".green.bold

          if total_calls > 0
            avg_latency = (total_latency / total_calls).round(2)
            puts "📊 Average per call: #{format_latency(avg_latency)}".light_black
          end

          puts "─" * 30
        end
      end
    end
  end
end
