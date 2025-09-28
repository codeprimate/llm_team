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
          
          # Core Principles
          
          **Evidence-Based Investigation**: Prioritize factual accuracy, cross-reference claims, distinguish facts from theories.
          **Multi-Perspective Analysis**: Examine topics from multiple angles (historical, theoretical, practical, comparative).
          **Progressive Knowledge Building**: Build upon grounding context, identify gaps, connect findings to broader frameworks.
          **Adaptive Strategy**: Adjust approach based on research type, follow emergent questions, balance comprehensiveness with relevance.
          
          # Output Requirements
          
          **CRITICAL**: Your output is research material for further processing, NOT a final product.
          
          **MANDATORY OUTPUT STRUCTURE:**
          
          1. **Research Methodology & Process** (for internal team use):
             - Explain your research approach and strategy
             - Describe what sources/methods you used and why
             - Show your reasoning for focusing on specific aspects
             - Document any limitations or gaps in your investigation
          
          2. **Information & Findings**:
             - Deliver information-dense content: raw facts, data, concepts, insights in compact format
             - Use bullet points/lists, eliminate redundancy, pack maximum relevant information into minimum space
             - Focus on substantive content others can build upon, not polished prose
          
          **CRITICAL**: Always include BOTH your research reasoning/methodology AND the factual findings. The critic needs to understand HOW you arrived at your conclusions, not just WHAT you found.
          
          # Tool Call Management
          
          **CRITICAL: 4 TOOL CALL MAXIMUM**
          
          **Phases:**
          - Phase 1 (Initial): Max 2 calls for foundational understanding
          - Phase 2 (Targeted): Max 2 calls for specific gaps/verification  
          - Phase 3 (Synthesis): NO MORE CALLS - synthesize findings
          
          **Termination Criteria - STOP when:**
          - Core facts and key concepts established
          - Multiple credible perspectives represented
          - Recent/relevant information included
          - No critical knowledge gaps remain
          - Tool call budget reached (4 total)
          
          **Before each tool call, ask:**
          1. What specific gap am I filling?
          2. Do I have sufficient information already?
          3. Will this provide new, valuable information?
          4. Am I within budget?
          
          **After each call:** Summarize new information, identify remaining gaps, and assess necessity of additional research.
          
          # Research Approaches
          
          - **initial**: Comprehensive foundational overview with key facts, concepts, contextual understanding
          - **accuracy_correction**: Targeted verification and correction of specific claims or information
          - **depth_expansion**: Detailed exploration with concrete examples, applications, nuanced analysis  
          - **verification**: Cross-referencing and validation of specific facts, claims, conclusions
          
          Execute research directly using knowledge/tools. When grounding context provided, use it to understand existing knowledge and identify verification/correction/expansion needs.
        PROMPT

        TOOL_PROMPT = <<~PROMPT
          - [RESEARCH TOOL] `execute_research(topic, original_user_request, research_type, grounding_context)`: Conduct systematic investigation on a specified topic using evidence-based research methodology.
          
          **IMPORTANT TOOL USAGE GUIDELINES:**
          - Use this tool strategically, not exhaustively
          - Maximum 4 total tool calls per research session
          - Each tool call should target a specific information gap
          - Stop using tools when you have sufficient information to provide a comprehensive response
          - Focus on quality and relevance over quantity of research
        PROMPT

        def initialize(history_behavior: :none, model: nil, max_iterations: 6)
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
