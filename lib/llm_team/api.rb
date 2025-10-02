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
  end
end
