# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **DSL-style API**: `LlmTeam.ask("question")` method for simple programmatic usage
- **Structured Response Objects**: `LlmTeam::Response` class with comprehensive metadata:
  - `answer`: The final response from the LLM
  - `tokens_used`: Total tokens consumed across all agents
  - `latency_ms`: Total latency in milliseconds
  - `agent_info`: Detailed performance metrics per agent (primary + tool agents)
  - `conversation_context`: Full conversation history for debugging
  - `error`: Error information if any occurred
  - `to_hash`: Serialization method for complete data export
- **Auxiliary Agent Discovery API**: New methods for managing auxiliary agents:
  - `LlmTeam.list_auxiliary_agents`: Returns array of available agent tool names
  - `LlmTeam.auxiliary_agent_loaded?(name)`: Checks if specific agent is available
- **Enhanced Query Input Methods**: Support for multiple input formats:
  - Direct string queries: `llm_team "What is machine learning?"`
  - File path queries: `llm_team ./questions.txt`
  - Automatic detection of file vs. string input
- **Comprehensive Test Suite**: 79 tests covering all functionality:
  - API method testing with mocked dependencies
  - Configuration validation and error handling
  - Agent initialization and auxiliary agent loading
  - Performance tracking validation
  - Response object serialization and error handling
  - CLI functionality preservation
- **Code Quality Tools**: StandardRB configuration for consistent code style
- **Enhanced Development Workflow**: Rakefile with comprehensive tasks:
  - `test`: Run RSpec test suite
  - `test:coverage`: Run tests with coverage reporting
  - `standardrb`: Run code quality linting
  - `build_validate`: Build and validate gem installation
  - `install_local`/`uninstall_local`: Local gem testing
  - `clean`: Clean build artifacts

## [0.1.0] - 2024-01-01

### Added
- **Multi-agent LLM orchestration system** with specialized agents:
  - PrimaryAgent: Workflow orchestration and decision making
  - ResearchAgent: Information gathering and research
  - CriticAgent: Quality review and critique
  - PresenterAgent: Response synthesis and presentation
- **Auxiliary agent system** with dynamic loading and namespace-based organization
- **Dual conversation tracking** (ephemeral + persistent) with configurable history behavior
- **Configuration DSL** with environment variable support
- **CLI application** with interactive commands and batch processing
- **Performance tracking** and conversation management across all agents
- **Tool calling** with LLM-driven orchestration and retry logic
- **Extension system** for adding domain-specific capabilities to any core agent
- **OpenRouter integration** with configurable API endpoints
- **Comprehensive error handling** and graceful degradation