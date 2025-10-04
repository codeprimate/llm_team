# LLM Team

A multi-agent LLM orchestration system that uses specialized AI agents working together through research-critique-synthesis workflows to provide comprehensive, high-quality responses.

## Quick Start

### Prerequisites
- Ruby 3.1+
- OpenRouter API key

### Installation

**From GitHub (recommended):**
```ruby
# Gemfile
gem "llm_team", git: "https://github.com/codeprimate/llm_team.git"
```
```bash
bundle install
```

**From local clone:**
```ruby
# Gemfile
gem "llm_team", path: "/path/to/llm_team"
```

### Configuration
```bash
export OPENROUTER_API_KEY='your_api_key_here'
# Optional
export LLM_TEAM_MODEL='google/gemini-2.5-flash'
export LLM_TEAM_MAX_ITERATIONS='10'
export LLM_TEAM_VERBOSE='true'
```

## Web Search Capabilities

LLM Team includes powerful web search capabilities through integration with [SearXNG](https://github.com/codeprimate/searxng_docker), a privacy-respecting metasearch engine.

### SearXNG Docker Setup

**Required for web search functionality**: The LLM Team uses a locally hosted SearXNG Docker cluster to provide web search capabilities to its agents. This setup aggregates results from multiple search engines while maintaining privacy.

**Features:**
- **Privacy-First**: No user tracking or data collection
- **Multi-Engine**: Aggregates results from 70+ search services
- **MCP Integration**: Model Context Protocol server for AI integration
- **Local Control**: Self-hosted with complete data privacy
- **API Access**: REST API for programmatic searches

**Configuration**: Once running, configure LLM Team to use your SearXNG instance:
```bash
export LLM_TEAM_SEARXNG_URL='http://localhost:7778'
```

For setup instructions, see the [SearXNG Docker repository](https://github.com/codeprimate/searxng_docker).

## CLI Usage

### Basic Commands
```bash
# Interactive mode
llm_team --verbose

# Single query (string or file)
llm_team "What is machine learning?"
llm_team ./questions.txt
llm_team -q "Explain quantum computing"
```

### Options
```bash
llm_team [options] [query]

  -m, --model MODEL       Set LLM model (default: google/gemini-2.5-flash)
  --agents-path           Additional path for auxiliary agent definitions
  --verbose               Enable verbose output
  --quiet                 Enable quiet output (minimal output)
  -q, --query QUERY       Run in non-interactive mode with single query
  -h, --help              Show help message
```

### Interactive Commands
- `exit`, `quit`, `q` - Exit
- `help` - Show help  
- `clear` - Clear history
- `save` - Save last query and response to timestamped markdown file

## Ruby API

### Basic Usage
```ruby
require 'llm_team'

response = LlmTeam.ask("What is machine learning?")
puts response.answer
puts "Tokens: #{response.tokens_used}, Latency: #{response.latency_ms}ms"
```

### Configuration
```ruby
LlmTeam.configure do |config|
  config.api_key = "your-api-key"
  config.model = "gpt-4"
  config.max_iterations = 15
  config.verbose = true
  config.add_auxiliary_agents_path("./my_agents")
end
```

### Response Object
```ruby
response = LlmTeam.ask("What is AI?")

# Core data
response.answer          # => "AI is..."
response.tokens_used     # => 150
response.latency_ms      # => 2500
response.error          # => nil or error message

# Performance metrics
response.agent_info     # => { primary: {...}, research: {...}, critic: {...} }

# Full context
response.conversation_context  # => [{ role: "user", content: "..." }]
response.to_hash               # => Complete hash representation
```

### Auxiliary Agents
```ruby
# List available agents
LlmTeam.list_auxiliary_agents
# => [:web_research, :perform_math_operation]

# Check availability
LlmTeam.auxiliary_agent_loaded?(:web_research)
# => true
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

## Development

### Setup
```bash
git clone https://github.com/codeprimate/llm_team.git
cd llm_team
bundle install
```

### Commands
```bash
bundle exec rake test              # Run tests
bundle exec rake test:coverage     # Run tests with coverage
bundle exec rake standardrb        # Run linting
bundle exec rake lint              # Run all linting tools
bundle exec rake build_validate    # Build and validate gem
bundle exec rake install_local     # Install gem locally
bundle exec rake uninstall_local   # Uninstall local gem
bundle exec rake clean             # Clean build artifacts
bundle exec rake                   # Default task (linting + tests)
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `Error: API key is required` | Set `OPENROUTER_API_KEY` environment variable |
| `Could not find gem 'llm_team'` | Run `bundle update` and ensure Ruby 3.1+ |
| `Error: Invalid configuration` | Check environment variables: `echo $OPENROUTER_API_KEY` |

## Resources

- [GitHub Issues](https://github.com/codeprimate/llm_team/issues)
- [Repository](https://github.com/codeprimate/llm_team)
- [Changelog](CHANGELOG.md)