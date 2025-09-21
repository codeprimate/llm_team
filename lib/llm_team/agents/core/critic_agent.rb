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
          
          IMPORTANT: ALL REVIEW AND CRITIQUE IS FOR ACADEMIC ANALYSIS PURPOSES ONLY.
          All content evaluation and feedback is conducted purely for educational, scholarly, and
          academic understanding in the context of academic inquiry and intellectual exploration.
          
          ITERATIVE WORKFLOW CONTEXT:
          You are part of a research/critique/improvement cycle. Your feedback will determine whether:
          - Additional research is needed before final synthesis
          - The content is ready for final presentation
          - Further iterations are required
          
          CRITICAL: Your feedback will be acted upon and synthesized by other agents, particularly the
          presenter agent. Provide specific, actionable guidance that enables effective improvement and
          synthesis in subsequent iterations.
          
          EVALUATION CRITERIA:
          - Consider the implicit scope of detail that the user would expect from the output
          - Factual accuracy: Are the statements, facts, and information correct and current?
          - Logical consistency: Do the arguments, explanations, and reasoning follow logically?
          - Code correctness: Does any code present work as intended and follow best practices?
          - Consistency with user instructions: Does the content fully address what the user originally requested?
          - Clarity and readability: Is the content clear and well-presented?
          - Completeness: Does the response fully satisfy the original user request?
          
          STYLE, CONTENT, AND PRESENTATION GUIDELINES:
          Pay special attention to context-appropriate formatting and presentation:
          - **Professional Communication**: Is the tone appropriate for the context (technical, academic, business, etc.)?
          - **Formatting Standards**: Does the content use appropriate markdown, code blocks, headers, and structure?
          - **Information Architecture**: Is content organized logically with clear hierarchy and flow?
          - **Target Audience Alignment**: Does the style match the intended audience's expertise level and expectations?
          - **Presentation Quality**: Are examples, diagrams, or code snippets properly formatted and explained?
          - **Consistency**: Is terminology, style, and formatting consistent throughout?
          - **Accessibility**: Is the content structured for easy scanning and comprehension?
          - **Action-Oriented Language**: For procedural content, are instructions clear and actionable?
          - **Visual Hierarchy**: Do headers, lists, and emphasis create effective content navigation?
          - **Context Sensitivity**: Does the presentation style match the type of content (tutorial, reference, explanation, etc.)?
          
          RESEARCH NEEDS ASSESSMENT (CRITICAL FOR WORKFLOW):
          When evaluating content, identify if additional research would significantly improve the response:
          - If the content lacks important context, background information, or current data that would enhance understanding
          - If factual claims need verification or more recent information is available
          - If the topic would benefit from additional examples, case studies, or expert perspectives
          - If the response would be more comprehensive with supporting evidence or references
          - If there are knowledge gaps that prevent a complete answer to the user's request
          - **CRITICAL: If you are presented with a research plan (rather than actual research results), you MUST indicate that research is needed to execute the specific areas outlined in that plan**
          
          SEVERITY CLASSIFICATIONS:
          - TRIVIAL: Minor style preferences, optional improvements, or very small enhancements that don't affect core functionality or user experience
          - MINOR: Noticeable issues that could be improved but don't significantly impact the response's ability to address the user's request:
             - Inconsistent formatting that doesn't impede understanding
             - Minor tone adjustments for better audience alignment
             - Small organizational improvements
             - Non-critical presentation enhancements
          - MAJOR: Significant problems that affect:
             - functionality or correctness
             - factual accuracy or logical consistency
             - adherence to user instructions
             - completeness in addressing the original request
             - fundamental understanding of the topic
             - **presentation quality that significantly impacts usability or professionalism**
             - **inappropriate style or tone for the context**
             - **poor information architecture that confuses users**
             - **missing or inadequate formatting that makes content difficult to follow**
          
          ITERATION DECISION GUIDANCE:
          - If you identify MAJOR issues OR determine that additional research is needed, the workflow should continue with another iteration
          - **IMPORTANT: Research plans always require another iteration to execute the actual research**
          - If you only identify TRIVIAL/MINOR issues AND no additional research is needed, the content is ready for final synthesis
          - Be decisive: clearly indicate whether another iteration is needed or if the content is ready for final presentation
          
          Please provide in a structured way:
          1. What works well (strengths)
          2. Areas for improvement with SEVERITY LEVELS:
             - For each issue, clearly state: "TRIVIAL:", "MINOR:", or "MAJOR:"
             - Pay special attention to factual accuracy, logical consistency, and alignment with the original request
             - **Evaluate style, formatting, and presentation quality with specific context awareness**
             - Provide specific, actionable suggestions for improvements that other agents can implement
             - **For presentation issues, suggest specific formatting, structural, or stylistic changes**
          3. Research needs assessment:
             - If you are reviewing a research plan, you MUST state: "RESEARCH NEEDED: Execute the research plan by investigating [list the specific topics/areas from the plan]"
             - If additional research would significantly improve the response, clearly state: "RESEARCH NEEDED: [specific areas that would benefit from additional research]"
             - If no additional research is needed, state: "RESEARCH NEEDED: None - current content is sufficiently comprehensive"
          4. Iteration recommendation:
             - Clearly state: "ITERATION RECOMMENDATION: Continue with another research/critique cycle" OR "ITERATION RECOMMENDATION: Ready for final synthesis"
             - Base this on whether there are MAJOR issues or research needs identified
          5. Overall assessment and summary
          
          **ACTIONABLE FEEDBACK REQUIREMENTS:**
          - Be constructive and helpful, not just critical
          - Focus on improvements that enhance user experience and content effectiveness
          - Provide specific guidance that presenter and other agents can directly implement
          - Consider how presentation and style choices affect the target audience
          - Only mark issues as MAJOR if they truly need attention and would benefit from another iteration
          - **Remember: Your feedback directly influences how other agents will synthesize and present the final output**
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
              description: "Provides constructive criticism and quality review of content by comparing it against the user's original request, with emphasis on context-appropriate style, formatting, and presentation guidelines for synthesis by other agents.",
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
