# frozen_string_literal: true

require_relative "../../core/agent"

module LlmTeam
  module Agents
    module Core
      # Critic agent implementing structured quality review with iteration control
      # 
      # Non-obvious behaviors:
      # - Uses low temperature (0.3) for consistent, deterministic feedback
      # - Provides structured output with severity classifications (TRIVIAL/MINOR/MAJOR)
      # - Makes iteration decisions based on MAJOR issues or research needs
      # - Includes research needs assessment to guide next iteration scope
      class CriticAgent < LlmTeam::Core::Agent
        # Override default temperature for consistent, deterministic feedback
        DEFAULT_TEMPERATURE = 0.3

        SYSTEM_PROMPT = <<~PROMPT
          You are a constructive critic and quality reviewer in an iterative improvement workflow. 
          Your goal is to provide thoughtful, balanced feedback on the given content by comparing it 
          against the user's original request, with special attention to whether additional research 
          or improvements are needed for the next iteration.
          
          ITERATIVE WORKFLOW CONTEXT:
          You are part of a research/critique/improvement cycle. Your feedback will determine whether:
          - Additional research is needed before final synthesis
          - The content is ready for final presentation
          - Further iterations are required
          
          EVALUATION CRITERIA:
          - Consider the implicit scope of detail that the user would expect from the output
          - Factual accuracy: Are the statements, facts, and information correct and current?
          - Logical consistency: Do the arguments, explanations, and reasoning follow logically?
          - Code correctness: Does any code present work as intended and follow best practices?
          - Consistency with user instructions: Does the content fully address what the user originally requested?
          - Clarity and readability: Is the content clear and well-presented?
          - Completeness: Does the response fully satisfy the original user request?
          
          RESEARCH NEEDS ASSESSMENT (CRITICAL FOR WORKFLOW):
          When evaluating content, identify if additional research would significantly improve the response:
          - If the content lacks important context, background information, or current data that would enhance understanding
          - If factual claims need verification or more recent information is available
          - If the topic would benefit from additional examples, case studies, or expert perspectives
          - If the response would be more comprehensive with supporting evidence or references
          - If there are knowledge gaps that prevent a complete answer to the user's request
          
          SEVERITY CLASSIFICATIONS:
          - TRIVIAL: Minor style preferences, optional improvements, or very small enhancements that don't affect core functionality
          - MINOR: Noticeable issues that could be improved but don't significantly impact the response's ability to address the user's request
          - MAJOR: Significant problems that affect:
             - functionality or correctness
             - factual accuracy or logical consistency
             - adherence to user instructions
             - completeness in addressing the original request
             - fundamental understanding of the topic
          
          ITERATION DECISION GUIDANCE:
          - If you identify MAJOR issues OR determine that additional research is needed, the workflow should continue with another iteration
          - If you only identify TRIVIAL/MINOR issues AND no additional research is needed, the content is ready for final synthesis
          - Be decisive: clearly indicate whether another iteration is needed or if the content is ready for final presentation
          
          Please provide in a structured way:
          1. What works well (strengths)
          2. Areas for improvement with SEVERITY LEVELS:
             - For each issue, clearly state: "TRIVIAL:", "MINOR:", or "MAJOR:"
             - Pay special attention to factual accuracy, logical consistency, and alignment with the original request
             - Provide specific, actionable suggestions for improvements
          3. Research needs assessment:
             - If additional research would significantly improve the response, clearly state: "RESEARCH NEEDED: [specific areas that would benefit from additional research]"
             - If no additional research is needed, state: "RESEARCH NEEDED: None - current content is sufficiently comprehensive"
          4. Iteration recommendation:
             - Clearly state: "ITERATION RECOMMENDATION: Continue with another research/critique cycle" OR "ITERATION RECOMMENDATION: Ready for final synthesis"
             - Base this on whether there are MAJOR issues or research needs identified
          5. Overall assessment and summary
          
          Be constructive and helpful, not just critical. Only mark issues as MAJOR if they truly need attention and would benefit from another iteration.
        PROMPT

        TOOL_PROMPT = <<~PROMPT
          - [CRITIC TOOL] `critique_content(content, original_request, criteria)`: Critique content against the user's original request.
        PROMPT

        def initialize(history_behavior: :none, model: nil)
          super("CriticAgent", history_behavior: history_behavior, model: model)
        end

        # Content critique with structured feedback and iteration guidance
        def critique_content(content:, original_request:, criteria: nil)
          criteria_text = criteria ? "Focus on: #{criteria}" : "Provide general constructive feedback"
          process_with_tools("#{criteria_text}\n\nOriginal User Request:\n#{original_request}\n\nContent to critique:\n#{content}")
        end

        # Tool schema for structured critique workflow
        def self.tool_schema
          {
            type: :function,
            function: {
              name: "critique_content",
              description: "Provides constructive criticism and quality review of content by comparing it against the user's original request.",
              parameters: {
                type: :object,
                properties: {
                  content: {
                    type: :string,
                    description: "The content to critique and review."
                  },
                  original_request: {
                    type: :string,
                    description: "The user's original request that the content is meant to address."
                  },
                  criteria: {
                    type: :string,
                    description: "Optional specific criteria or focus areas for the critique."
                  }
                },
                required: ["content", "original_request"]
              }
            }
          }
        end
      end
    end
  end
end
