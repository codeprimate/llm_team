# LLM Team

A multi-agent LLM orchestration system that uses specialized AI agents working together through research-critique-synthesis workflows to provide comprehensive, high-quality responses.

## Installation

### Prerequisites

- Ruby 3.1+
- OpenRouter API key

### Option 1: Install from GitHub (Recommended)

Add to your Gemfile:

```ruby
gem "llm_team", git: "https://github.com/codeprimate/llm_team.git"
```

Then install:

```bash
bundle install
```

### Option 2: Install from Local Clone

If you've cloned the repository locally:

```bash
# Clone the repository
git clone https://github.com/codeprimate/llm_team.git
cd llm_team

# Install dependencies
bundle install

# Build and install the gem locally
bundle exec rake install_local
```

Or add to your Gemfile using the local path:

```ruby
gem "llm_team", path: "/path/to/llm_team"
```

Then run:

```bash
bundle install
```

### Development Setup

For development work on the gem itself:

```bash
# Clone and setup for development
git clone https://github.com/codeprimate/llm_team.git
cd llm_team
bundle install

# Run tests to verify installation
bundle exec rake test

# Build and validate the gem
bundle exec rake build_validate
```

### Environment Setup

Set your API key:

```bash
export OPENROUTER_API_KEY='your_api_key_here'
```

Optional configuration:

```bash
export LLM_TEAM_MODEL='google/gemini-2.5-flash'  # Default model
export LLM_TEAM_MAX_ITERATIONS='10'              # Max iterations
export LLM_TEAM_VERBOSE='true'                   # Verbose output
```

## Usage

### Interactive Mode
```bash
llm_team --verbose
```

### Single Query Mode
```bash
# Direct query string
llm_team "What is machine learning?"

# Query from file
llm_team ./my_questions.txt
llm_team -q ./questions.md
```

### Options
```bash
llm_team [options] [query]

  -m, --model MODEL       Set LLM model (default: google/gemini-2.5-flash)
  --agents-path           Additional path for auxiliary agent definitions
  --searxng-mcp URL       Set SearXNG MCP server URL
  --verbose               Enable verbose output
  --quiet                 Enable quiet output (minimal output)
  -q, --query QUERY       Run in non-interactive mode with single query (supports file paths)
  -h, --help              Show help message
```

### Query Input Methods

LLM Team supports multiple ways to provide your query:

1. **Direct String**: Pass the query directly as a string
   ```bash
   llm_team "What is machine learning?"
   llm_team -q "Explain quantum computing"
   ```

2. **File Path**: Provide a file path to read the query from
   ```bash
   llm_team ./my_questions.txt
   llm_team -q ./questions.md
   ```

