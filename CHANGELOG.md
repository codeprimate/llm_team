# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **New DSL-style API**: `LlmTeam.ask("question")` method for simple programmatic usage
- **Structured Response Object**: `LlmTeam::Response` class with comprehensive metadata including:
  - `answer`: The final response from the LLM
  - `tokens_used`: Total tokens consumed across all agents
  - `latency_ms`: Total latency in milliseconds
  - `agent_info`: Detailed performance metrics per agent
  - `conversation_context`: Full conversation history for debugging
  - `error`: Error information if any occurred
- **Auxiliary Agent Discovery**: New methods for discovering available auxiliary agents:
  - `LlmTeam.list_auxiliary_agents`: Returns array of available agent tool names
  - `LlmTeam.auxiliary_agent_loaded?(name)`: Checks if specific agent is available
- **Comprehensive Test Suite**: 79 tests covering all functionality including:
  - API method testing with mocked dependencies
  - Configuration validation and error handling
  - Agent initialization and auxiliary agent loading
  - Performance tracking validation
  - CLI functionality preservation
- **Code Quality Tools**: StandardRB configuration for consistent code style
- **Enhanced Rakefile**: Development workflow tasks including:
  - `test`: Run RSpec test suite
  - `standardrb`: Run code quality linting
  - `build_validate`: Build and validate gem installation
  - `install_local`/`uninstall_local`: Local gem testing
  - `clean`: Clean build artifacts

### Changed
- **Module Structure**: Removed direct execution from `lib/llm_team.rb` to support proper gem usage
- **API Integration**: New API methods integrate seamlessly with existing configuration system
- **Performance Tracking**: Enhanced performance data aggregation with detailed agent metrics
- **Error Handling**: Improved error reporting through structured response objects

### Technical Details
- **Configuration Preservation**: All existing configuration DSL and environment variable support maintained
- **CLI Compatibility**: All existing CLI functionality preserved and working
- **Agent Architecture**: No changes to core agent functionality or initialization
- **Dependency Management**: Maintains compatibility with existing dependencies (ruby-openai, colorize, symbolic)

### Migration Notes
- **Breaking Change**: Direct execution via `ruby lib/llm_team.rb` no longer works (use `bin/llm_team` instead)
- **New Usage Pattern**: Use `LlmTeam.ask("question")` for programmatic access instead of direct agent instantiation
- **Configuration**: Existing configuration patterns continue to work unchanged
- **CLI Usage**: All existing CLI commands and options continue to work unchanged

## [0.1.0] - Initial Release

### Added
- Multi-agent LLM orchestration system
- Core agents: Primary, Research, Critic, Presenter
- Auxiliary agent system with dynamic loading
- Configuration DSL with environment variable support
- CLI application with interactive commands
- Performance tracking and conversation management
- Tool calling and workflow coordination
