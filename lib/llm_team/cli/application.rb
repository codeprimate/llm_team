# frozen_string_literal: true

require_relative "../agents/core/primary_agent"
require "tty-prompt"

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
        @last_response = nil
        @last_user_input = nil
      end

      def run
        parse_arguments

        # Set global configuration from CLI options
        LlmTeam.configuration.verbose = @options[:verbose] if @options[:verbose]
        LlmTeam.configuration.quiet = @options[:quiet] if @options[:quiet]
        LlmTeam.configuration.llm_provider = @options[:provider] if @options[:provider]

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
        LlmTeam::Output.puts("LLM Team Interactive Mode", type: :app)
        LlmTeam::Output.puts("=" * 50, type: :app)
        LlmTeam::Output.puts("Type your questions or requests, and the team will work together to help you.", type: :app)

        if @options[:verbose]
          LlmTeam::Output.puts("Configuration:", type: :debug)
          LlmTeam::Output.puts("  Provider: #{@options[:provider] || LlmTeam.configuration.llm_provider}", type: :debug)
          LlmTeam::Output.puts("  Model: #{@options[:model] || LlmTeam::Configuration::DEFAULT_MODEL}", type: :debug)
        end

        LlmTeam::Output.puts("Commands:", type: :app, color: :yellow)
        LlmTeam::Output.puts("  'exit', 'quit', or 'q' - Exit the interactive mode", type: :app)
        LlmTeam::Output.puts("  'help' - Show this help message", type: :app)
        LlmTeam::Output.puts("  'clear' - Clear the screen and conversation history", type: :app)
        LlmTeam::Output.puts("  'save' - Save the last query and response to a timestamped markdown file", type: :app)
        LlmTeam::Output.puts("", type: :app)
        LlmTeam::Output.puts("Input:", type: :app, color: :yellow)
        LlmTeam::Output.puts("  Type your query with full editing support (backspace, arrow keys)", type: :app)
        LlmTeam::Output.puts("  Press Ctrl+D when finished", type: :app)
        LlmTeam::Output.puts("\n" + "=" * 50, type: :app)

        loop do
          user_input = get_multiline_input

          # Handle EOF (Ctrl+D) or nil input
          if user_input.nil?
            LlmTeam::Output.puts("Goodbye! Thanks for using the LLM Team!", type: :app, color: [:green, :bold])
            break
          end

          # Reset statistics for accurate per-interaction tracking
          primary_agent.reset_all_stats

          # Handle empty input
          if user_input.empty?
            LlmTeam::Output.puts("Please enter a question or request.", type: :warning)
            next
          end

          # Handle exit commands
          if ["exit", "quit", "q"].include?(user_input.downcase)
            LlmTeam::Output.puts("Goodbye! Thanks for using the LLM Team!", type: :app, color: [:green, :bold])
            break
          end

          # Handle help command
          if user_input.downcase == "help"
            LlmTeam::Output.puts("Help - Available Commands:", type: :user, color: [:yellow, :bold])
            LlmTeam::Output.puts("  'exit', 'quit', or 'q' - Exit the interactive mode", type: :user)
            LlmTeam::Output.puts("  'help' - Show this help message", type: :user)
            LlmTeam::Output.puts("  'clear' - Clear the screen and conversation history", type: :user)
            LlmTeam::Output.puts("  'save' - Save the last query and response to a timestamped markdown file", type: :user)
            LlmTeam::Output.puts("  Any other text - Send as a query to the LLM team", type: :user)
            LlmTeam::Output.puts("", type: :user)
            LlmTeam::Output.puts("Input:", type: :user, color: [:yellow, :bold])
            LlmTeam::Output.puts("  Type your query with full editing support (backspace, arrow keys)", type: :user)
            LlmTeam::Output.puts("  Press Ctrl+D when finished", type: :user)
            next
          end

          # Handle clear command with cross-platform support
          if user_input.downcase == "clear"
            system("clear") || system("cls")
            primary_agent.clear_conversation
            @last_response = nil
            @last_user_input = nil
            LlmTeam::Output.puts("LLM Team Interactive Mode - Screen and conversation cleared", type: :app)
            next
          end

          # Handle save command
          if user_input.downcase == "save"
            save_last_answer
            next
          end

          # Process user query with comprehensive error handling
          begin
            LlmTeam::Output.puts("Querying Primary Agent...", type: :workflow, color: [:yellow, :bold])
            final_answer = primary_agent.respond(user_input)
            @last_response = final_answer
            @last_user_input = user_input

            LlmTeam::Output.final_answer(final_answer)
          rescue OpenAI::Error => e
            LlmTeam::Output.puts("LLM Error: #{e.message}", type: :error)
            LlmTeam::Output.puts("Please ensure your OPENROUTER_API_KEY environment variable is set.", type: :warning)
            LlmTeam::Output.puts(e.backtrace.join("\n"), type: :debug) if ENV["DEBUG"]
          rescue => e
            LlmTeam::Output.puts("Unexpected Error: #{e.class} - #{e.message}", type: :error)
            LlmTeam::Output.puts(e.backtrace.join("\n"), type: :debug)
          end
        end
      end

      def run_single_query_mode(primary_agent)
        query = @options[:query]
        LlmTeam::Output.puts("LLM Team - Single Query Mode", type: :app)
        LlmTeam::Output.puts("Query: #{query}", type: :app, color: :green)

        if @options[:verbose]
          LlmTeam::Output.puts("Configuration:", type: :debug)
          LlmTeam::Output.puts("  Provider: #{@options[:provider] || LlmTeam.configuration.llm_provider}", type: :debug)
          LlmTeam::Output.puts("  Model: #{@options[:model] || "deepseek/deepseek-chat-v3.1 (default)"}", type: :debug)
          LlmTeam::Output.puts("  Max Iterations: #{@options[:max_iterations]}", type: :debug)
          LlmTeam::Output.puts("  History Behavior: #{@options[:history_behavior]}", type: :debug)
        end

        # Reset statistics for accurate tracking
        primary_agent.reset_all_stats

        # Process the single query
        begin
          LlmTeam::Output.puts("Processing your request...", type: :workflow, color: [:yellow, :bold])

          final_answer = primary_agent.respond(query)

          LlmTeam::Output.final_answer(final_answer)
        rescue OpenAI::Error => e
          LlmTeam::Output.puts("LLM Error: #{e.message}", type: :error)
          LlmTeam::Output.puts("Please ensure your OPENROUTER_API_KEY environment variable is set.", type: :warning)
          LlmTeam::Output.puts(e.backtrace.join("\n"), type: :debug) if ENV["DEBUG"]
          exit 1
        rescue => e
          LlmTeam::Output.puts("Unexpected Error: #{e.class} - #{e.message}", type: :error)
          LlmTeam::Output.puts(e.backtrace.join("\n"), type: :debug)
          exit 1
        end
      end

      private

      # Determines if a query string is a file path and reads its content if it exists
      # Returns the file content if it's a valid file, otherwise returns the original string
      def resolve_query_content(query_string)
        return query_string if query_string.nil? || query_string.empty?

        # Check if the string looks like a file path (contains path separators or has a file extension)
        # and if it exists as a file
        if (query_string.include?("/") || query_string.include?("\\") || query_string.match?(/\.[a-zA-Z0-9]+$/)) &&
            File.exist?(query_string) && File.file?(query_string)

          begin
            file_content = File.read(query_string).strip
            LlmTeam::Output.puts("Reading query from file: #{query_string}", type: :debug) if @options[:verbose]
            return file_content
          rescue => e
            LlmTeam::Output.puts("Warning: Could not read file '#{query_string}': #{e.message}", type: :warning)
            LlmTeam::Output.puts("Using the string as-is instead.", type: :warning)
            return query_string
          end
        end

        # Return original string if it's not a file or doesn't exist
        query_string
      end

      # Handles multiline input using a custom implementation to avoid line duplication issues
      # Users can finish input by pressing Ctrl+D
      def get_multiline_input
        puts "Enter your query (Ctrl+D to finish):"
        lines = []

        begin
          loop do
            print "> "
            line = $stdin.gets
            break if line.nil? # Ctrl+D pressed

            lines << line.chomp
          end
        rescue Interrupt
          # Handle Ctrl+C gracefully
          puts "\nInput cancelled."
          return nil
        end

        # Join lines and clean up
        result = lines.join("\n").strip
        result.empty? ? nil : result
      end

      def save_last_answer
        if @last_response.nil?
          LlmTeam::Output.puts("No response to save. Please run a query first.", type: :warning)
          return
        end

        # Generate timestamp filename in format: llm_team_YYYYMMDD_HHMMSS.md
        timestamp = Time.now.strftime("%Y%m%d_%H%M%S")
        filename = "llm_team_#{timestamp}.md"

        # Create markdown content with two sections
        markdown_content = <<~MARKDOWN
          # LLM Team Session - #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}

          ## User Input

          #{@last_user_input}

          ## Response

          #{@last_response}
        MARKDOWN

        begin
          File.write(filename, markdown_content)
          LlmTeam::Output.puts("Response saved to: #{filename}", type: :status)
        rescue => e
          LlmTeam::Output.puts("Failed to save file: #{e.message}", type: :error)
        end
      end

      def parse_arguments
        args = ARGV.dup
        @options = {
          max_iterations: 20,
          model: nil,
          provider: nil,
          history_behavior: :last,
          verbose: false,
          quiet: false
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
          when "--model", "-m"
            @options[:model] = args.shift
            if @options[:model].nil?
              LlmTeam::Output.puts("--model requires a model name", type: :error)
              exit 1
            end
          when "--provider", "-p"
            provider = args.shift
            if provider.nil?
              LlmTeam::Output.puts("--provider requires a provider name", type: :error)
              exit 1
            end
            provider_sym = provider.to_sym
            unless [:openrouter, :openai, :ollama].include?(provider_sym)
              LlmTeam::Output.puts("Invalid provider: #{provider}. Supported providers: openrouter, openai, ollama", type: :error)
              exit 1
            end
            @options[:provider] = provider_sym
          when "--agents-path"
            path = args.shift
            if path.nil?
              LlmTeam::Output.puts("--agents-path requires a path", type: :error)
              exit 1
            end
            LlmTeam.configuration.add_auxiliary_agents_path(path)
          when "--verbose"
            @options[:verbose] = true
          when "--quiet"
            @options[:quiet] = true
            @options[:verbose] = false  # quiet overrides verbose
          when "--query", "-q"
            # Non-interactive mode with single query
            query = args.shift
            if query
              @options[:query] = resolve_query_content(query)
              @options[:interactive] = false
            else
              LlmTeam::Output.puts("--query requires a query string", type: :error)
              exit 1
            end
          else
            if arg.start_with?("-")
              LlmTeam::Output.puts("Unknown option: #{arg}", type: :error)
              show_help
              exit 1
            else
              # Treat as query for non-interactive mode
              @options[:query] = resolve_query_content(arg)
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
            -m, --model MODEL       Set LLM model (default: #{LlmTeam::Configuration::DEFAULT_MODEL})
            -p, --provider PROVIDER Set LLM provider (openrouter, openai, ollama) (default: openrouter)
            --agents-path PATH      Add additional path for auxiliary agents
            --verbose               Enable verbose output
            --quiet                 Enable quiet output (minimal output)
            -q, --query QUERY       Run in non-interactive mode with single query (supports file paths)

          Examples:
            llm_team                                    # Interactive mode
            llm_team "What is machine learning?"        # Single query mode
            llm_team -q "Explain quantum computing"     # Single query mode
            llm_team ./my_query.txt                     # Single query mode from file
            llm_team -q ./questions.md                  # Single query mode from file
            llm_team --model "gpt-4" --verbose         # Custom model with verbose output
            llm_team --provider ollama --model llama3.1 # Use Ollama with specific model
            llm_team -p openai -m gpt-4                # Use OpenAI with GPT-4
            llm_team --agents-path ./my_agents         # Load auxiliary agents from additional directory

          Environment Variables:
            LLM_TEAM_PROVIDER                LLM provider (openrouter, openai, ollama) (default: openrouter)
            LLM_TEAM_API_KEY                 API key for LLM provider (required for openrouter/openai)
            LLM_TEAM_BASE_URL                Base URL for LLM provider (auto-detected by provider)
            LLM_TEAM_MODEL                   Default model name (provider-specific)
            OPENROUTER_API_KEY               Legacy: OpenRouter API key (backward compatibility)
            LLM_TEAM_AUXILIARY_AGENTS_PATH   Default path for auxiliary agents
            LLM_TEAM_SEARXNG_URL             SearXNG MCP server URL (default: http://localhost:7778)

          Interactive Commands:
            exit, quit, q           Exit the application
            help                    Show help
            clear                   Clear screen and conversation history
            save                    Save the last query and response to a file

          Input:
            Type your query with full editing support (backspace, arrow keys)
            Press Ctrl+D when finished
        HELP
      end

      def show_version
        puts "LLM Team v#{LlmTeam::VERSION}"
      end
    end
  end
end
