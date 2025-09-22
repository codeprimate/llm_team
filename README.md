# LLM Team

A multi-agent LLM orchestration system that uses specialized AI agents working together through research-critique-synthesis workflows to provide comprehensive, high-quality responses.

## Installation

### Prerequisites

- Ruby 3.1+
- OpenRouter API key

### Setup

```bash
# Clone and install
git clone <repository-url>
cd llm_team
bundle install

# Set your API key
export OPENROUTER_API_KEY='your_api_key_here'
```

## Usage

### Interactive Mode
```bash
llm_team
```

### Single Query Mode
```bash
llm_team "What is machine learning?"
```

### Options
```bash
llm_team [options] [query]

  -m, --model MODEL       Set LLM model (default: google/gemini-2.5-pro)
  --agent-path            Path to auxillary agent definitions
  --verbose               Enable verbose output
  -h, --help              Show help message
```

### Interactive Commands
- `exit`, `quit`, `q` - Exit
- `help` - Show help  
- `clear` - Clear history
- `save` - Save last query and response to timestamped markdown file

## Extension System

LLM Team uses a namespace-based auxiliary agent system that automatically loads custom tools for any core agent.

### How It Works

**Automatic Discovery**: Each agent automatically scans `lib/llm_team/agents/auxiliary/` for agent files matching its namespace.

**Namespace Mapping**: File paths are converted to Ruby class namespaces:
```
auxiliary/
├── primary_agent/
│   ├── web_search_agent.rb     → LlmTeam::Agents::Auxiliary::PrimaryAgent::WebSearchAgent
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
# lib/llm_team/agents/auxiliary/primary_agent/web_search_agent.rb
module LlmTeam::Agents::Auxiliary::PrimaryAgent
  class WebSearchAgent < LlmTeam::Core::Agent
    def initialize
      super("WebSearchAgent")
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