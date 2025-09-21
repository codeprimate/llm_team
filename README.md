# LLM Team

A multi-agent LLM orchestration system that uses specialized AI agents working together to provide comprehensive, high-quality responses through research, critique, and synthesis workflows.

## Features

- **Multi-Agent Architecture**: Specialized agents for research, critique, and presentation
- **LLM-Driven Orchestration**: Intelligent workflow management through system prompts
- **Dual Conversation Tracking**: Sophisticated ephemeral vs persistent history management
- **Tool Calling System**: Clean tool registration and execution with retry logic
- **Performance Tracking**: Comprehensive token usage and latency monitoring
- **Interactive CLI**: User-friendly command interface with both interactive and single-query modes
- **Extensible Design**: Clean separation between core and auxiliary agents

## Architecture

### Core Components

- **Core::Agent**: Base orchestration capability with conversation management
- **Core::Conversation**: Message handling with history behavior modes
- **Core Agents**: Essential agents for basic functionality
  - `ResearchAgent`: Information gathering with contextual research modes
  - `CriticAgent`: Quality assessment with structured feedback
  - `PresenterAgent`: Final synthesis and response formatting
  - `Orchestrator`: LLM-driven workflow coordination

### Agent Workflow

The system follows a structured research-critique-synthesis workflow:

1. **Research**: Gather initial information on the topic
2. **Synthesis**: Create a comprehensive response
3. **Critique**: Review the response for quality and completeness
4. **Iteration**: If needed, conduct additional research and improve the response
5. **Final Presentation**: Deliver the polished final answer

## Installation

### Prerequisites

- Ruby 3.0 or higher
- OpenRouter API key

### Setup

1. Clone the repository:
```bash
git clone <repository-url>
cd llm_team
```

2. Install dependencies:
```bash
bundle install
```

3. Set your API key:
```bash
export OPENROUTER_API_KEY='your_api_key_here'
```

## Usage

### Interactive Mode

Start the interactive CLI:
```bash
llm_team
```

This launches an interactive session where you can ask questions and have conversations with the LLM team.

### Single Query Mode

Run a single query without entering interactive mode:
```bash
llm_team "What is machine learning?"
```

### Command Line Options

```bash
llm_team [options] [query]

Options:
  -h, --help              Show help message
  -v, --version           Show version information
  -i, --max-iterations N  Set maximum iterations (default: 20)
  -m, --model MODEL       Set LLM model (default: deepseek/deepseek-chat-v3.1)
  -H, --history BEHAVIOR  Set history behavior: none, last, full (default: last)
  --verbose               Enable verbose output
  -q, --query QUERY       Run in non-interactive mode with single query

Examples:
  llm_team                                    # Interactive mode
  llm_team "What is machine learning?"        # Single query mode
  llm_team -q "Explain quantum computing"     # Single query mode
  llm_team -i 10 -H full                     # Custom iterations and history
  llm_team --model "gpt-4" --verbose         # Custom model with verbose output
```

### Interactive Commands

When in interactive mode, you can use these commands:
- `exit`, `quit`, or `q` - Exit the application
- `help` - Show help message
- `clear` - Clear screen and conversation history

## Configuration

### Environment Variables

- `OPENROUTER_API_KEY`: Your OpenRouter API key (required)

### History Behavior Modes

- `none`: No conversation history - fresh start each time
- `last`: Preserve only the last user-assistant pair for minimal context
- `full`: Preserve entire conversation including tool interactions

## Development

### Project Structure

```
llm_team/
├── lib/
│   ├── llm_team.rb                    # Main entry point
│   ├── llm_team/
│   │   ├── version.rb                 # Version management
│   │   ├── configuration.rb           # Configuration system
│   │   ├── errors.rb                  # Custom error classes
│   │   │
│   │   ├── core/                      # Core domain models
│   │   │   ├── agent.rb               # Base Agent class
│   │   │   └── conversation.rb        # Conversation management
│   │   │
│   │   ├── agents/                    # Agent implementations
│   │   │   └── core/                  # Essential agents
│   │   │       ├── research_agent.rb
│   │   │       ├── critic_agent.rb
│   │   │       ├── presenter_agent.rb
│   │   │       └── orchestrator.rb
│   │   │
│   │   └── cli/                       # CLI interface
│   │       └── application.rb
│   │
├── bin/
│   └── llm_team                      # Executable
├── Gemfile
├── llm_team.gemspec
└── README.md
```

### Running Tests

```bash
# Run syntax checks
ruby -c lib/llm_team.rb

# Run individual component checks
ruby -c lib/llm_team/core/agent.rb
ruby -c lib/llm_team/core/conversation.rb
```

### Code Quality

The project follows Ruby best practices and uses:
- Consistent naming conventions
- Comprehensive error handling
- Clear separation of concerns
- Extensive documentation

## Key Design Principles

1. **LLM-Driven Orchestration**: The system uses LLM decision-making through system prompts rather than complex state machines
2. **Tool-Based Coordination**: Agents communicate through tool calling, not direct method calls
3. **Dual History Tracking**: Sophisticated ephemeral vs persistent conversation management
4. **Performance Monitoring**: Comprehensive tracking of tokens, latency, and API calls
5. **Graceful Error Handling**: Robust retry logic and error recovery

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

[Add your license information here]

## Changelog

### Recent Changes

- Removed backward compatibility aliases for cleaner API
- Reorganized agents into core/auxiliary structure
- Extracted conversation management into separate Core::Conversation class
- Enhanced CLI with proper argument parsing and configuration options
- Added support for both interactive and single-query modes
- Improved error handling and user experience