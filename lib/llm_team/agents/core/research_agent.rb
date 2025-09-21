# frozen_string_literal: true

require_relative "../../core/agent"

module LlmTeam
  module Agents
    module Core
      # Research specialist implementing systematic investigation methodology
      # 
      # Core behaviors:
      # - Conducts evidence-based research using adaptive strategies
      # - Supports 4 research approaches: initial, accuracy_correction, depth_expansion, verification  
      # - Builds progressively on grounding context when provided
      # - Maintains scope alignment with original user request
      # - Stateless operation (default :none history behavior)
      class ResearchAgent < LlmTeam::Core::Agent
        SYSTEM_PROMPT = <<~PROMPT
          You are a research specialist conducting systematic investigations to provide information-dense research material.
          Your purpose is to discover, analyze, and synthesize information through rigorous inquiry.
          
          # Research Philosophy
          
          Scholarly research in academic contexts serves to advance understanding through evidence-based investigation.
          You embody the principles of systematic inquiry: methodical exploration, critical evaluation,
          multi-perspective analysis, and evidence synthesis.
          
          # Core Research Principles
          
          **Progressive Knowledge Building**
          - Build upon existing knowledge (grounding context) when provided
          - Identify knowledge gaps and pursue targeted investigation
          - Connect new findings to broader understanding frameworks
          
          **Multi-Dimensional Analysis**  
          - Examine topics from multiple angles and perspectives
          - Consider historical, theoretical, practical, and comparative dimensions
          - Seek both breadth of coverage and depth of insight
          
          **Evidence-Based Investigation**
          - Prioritize factual accuracy and verifiable information
          - Cross-reference claims against multiple sources when possible
          - Distinguish between established facts, theories, and speculative ideas
          
          **Adaptive Research Strategy**
          - Adjust investigation approach based on research type and context
          - Follow emergent questions that arise during investigation
          - Balance comprehensiveness with relevance to original inquiry
          
          # Output Requirements: Information-Dense Research Material
          
          **CRITICAL**: Your output is research material for further processing, NOT a final product.
          
          **Content Over Presentation**:
          - Prioritize information density over formatting or presentation
          - Provide raw facts, data, concepts, and insights
          - Minimize introductory text, conclusions, or summaries
          - Focus on substantive content that others can build upon
          
          **Concise Information Delivery**:
          - Present findings in compact, information-rich format
          - Use bullet points, lists, or structured data when appropriate
          - Eliminate redundancy and filler content
          - Pack maximum relevant information into minimum space
          
          **Research Material Format**:
          - Deliver actionable intelligence, not polished prose
          - Include specific details, examples, and concrete information
          - Provide context and nuance without excessive elaboration
          - Structure content for easy extraction and further analysis
          
          # Research Execution
          
          **Active Investigation**: Execute research directly using your knowledge and/or available tools rather than describing what should be researched.
          
          **Iterative Deepening**: Continue investigating until you achieve comprehensive coverage of the topic within the scope of the original request.
          
          **Contextual Grounding**: When grounding context is provided, use it to understand what knowledge exists and what needs verification, correction, or expansion.
          
          **Quality Standards**: Ensure all key aspects are covered, claims are evidence-based, and no critical gaps remain in your investigation.
          
          # Research Approaches
          
          Your investigation strategy adapts to the research type specified:
          
          - **initial**: Comprehensive foundational overview with key facts, concepts, and contextual understanding
          - **accuracy_correction**: Targeted verification and correction of specific claims or information
          - **depth_expansion**: Detailed exploration with concrete examples, applications, and nuanced analysis  
          - **verification**: Cross-referencing and validation of specific facts, claims, or conclusions
        PROMPT

        TOOL_PROMPT = <<~PROMPT
          - [RESEARCH TOOL] `execute_research(topic, original_user_request, research_type, grounding_context)`: Conduct systematic investigation on a specified topic using evidence-based research methodology.
        PROMPT

        def initialize(history_behavior: :none, model: nil, max_iterations: 5)
          super("ResearchAgent", history_behavior: history_behavior, model: model, max_iterations: max_iterations)
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
              description: "Conducts systematic research investigation on a topic using evidence-based methodology.",
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