The system automatically detects if the input is a file path by checking for:
- Path separators (`/` or `\`)
- File extensions (e.g., `.txt`, `.md`, `.py`)

If the file exists and is readable, its content will be used as the query. If not, the string will be treated as a direct query.

### Interactive Commands
- `exit`, `quit`, `q` - Exit
- `help` - Show help  
- `clear` - Clear history
- `save` - Save last query and response to timestamped markdown file

## Programmatic API

### Basic Usage

```ruby
require 'llm_team'

# Simple question
response = LlmTeam.ask("What is machine learning?")
puts response.answer
puts "Tokens used: #{response.tokens_used}"
puts "Latency: #{response.latency_ms}ms"
```

### Configuration

```ruby
# Configure the system
LlmTeam.configure do |config|
  config.api_key = "your-api-key"  # Overrides OPENROUTER_API_KEY
  config.model = "gpt-4"           # Overrides LLM_TEAM_MODEL
  config.max_iterations = 15       # Overrides LLM_TEAM_MAX_ITERATIONS
  config.verbose = true            # Overrides LLM_TEAM_VERBOSE
  config.add_auxiliary_agents_path("./my_agents")
end

# Ask questions with custom configuration
response = LlmTeam.ask("Explain quantum computing")
```

### Response Object

The `LlmTeam.ask()` method returns a structured response object:

```ruby
response = LlmTeam.ask("What is AI?")

# Core response data
response.answer          # => "AI is..."
response.tokens_used     # => 150
response.latency_ms      # => 2500
response.error          # => nil (or error message if failed)

# Detailed performance metrics
response.agent_info     # => {
#   primary: { tokens: 100, latency_ms: 2000, calls: 1 },
#   research: { tokens: 30, latency_ms: 300, calls: 1 },
#   critic: { tokens: 20, latency_ms: 200, calls: 1 },
#   summary: { total_agents: 3, total_tokens: 150, total_latency_ms: 2500 }
# }

# Full conversation context
response.conversation_context  # => [
#   { role: "user", content: "What is AI?" },
#   { role: "assistant", content: "AI is..." }
# ]

# Serialization
response.to_hash  # => Complete hash representation
```

### Auxiliary Agent Discovery

```ruby
# List available auxiliary agents
agents = LlmTeam.list_auxiliary_agents
# => [:web_research, :perform_math_operation]

# Check if specific agent is available
LlmTeam.auxiliary_agent_loaded?(:web_research)
# => true

LlmTeam.auxiliary_agent_loaded?(:nonexistent_agent)
# => false
```

### Error Handling

```ruby
response = LlmTeam.ask("Test question")

if response.error
  puts "Error: #{response.error}"
else
  puts "Success: #{response.answer}"
end
```

## Extension System

LLM Team uses a namespace-based auxiliary agent system that automatically loads custom tools for any core agent.

### How It Works

**Automatic Discovery**: Each agent automatically scans `lib/llm_team/agents/auxiliary/` for agent files matching its namespace.

**Namespace Mapping**: File paths are converted to Ruby class namespaces:
```
auxiliary/
├── primary_agent/
│   ├── searxng_mcp_agent.rb     → LlmTeam::Agents::Auxiliary::ResearchAgent::SearxngMcpAgent
│   └── calculator_agent.rb     → LlmTeam::Agents::Auxiliary::PrimaryAgent::CalculatorAgent
└── research_agent/
    └── database_agent.rb       → LlmTeam::Agents::Auxiliary::ResearchAgent::DatabaseAgent
```

**Agent Isolation**: Each core agent only loads auxiliary agents in its own namespace. PrimaryAgent ignores ResearchAgent's auxiliary agents and vice versa.

### Creating Auxiliary Agents

1. **Create the file** in the appropriate namespace directory:
```bash
mkdir -p lib/llm_team/agents/auxiliary/primary_agent
touch lib/llm_team/agents/auxiliary/primary_agent/web_search_agent.rb
```

2. **Implement the agent** following this pattern:
```ruby
# lib/llm_team/agents/auxiliary/research_agent/searxng_mcp_agent.rb
module LlmTeam::Agents::Auxiliary::ResearchAgent
  class SearxngMcpAgent < LlmTeam::Core::Agent
    def initialize
      super("SearxngMcpAgent")
    end

    def search_web(query:)
      # Your implementation here
      "Search results for: #{query}"
    end

    def self.tool_schema
      {
        type: :function,
        function: {
          name: "search_web",
          description: "Search the web for information",
          parameters: {
            type: :object,
            properties: {
              query: {
                type: :string,
                description: "Search query"
              }
            },
            required: ["query"]
          }
        }
      }
    end
  end
end
```

3. **Tool Registration**: The agent automatically registers and becomes available as `search_web` function call.

### Extension Theory

**Tool Discovery**: Uses Ruby's `constantize` to dynamically load classes based on file paths, not reflection.

**Function Calling**: Tools are exposed to the LLM via OpenAI function calling schema, creating a clean interface between agents.

**Namespace Isolation**: Prevents tool conflicts and ensures each agent gets only relevant tools.

**Validation**: Auxiliary agents must inherit from `Core::Agent` and define a `tool_schema` class method.

**Error Handling**: Invalid agents are skipped with warnings, so the system gracefully continues with available tools.

This design allows extending any core agent with domain-specific capabilities without modifying the core system.

## Troubleshooting

### Common Issues

#### Missing API Key
```
Error: API key is required
```
**Solution**: Set your OpenRouter API key:
```bash
export OPENROUTER_API_KEY='your_api_key_here'
```

#### GitHub Installation Issues
```
fatal: could not read Username for 'https://github.com'
```
**Solution**: Ensure the repository is public and accessible, or use SSH:
```ruby
gem "llm_team", git: "git@github.com:codeprimate/llm_team.git"
```

#### Dependency Resolution Issues
```
Could not find gem 'llm_team'
```
**Solution**: Update your bundle and ensure Ruby 3.1+:
```bash
bundle update
ruby --version  # Should be 3.1.0 or higher
```

#### Configuration Errors
```
Error: Invalid configuration
```
**Solution**: Check your environment variables and configuration:
```bash
echo $OPENROUTER_API_KEY
echo $LLM_TEAM_MODEL
```

### Development Workflow

```bash
# Run tests
bundle exec rake test

# Run tests with coverage
bundle exec rake test:coverage

# Run linting
bundle exec rake standardrb

# Run all linting tools
bundle exec rake lint

# Build and validate gem
bundle exec rake build_validate

# Install gem locally for testing
bundle exec rake install_local

# Uninstall local gem
bundle exec rake uninstall_local

# Clean build artifacts
bundle exec rake clean

# Run default task (linting + tests)
bundle exec rake
```

### Getting Help

- **Issues**: [GitHub Issues](https://github.com/codeprimate/llm_team/issues)
- **Documentation**: [GitHub Repository](https://github.com/codeprimate/llm_team)
- **Changelog**: [CHANGELOG.md](https://github.com/codeprimate/llm_team/blob/main/CHANGELOG.md)