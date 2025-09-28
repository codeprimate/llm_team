# frozen_string_literal: true

module LlmTeam
  module Core
    # Conversation management with dual history tracking and behavior modes
    # 
    # Key behaviors:
    # - Maintains separate conversation_history (per-call) and persistent_history (cross-calls)
    # - History behavior modes control what persists between calls: :none, :last, :full
    # - Filters out system prompts and datetime injections from history
    # - Provides conversation context building for LLM calls
    class Conversation
      attr_reader :conversation_history, :persistent_history, :history_behavior

      def initialize(history_behavior: :none)
        @history_behavior = history_behavior
        @conversation_history = [] # Ephemeral: current call only
        @persistent_history = [] # Persistent: survives across calls based on history_behavior
      end

      # Conversation context builder with history behavior modes
      # 
      # Non-obvious behaviors:
      # - :last mode finds last user+assistant pair, not just last message
      # - Filters out datetime injection messages and system prompts from history
      # - Always injects current timestamp as assistant message before user input
      # - :full mode preserves entire conversation except system/datetime messages
      def build_conversation_for_llm(system_prompt, new_user_message, history_behavior: nil)
        history_behavior ||= @history_behavior
        messages = []

        # System prompt always first (constant, never changes)
        if system_prompt
          messages << {role: LlmTeam::ROLE_SYSTEM, content: system_prompt}
        end

        # History behavior determines what context to include
        case history_behavior
        when :none
          # No conversation history - fresh start each time
        when :last
          # Extract last user-assistant pair for minimal context
          if @persistent_history.any?
            # Find last user message
            last_user_message = @persistent_history.reverse.find { |msg| msg[:role] == LlmTeam::ROLE_USER }

            # Find last assistant response (exclude tool calls and datetime injections)
            last_assistant_message = @persistent_history.reverse.find do |msg|
              msg[:role] == LlmTeam::ROLE_ASSISTANT &&
                msg[:content] &&
                !msg[:tool_calls] &&
                !msg[:content].include?("current date and time")
            end

            # Add both to maintain conversational context
            messages << last_user_message if last_user_message
            messages << last_assistant_message if last_assistant_message
          end
        when :full
          # Include entire conversation history (filtered)
          @persistent_history.each do |msg|
            # Skip system prompts and datetime injections
            next if msg[:role] == LlmTeam::ROLE_SYSTEM
            next if msg[:role] == LlmTeam::ROLE_ASSISTANT && msg[:content]&.include?("current date and time")
            messages << msg
          end
        else
          raise ArgumentError, "Invalid history_behavior: #{history_behavior}. Must be :none, :last, or :full"
        end

        # Always inject current timestamp before user message
        messages << {role: LlmTeam::ROLE_ASSISTANT, content: "--- The current date and time is #{Time.now.strftime("%Y-%m-%d %H:%M:%S")} ---\n\n"}
        messages << {role: LlmTeam::ROLE_USER, content: new_user_message}
        messages
      end

      # Post-processing history cleanup based on behavior mode
      # 
      # Non-obvious behaviors:
      # - :none mode clears all persistent history (fresh start each call)
      # - :last mode extracts and preserves only the final user-assistant pair
      # - :full mode preserves entire conversation including tool calls
      # - Always runs after completion, even on max-iterations or errors
      def cleanup_conversation_history(history_behavior)
        case history_behavior
        when :none
          # Complete reset - no memory between calls
          @persistent_history = []
        when :last
          # Extract final user-assistant pair for minimal context preservation
          if @conversation_history.any?
            # Find last user message
            last_user_message = @conversation_history.reverse.find { |msg| msg[:role] == LlmTeam::ROLE_USER }

            # Find last assistant response (exclude tool calls and datetime injections)
            last_assistant_message = @conversation_history.reverse.find do |msg|
              msg[:role] == LlmTeam::ROLE_ASSISTANT &&
                msg[:content] &&
                !msg[:tool_calls] &&
                !msg[:content].include?("current date and time")
            end

            # Store only the final pair in chronological order
            @persistent_history = []
            @persistent_history << last_user_message if last_user_message
            @persistent_history << last_assistant_message if last_assistant_message
          end
        when :full
          # Complete conversation preservation including tool interactions
          @persistent_history = @conversation_history.dup
        end
      end

      # Add message to conversation history
      def add_message(role, content, tool_calls: nil, tool_call_id: nil, name: nil)
        message = { role: role, content: content }
        message[:tool_calls] = tool_calls if tool_calls
        message[:tool_call_id] = tool_call_id if tool_call_id
        message[:name] = name if name
        
        @conversation_history << message
      end

      # Extract tool execution results from conversation history
      # 
      # Non-obvious behavior:
      # - Maps tool names to their output content for result aggregation
      # - Used by primary agent to collect results from multiple tool calls
      def extract_agent_results_from_history
        results = {}
        @conversation_history.each do |message|
          if message[:role] == LlmTeam::ROLE_TOOL
            results[message[:name].to_sym] = message[:content]
          end
        end
        results
      end

      # Find last user message in conversation history
      def last_user_message
        @conversation_history.reverse.find { |msg| msg[:role] == LlmTeam::ROLE_USER }
      end

      # Complete conversation state reset (both ephemeral and persistent)
      def clear_conversation
        @conversation_history = []
        @persistent_history = []
      end

      # Set conversation history (used for initialization from persistent history)
      def conversation_history=(history)
        @conversation_history = history.dup
      end

      # Get conversation history
      def conversation_history
        @conversation_history.dup
      end

      # Get persistent history
      def persistent_history
        @persistent_history.dup
      end
    end
  end
end
