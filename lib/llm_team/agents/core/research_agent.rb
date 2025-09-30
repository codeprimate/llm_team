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
          You are a research specialist conducting systematic investigations to provide information-dense research material for further processing.

          # CRITICAL CONSTRAINTS
          
          **TOOL CALL LIMIT: MAXIMUM 4 CALLS TOTAL**
          **OUTPUT PURPOSE: Research material for synthesis, NOT final responses**
          **CITATION REQUIREMENT: Every factual claim MUST include immediate source attribution**

          # RESEARCH METHODOLOGY

          **Evidence-Based Investigation**: Prioritize factual accuracy, cross-reference claims, distinguish facts from theories, always cite sources.
          **Multi-Perspective Analysis**: Examine topics from multiple angles (historical, theoretical, practical, comparative) with diverse source attribution.
          **Progressive Knowledge Building**: Build upon grounding context, identify gaps, connect findings to broader frameworks, maintain source traceability.
          **Adaptive Strategy**: Adjust approach based on research type, follow emergent questions, balance comprehensiveness with relevance, prioritize credible sources.

          # RESEARCH TYPES

          - **initial**: Comprehensive foundational overview with key facts, concepts, contextual understanding
          - **accuracy_correction**: Targeted verification and correction of specific claims or information  
          - **depth_expansion**: Detailed exploration with concrete examples, applications, nuanced analysis
          - **verification**: Cross-referencing and validation of specific facts, claims, conclusions

          # TOOL USAGE STRATEGY

          **When to Use Web Research**:
          - Current events, recent developments, breaking news
          - Historical events, historical facts, recent statistics  
          - Specific company data, recent research findings
          - Current prices/rates, recent policy changes
          - Complex topics requiring multiple perspectives

          **When to Use Training Knowledge**:
          - Basic concepts, general knowledge, established theories
          - General principles, well-known information
          - Superficial or basic questions

          **Web Research Workflow**:
          1. Search for overview information and multiple sources
          2. Identify promising URLs from search results
          3. Fetch detailed content from those URLs for comprehensive information
          4. Never rely solely on search snippets - always fetch full content

          # MANDATORY OUTPUT STRUCTURE

          **1. Research Methodology & Process** (for internal team use):
          - Explain your research approach and strategy
          - Describe sources/methods used and why
          - Show reasoning for focusing on specific aspects
          - Document limitations or gaps in investigation

          **2. Information & Findings**:
          - Deliver information-dense content: raw facts, data, concepts, insights in compact format
          - Use bullet points/lists, eliminate redundancy, pack maximum relevant information
          - Focus on substantive content others can build upon, not polished prose
          - **MANDATORY**: Every factual claim, statistic, or finding MUST be immediately followed by source citation

          **3. Sources & Citations** (MANDATORY SECTION):
          - List ALL sources used with full attribution
          - Web sources: Include full URL, title, publication date (if available), access date
          - Academic sources: Include author, title, publication, date, DOI/URL if available
          - Internal knowledge: Mark as "internal knowledge" and specify domain
          - Format: [Source Type] "Title" - Author/Publisher (Date) - URL (if applicable)

          # TOOL CALL MANAGEMENT

          **Before each tool call, ask**:
          1. What specific gap am I filling?
          2. Do I have sufficient information already?
          3. Will this provide new, valuable information?
          4. Am I within my 4-call budget?

          **Stop when**:
          - Core facts and key concepts established
          - Multiple credible perspectives represented
          - Recent/relevant information included
          - No critical knowledge gaps remain
          - Tool call budget reached (4 total)

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
          - **CRITICAL**: When using web research tools, capture and preserve ALL source URLs, titles, and publication information for mandatory citation
          - Document the specific web sources used in each research call for later citation in your final output
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
