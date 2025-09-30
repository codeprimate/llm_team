# frozen_string_literal: true

require_relative "errors"

module LlmTeam
  class Configuration
    # API Configuration
    attr_accessor :api_key, :api_base_url, :model, :max_iterations

    # Model Parameters Configuration
    attr_accessor :temperature

    # Agent Configuration
    attr_accessor :default_history_behavior, :auxiliary_agents_paths, :max_tool_call_response_length

    # Performance Configuration
    attr_accessor :max_retries, :retry_delay, :timeout

    # Logging Configuration
    attr_accessor :log_level

    # Output Configuration
    attr_accessor :verbose, :quiet

    # SearXNG MCP Configuration
    attr_accessor :searxng_url

    DEFAULT_MODEL = "google/gemini-2.5-flash"
    DEFAULT_MAX_ITERATIONS = 5
    DEFAULT_TEMPERATURE = 0.7
    DEFAULT_HISTORY_BEHAVIOR = :none
    DEFAULT_AUXILIARY_AGENTS_PATH = File.join(File.dirname(__FILE__), "agents", "auxiliary")
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_RETRY_DELAY = 1
    DEFAULT_TIMEOUT = 30
    DEFAULT_LOG_LEVEL = :info
    DEFAULT_API_BASE_URL = "https://openrouter.ai/api/v1"
    DEFAULT_SEARXNG_URL = "http://localhost:7778"
    DEFAULT_VERBOSE = false
    DEFAULT_QUIET = false
    DEFAULT_MAX_TOOL_CALL_RESPONSE_LENGTH = 128000

    def initialize
      # API Configuration
      @api_key = ENV["OPENROUTER_API_KEY"]
      @api_base_url = ENV.fetch("OPENROUTER_API_BASE_URL", DEFAULT_API_BASE_URL)
      @model = ENV.fetch("LLM_TEAM_MODEL", DEFAULT_MODEL)
      @max_iterations = ENV.fetch("LLM_TEAM_MAX_ITERATIONS", DEFAULT_MAX_ITERATIONS.to_s).to_i

      # Model Parameters Configuration
      @temperature = ENV.fetch("LLM_TEAM_TEMPERATURE", DEFAULT_TEMPERATURE.to_s).to_f

      # Agent Configuration
      @default_history_behavior = ENV.fetch("LLM_TEAM_HISTORY_BEHAVIOR", DEFAULT_HISTORY_BEHAVIOR.to_s).to_sym
      @auxiliary_agents_paths = [ENV.fetch("LLM_TEAM_AUXILIARY_AGENTS_PATH", DEFAULT_AUXILIARY_AGENTS_PATH)]
      @max_tool_call_response_length = ENV.fetch("LLM_TEAM_MAX_TOOL_CALL_RESPONSE_LENGTH", DEFAULT_MAX_TOOL_CALL_RESPONSE_LENGTH).to_i

      # Performance Configuration
      @max_retries = ENV.fetch("LLM_TEAM_MAX_RETRIES", DEFAULT_MAX_RETRIES.to_s).to_i
      @retry_delay = ENV.fetch("LLM_TEAM_RETRY_DELAY", DEFAULT_RETRY_DELAY.to_s).to_f
      @timeout = ENV.fetch("LLM_TEAM_TIMEOUT", DEFAULT_TIMEOUT.to_s).to_i

      # Logging Configuration
      @log_level = ENV.fetch("LLM_TEAM_LOG_LEVEL", DEFAULT_LOG_LEVEL.to_s).to_sym

      # Output Configuration
      @verbose = ENV.fetch("LLM_TEAM_VERBOSE", DEFAULT_VERBOSE.to_s).downcase == "true"
      @quiet = ENV.fetch("LLM_TEAM_QUIET", DEFAULT_QUIET.to_s).downcase == "true"

      # SearXNG MCP Configuration
      @searxng_url = ENV.fetch("LLM_TEAM_SEARXNG_URL", DEFAULT_SEARXNG_URL)

      # Handle mutual exclusion: quiet overrides verbose
      @verbose = false if @quiet
    end

    # Validation
    def validate!
      raise MissingAPIKeyError, "API key is required. Set OPENROUTER_API_KEY environment variable." if @api_key.nil? || @api_key.empty?

      unless [:none, :last, :full].include?(@default_history_behavior)
        raise ConfigurationError, "Invalid history behavior: #{@default_history_behavior}. Must be :none, :last, or :full"
      end

      # Model parameter validation
      unless (0.0..2.0).cover?(@temperature)
        raise ConfigurationError, "Temperature must be between 0.0 and 2.0, got: #{@temperature}"
      end

      unless @max_iterations.positive?
        raise ConfigurationError, "Max iterations must be positive, got: #{@max_iterations}"
      end
    end

    # Model parameter helpers
    def model_parameters
      {
        temperature: @temperature
      }
    end

    # Configuration helpers
    def to_hash
      {
        api_key: @api_key,
        api_base_url: @api_base_url,
        model: @model,
        max_iterations: @max_iterations,
        temperature: @temperature,
        default_history_behavior: @default_history_behavior,
        auxiliary_agents_paths: @auxiliary_agents_paths,
        max_retries: @max_retries,
        retry_delay: @retry_delay,
        timeout: @timeout,
        log_level: @log_level,
        verbose: @verbose,
        quiet: @quiet,
        searxng_url: @searxng_url
      }
    end

    def reset!
      initialize
    end

    # Add an additional auxiliary agents path
    def add_auxiliary_agents_path(path)
      @auxiliary_agents_paths ||= []
      @auxiliary_agents_paths << path unless @auxiliary_agents_paths.include?(path)
    end
  end
end
