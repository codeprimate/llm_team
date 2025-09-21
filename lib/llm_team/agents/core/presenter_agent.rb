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
          
          You may receive outputs from different types of agents:
          - Research agents: factual information and explanations
          - Code generation agents: code snippets and examples
          - Critic agents: constructive feedback, improvements, and quality assessments
          
          When synthesizing:
          - If criticism or feedback is provided, provide special attention to MAJOR issues into your final output
          - Write as if the improved version is the original, polished response
          
          Make sure the final output is easy to read, uses markdown where appropriate,
          and directly answers the user's request based on the provided agent outputs.
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
