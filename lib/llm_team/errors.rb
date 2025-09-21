# frozen_string_literal: true

module LlmTeam
  # Base error class for all LLM Team errors
  class Error < StandardError; end

  # API-related errors
  class APIError < Error; end
  class AuthenticationError < APIError; end
  class RateLimitError < APIError; end
  class ModelNotFoundError < APIError; end

  # Configuration errors
  class ConfigurationError < Error; end
  class MissingAPIKeyError < ConfigurationError; end

  # Agent and tool errors
  class AgentError < Error; end
  class ToolNotFoundError < AgentError; end
  class ToolExecutionError < AgentError; end
  class MaxIterationsError < AgentError; end

  # Conversation and workflow errors
  class ConversationError < Error; end
  class InvalidHistoryBehaviorError < ConversationError; end
  class WorkflowError < Error; end

  # Extension errors
  class ExtensionError < Error; end
  class AgentRegistrationError < ExtensionError; end
end
