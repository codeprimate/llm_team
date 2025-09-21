# frozen_string_literal: true

require_relative "../agents/core/primary_agent"

module LlmTeam
  module CLI
    # Interactive CLI application with command handling and error recovery
    # 
    # Non-obvious behaviors:
    # - Resets statistics before each interaction for accurate per-query tracking
    # - Handles cross-platform screen clearing (clear/cls)
    # - Provides graceful error handling with environment variable guidance
    # - Uses high max_iterations (20) to allow complex multi-cycle workflows
    class Application
      def initialize
        @options = {}
      end

      def run
        parse_arguments
        primary_agent = LlmTeam::Agents::Core::PrimaryAgent.new(
          max_iterations: @options[:max_iterations] || 20,
          model: @options[:model]
        )

        if @options[:interactive]
          run_interactive_mode(primary_agent)
        else
          run_single_query_mode(primary_agent)
        end
      end

      def run_interactive_mode(primary_agent)
        puts "\n🤖 LLM Team Interactive Mode".blue.bold
        puts "=" * 50
        puts "Welcome! You can now interact with the LLM team directly.".green
        puts "Type your questions or requests, and the team will work together to help you."
        
        if @options[:verbose]
          puts "\n🔧 Configuration:".cyan
          puts "  Model: #{@options[:model] || 'deepseek/deepseek-chat-v3.1 (default)'}"
          puts "  Max Iterations: #{@options[:max_iterations]}"
          puts "  History Behavior: #{@options[:history_behavior]}"
        end
        
        puts "\n📋 Commands:".yellow
        puts "  'exit', 'quit', or 'q' - Exit the interactive mode"
        puts "  'help' - Show this help message"
        puts "  'clear' - Clear the screen and conversation history"
        puts "\n" + "=" * 50

        loop do
          print "\n💬 You: ".cyan
          user_input = $stdin.gets&.chomp&.strip

          # Handle EOF (Ctrl+D) or nil input
          if user_input.nil?
            puts "\n👋 Goodbye! Thanks for using the LLM Team!".green.bold
            break
          end

          # Reset statistics for accurate per-interaction tracking
          primary_agent.reset_all_stats

          # Handle empty input
          if user_input.empty?
            puts "⚠️  Please enter a question or request.".yellow
            next
          end

          # Handle exit commands
          if ["exit", "quit", "q"].include?(user_input.downcase)
            puts "\n👋 Goodbye! Thanks for using the LLM Team!".green.bold
            break
          end

          # Handle help command
          if user_input.downcase == "help"
            puts "\n📖 Help - Available Commands:".yellow.bold
            puts "  'exit', 'quit', or 'q' - Exit the interactive mode"
            puts "  'help' - Show this help message"
            puts "  'clear' - Clear the screen and conversation history"
            puts "  Any other text - Send as a query to the LLM team"
            next
          end

          # Handle clear command with cross-platform support
          if user_input.downcase == "clear"
            system("clear") || system("cls")
            primary_agent.clear_conversation
            puts "\n🤖 LLM Team Interactive Mode - Screen and conversation cleared".blue
            next
          end

          # Process user query with comprehensive error handling
          begin
            puts "\n🔄 Processing your request...".yellow.bold
            puts "─" * 50

            final_answer = primary_agent.respond(user_input)

            puts "\n" + "=" * 50
            puts "🎯 FINAL ANSWER:".green.bold
            puts "=" * 50
            puts final_answer
            puts "=" * 50
          rescue OpenAI::Error => e
            puts "\n❌ LLM Error: #{e.message}".red.bold
            puts "Please ensure your OPENROUTER_API_KEY environment variable is set.".yellow
            puts e.backtrace.join("\n") if ENV["DEBUG"]
          rescue => e
            puts "\n❌ Unexpected Error: #{e.class} - #{e.message}".red.bold
            puts e.backtrace.join("\n")
          end
        end
      end

      def run_single_query_mode(primary_agent)
        query = @options[:query]
        puts "\n🤖 LLM Team - Single Query Mode".blue.bold
        puts "=" * 50
        puts "Query: #{query}".green
        
        if @options[:verbose]
          puts "\n🔧 Configuration:".cyan
          puts "  Model: #{@options[:model] || 'deepseek/deepseek-chat-v3.1 (default)'}"
          puts "  Max Iterations: #{@options[:max_iterations]}"
          puts "  History Behavior: #{@options[:history_behavior]}"
        end
        
        puts "=" * 50

        # Reset statistics for accurate tracking
        primary_agent.reset_all_stats

        # Process the single query
        begin
          puts "\n🔄 Processing your request...".yellow.bold
          puts "─" * 50

          final_answer = primary_agent.respond(query)

          puts "\n" + "=" * 50
          puts "🎯 FINAL ANSWER:".green.bold
          puts "=" * 50
          puts final_answer
          puts "=" * 50
        rescue OpenAI::Error => e
          puts "\n❌ LLM Error: #{e.message}".red.bold
          puts "Please ensure your OPENROUTER_API_KEY environment variable is set.".yellow
          puts e.backtrace.join("\n") if ENV["DEBUG"]
          exit 1
        rescue => e
          puts "\n❌ Unexpected Error: #{e.class} - #{e.message}".red.bold
          puts e.backtrace.join("\n")
          exit 1
        end
      end

      private

      def parse_arguments
        args = ARGV.dup
        @options = {
          max_iterations: 20,
          model: nil,
          history_behavior: :last,
          verbose: false
        }

        while args.any?
          arg = args.shift

          case arg
          when "--help", "-h"
            show_help
            exit 0
          when "--version", "-v"
            show_version
            exit 0
          when "--max-iterations", "-i"
            @options[:max_iterations] = args.shift&.to_i || 20
          when "--model", "-m"
            @options[:model] = args.shift
            if @options[:model].nil?
              puts "❌ --model requires a model name".red
              exit 1
            end
          when "--history", "-H"
            behavior = args.shift&.to_sym
            if [:none, :last, :full].include?(behavior)
              @options[:history_behavior] = behavior
            else
              puts "❌ Invalid history behavior: #{behavior}. Must be none, last, or full".red
              exit 1
            end
          when "--agents-path"
            path = args.shift
            if path.nil?
              puts "❌ --agents-path requires a path".red
              exit 1
            end
            LlmTeam.configuration.auxiliary_agents_path = path
          when "--verbose"
            @options[:verbose] = true
          when "--query", "-q"
            # Non-interactive mode with single query
            query = args.shift
            if query
              @options[:query] = query
              @options[:interactive] = false
            else
              puts "❌ --query requires a query string".red
              exit 1
            end
          else
            if arg.start_with?("-")
              puts "❌ Unknown option: #{arg}".red
              show_help
              exit 1
            else
              # Treat as query for non-interactive mode
              @options[:query] = arg
              @options[:interactive] = false
            end
          end
        end

        # Set default mode
        @options[:interactive] = true unless @options.key?(:interactive)
      end

      def show_help
        puts <<~HELP
          🤖 LLM Team - Multi-Agent LLM Orchestration System

          Usage: llm_team [options] [query]

          Options:
            -h, --help              Show this help message
            -v, --version           Show version information
            -i, --max-iterations N  Set maximum iterations (default: 20)
            -m, --model MODEL       Set LLM model (default: deepseek/deepseek-chat-v3.1)
            -H, --history BEHAVIOR  Set history behavior: none, last, full (default: last)
            --agents-path PATH      Set path for auxiliary agents
            --verbose               Enable verbose output
            -q, --query QUERY       Run in non-interactive mode with single query

          Examples:
            llm_team                                    # Interactive mode
            llm_team "What is machine learning?"        # Single query mode
            llm_team -q "Explain quantum computing"     # Single query mode
            llm_team -i 10 -H full                     # Custom iterations and history
            llm_team --model "gpt-4" --verbose         # Custom model with verbose output
            llm_team --agents-path ./my_agents         # Load auxiliary agents from directory

          Environment Variables:
            OPENROUTER_API_KEY               Your OpenRouter API key (required)
            LLM_TEAM_AUXILIARY_AGENTS_PATH   Default path for auxiliary agents

          Interactive Commands:
            exit, quit, q           Exit the application
            help                    Show help
            clear                   Clear screen and conversation history
        HELP
      end

      def show_version
        puts "LLM Team v#{LlmTeam::VERSION}"
      end
    end
  end
end
