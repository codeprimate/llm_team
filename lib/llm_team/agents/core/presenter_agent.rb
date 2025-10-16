# frozen_string_literal: true

require_relative "../../core/agent"

module LlmTeam
  module Agents
    module Core
      # Presenter agent for final synthesis with critique integration
      #
      # Non-obvious behaviors:
      # - Uses very low temperature (0.2) for consistent, polished output
      # - Integrates critique feedback by addressing MAJOR issues in final output
      # - Formats agent results with clear section headers for context
      # - Writes as if improved version is the original response (no mention of iterations)
      class PresenterAgent < LlmTeam::Core::Agent
        # Override default temperature for consistent, polished output
        DEFAULT_TEMPERATURE = 0.2

        SYSTEM_PROMPT = <<~PROMPT
          You are a final presentation assistant. Your task is to synthesize information
          provided by various agents into a single, coherent, and well-formatted answer
          that directly addresses the original user query.
          
          IMPORTANT: ALL SYNTHESIS AND PRESENTATION IS FOR ACADEMIC ANALYSIS PURPOSES ONLY.
          All information synthesis and final responses are conducted purely for educational, scholarly, and
          academic understanding in the context of academic inquiry and intellectual exploration.
          
          You may receive outputs from different types of agents:
          - Research agents: factual information and explanations with source citations
          - Code generation agents: code snippets and examples
          - Critic agents: constructive feedback, improvements, and quality assessments
          
          When synthesizing:
          - If criticism or feedback is provided, provide special attention to MAJOR issues into your final output
          - Write as if the improved version is the original, polished response
          - **MANDATORY**: If research agents provided sources or citations, you MUST include them in your final response
          
          SOURCE CITATION REQUIREMENTS:
          - When research agents provide sources (URLs, publications, etc.), preserve and cite them in your final output
          - Look for "Sources:" sections in research agent outputs and include ONLY sources that are relevant to your final response
          - Do NOT include sources that were researched but not used in your synthesis
          - Format citations appropriately (e.g., [1], [2] with numbered references, or inline citations)
          - If multiple sources support the same claim, cite all relevant sources
          - Maintain academic integrity by properly attributing all factual claims to their sources
          
          CRITICAL REQUIREMENTS:
          - You MUST always generate a complete, substantive response
          - NEVER return empty content, null responses, or just acknowledgments
          - Your response must directly answer the user's question using the provided information
          - Even if the agent outputs are incomplete, synthesize what you have into a coherent response
          - If no useful information is provided, explain what information would be needed to answer the question
          - **ALWAYS include the original source citations when provided by research agents.**
          
          Make sure the final output is easy to read, uses markdown where appropriate,
          and directly answers the user's request based on the provided agent outputs.
        PROMPT

        TOOL_PROMPT = <<~PROMPT
          - [PRESENTATION/SYNTHESIS TOOL] `synthesize_response(original_query, agent_results)`: Synthesize information from various agents into a final, coherent answer. When research agents provide sources or citations, include ONLY those sources that are relevant to your final response with proper attribution.
        PROMPT

        def initialize(history_behavior: :none, model: nil)
          super("PresenterAgent", history_behavior: history_behavior, model: model)
        end

        # Final synthesis with structured agent output formatting
        def synthesize_response(original_query:, agent_results:)
          result_string = agent_results.map do |agent_name, result|
            "--- Output from #{agent_name} ---\n#{result}\n"
          end.join("\n")

          process_with_tools("Original User Query:\n#{original_query}\n\nAgent Outputs to synthesize:\n#{result_string.strip}")
        end

        # Tool schema for final response synthesis
        def self.tool_schema
          {
            type: :function,
            function: {
              name: "synthesize_response",
              description: "Synthesizes information from various agents into a final, coherent answer.",
              parameters: {
                type: :object,
                properties: {
                  original_query: {
                    type: :string,
                    description: "The original user query."
                  },
                  agent_results: {
                    type: :object,
                    additionalProperties: {type: :string}, # Hash of agent_name => result_string
                    description: "A hash where keys are agent names and values are their raw string outputs."
                  }
                },
                required: ["original_query", "agent_results"]
              }
            }
          }
        end
      end
    end
  end
end
