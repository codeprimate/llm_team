# frozen_string_literal: true

require_relative "../../core/agent"

module LlmTeam
  module Agents
    module Core
      # Research agent with contextual research modes and grounding support
      # 
      # Non-obvious behaviors:
      # - Supports 4 research types: initial, accuracy_correction, depth_expansion, verification
      # - Uses grounding_context to build upon or correct existing information
      # - Always includes original_user_request for scope context
      # - Defaults to :none history behavior (stateless research)
      class ResearchAgent < LlmTeam::Core::Agent
        SYSTEM_PROMPT = <<~PROMPT
          You are a research assistant specializing in accurate, well-sourced information.
          
          Research Types:
          - initial: Provide comprehensive overview with key facts and brief summary
          - accuracy_correction: Focus on verifying and correcting specific claims mentioned in the grounding context
          - depth_expansion: Provide detailed examples and practical applications for the specific focus area
          - verification: Cross-reference and verify specific claims or facts
          
          Always be accurate, informative, and well-organized in your responses.
          When grounding context is provided, use it to understand what to build upon, verify, or correct.
          When specific focus areas are mentioned, prioritize those aspects in your research.
        PROMPT

        def initialize(history_behavior: :none, model: nil)
          super("ResearchAgent", history_behavior: history_behavior, model: model)
        end

        # Research execution with structured context building
        def execute_research(topic:, original_user_request:, research_type: "initial", grounding_context: nil)
          context_parts = []
          context_parts << "Research topic: #{topic}"
          context_parts << "Research type: #{research_type}"
          context_parts << "Original user request: #{original_user_request}"
          context_parts << "Grounding context: #{grounding_context}" if grounding_context

          process_with_tools(context_parts.join("\n\n"))
        end

        # Tool schema definition for LLM function calling
        def self.tool_schema
          {
            type: :function,
            function: {
              name: "execute_research",
              description: "Gathers concise information on a given topic with contextual guidance.",
              parameters: {
                type: :object,
                properties: {
                  topic: {
                    type: :string,
                    description: "The topic to research."
                  },
                  research_type: {
                    type: :string,
                    description: "Type of research approach needed",
                    enum: ["initial", "accuracy_correction", "depth_expansion", "verification"]
                  },
                  grounding_context: {
                    type: :string,
                    description: "Specific factual context or claims to build upon, verify, or correct (optional)"
                  },
                  original_user_request: {
                    type: :string,
                    description: "The user's original request for scope context"
                  }
                },
                required: ["topic", "original_user_request", "research_type"]
              }
            }
          }
        end
      end
    end
  end
end
