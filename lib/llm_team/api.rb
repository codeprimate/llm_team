# frozen_string_literal: true

module LlmTeam
  # Module-level convenience methods for DSL-style API usage
  module API
    # Ask a question and get a structured response
    #
    # @param query [String] The question to ask
    # @return [LlmTeam::Response] Structured response with answer, performance data, and metadata
    def self.ask(query)
      # Validate configuration before proceeding
      LlmTeam.configuration.validate!

      # Create PrimaryAgent with current configuration
      primary_agent = LlmTeam::Agents::Core::PrimaryAgent.new

      # Call respond method and get the answer
      answer = primary_agent.respond(query)

      # Create Response object with performance data
      LlmTeam::Response.new(primary_agent, answer)
    rescue => e
      # Create Response object with error
      LlmTeam::Response.new(nil, nil, error: e.message)
    end

    # List all available auxiliary agents
    #
    # @return [Array<Symbol>] Array of available auxiliary agent tool names
    def self.list_auxiliary_agents
      get_auxiliary_agent_tool_names
    end

    # Check if a specific auxiliary agent is loaded
    #
    # @param name [String, Symbol] The auxiliary agent name to check
    # @return [Boolean] True if the auxiliary agent is available
    def self.auxiliary_agent_loaded?(name)
      tool_name = name.to_sym
      get_auxiliary_agent_tool_names.include?(tool_name)
    end

    # Get auxiliary agent tool names using shared discovery logic
    #
    # @return [Array<Symbol>] Array of auxiliary agent tool names
    def self.get_auxiliary_agent_tool_names
      LlmTeam::AuxiliaryAgentDiscovery.extract_tool_names(LlmTeam.configuration)
    rescue
      # If anything goes wrong, return empty array (following existing error handling pattern)
      []
    end
  end
end
