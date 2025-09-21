# frozen_string_literal: true

require_relative "errors"

module LlmTeam
  class Configuration
    # API Configuration
    attr_accessor :api_key, :api_base_url, :model, :max_iterations

    # Model Parameters Configuration
    attr_accessor :temperature

    # Agent Configuration
    attr_accessor :default_history_behavior, :auxiliary_agents, :auxiliary_agents_path

    # Performance Configuration
    attr_accessor :max_retries, :retry_delay, :timeout

    # Logging Configuration
    attr_accessor :log_level, :enable_performance_tracking

    def initialize
      # API Configuration
      @api_key = ENV["OPENROUTER_API_KEY"]
      @api_base_url = ENV["OPENROUTER_API_BASE_URL"] || "https://openrouter.ai/api/v1"
      @model = ENV["LLM_TEAM_MODEL"] || "deepseek/deepseek-chat-v3.1"
      @max_iterations = (ENV["LLM_TEAM_MAX_ITERATIONS"] || "5").to_i

      # Model Parameters Configuration
      @temperature = (ENV["LLM_TEAM_TEMPERATURE"] || "0.7").to_f

      # Agent Configuration
      @default_history_behavior = (ENV["LLM_TEAM_HISTORY_BEHAVIOR"] || "none").to_sym
      @auxiliary_agents = []
      @auxiliary_agents_path = ENV["LLM_TEAM_AUXILIARY_AGENTS_PATH"] # or path relative to the current file
      @auxiliary_agents_path = File.join(File.dirname(__FILE__), "agents", "auxiliary") if @auxiliary_agents_path.nil? || @auxiliary_agents_path.empty?

      # Performance Configuration
      @max_retries = (ENV["LLM_TEAM_MAX_RETRIES"] || "3").to_i
      @retry_delay = (ENV["LLM_TEAM_RETRY_DELAY"] || "1").to_f
      @timeout = (ENV["LLM_TEAM_TIMEOUT"] || "30").to_i

      # Logging Configuration
      @log_level = (ENV["LLM_TEAM_LOG_LEVEL"] || "info").to_sym
      @enable_performance_tracking = ENV["LLM_TEAM_PERFORMANCE_TRACKING"] != "false"
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

    # Auxiliary agent management
    def enable_auxiliary_agent(agent_name)
      @auxiliary_agents << agent_name.to_s unless @auxiliary_agents.include?(agent_name.to_s)
    end

    def disable_auxiliary_agent(agent_name)
      @auxiliary_agents.delete(agent_name.to_s)
    end

    def auxiliary_agent_enabled?(agent_name)
      @auxiliary_agents.include?(agent_name.to_s)
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
        auxiliary_agents: @auxiliary_agents.dup,
        auxiliary_agents_path: @auxiliary_agents_path,
        max_retries: @max_retries,
        retry_delay: @retry_delay,
        timeout: @timeout,
        log_level: @log_level,
        enable_performance_tracking: @enable_performance_tracking
      }
    end

    def reset!
      initialize
    end
  end
end
