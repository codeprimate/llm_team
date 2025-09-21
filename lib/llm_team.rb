# frozen_string_literal: true

# LLM Team Primary Agent - Multi-agent system with tool calling and conversation management

require_relative "llm_team/version"
require_relative "llm_team/errors"
require_relative "llm_team/configuration"
require_relative "llm_team/output"

# Core dependencies
require "ruby/openai"
require "json"
require "colorize"

# Core classes
require_relative "llm_team/core/conversation"
require_relative "llm_team/core/agent"

# Core agent classes
require_relative "llm_team/agents/core/research_agent"
require_relative "llm_team/agents/core/critic_agent"
require_relative "llm_team/agents/core/presenter_agent"
require_relative "llm_team/agents/core/primary_agent"

# CLI
require_relative "llm_team/cli/application"

module LlmTeam
  # Configuration access
  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end

  # Conversation role constants for consistent message handling
  ROLE_SYSTEM = :system
  ROLE_USER = :user
  ROLE_ASSISTANT = :assistant
  ROLE_TOOL = :tool

end

# LLM Team Primary Agent - Setup and Usage
#
# Prerequisites:
# 1. Install dependencies: `bundle install` (requires ruby-openai gem)
# 2. Set API key: `export OPENROUTER_API_KEY='your_api_key_here'`
# 3. Run: `ruby llm_team.rb`
#
# Key Features:
# - Multi-agent coordination with research, critique, and synthesis workflow
# - Conversation history management with configurable persistence modes
# - Performance tracking (tokens, latency) across all agents
# - Interactive CLI with command handling and error recovery
# - Tool calling with retry logic and graceful error handling
#
# Architecture:
# - Agent base class with dual conversation tracking (ephemeral + persistent)
# - Specialized agents: ResearchAgent, CriticAgent, PresenterAgent
# - PrimaryAgent implementing structured decision tree workflow
# - Interactive CLI application with cross-platform command handling
#
# Usage Examples:
# - Interactive mode: `ruby llm_team.rb`
# - IRB integration: `irb -r ./llm_team.rb`
# - Direct execution: `LlmTeam::CLI::Application.new.run`

# Direct execution entry point
if __FILE__ == $0
  # When run directly, process command line arguments
  LlmTeam::CLI::Application.new.run
end