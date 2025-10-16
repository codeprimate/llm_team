# frozen_string_literal: true

require "bundler/setup"
require "llm_team"
require_relative "../lib/llm_team/response"
require_relative "../lib/llm_team/api"
require_relative "../lib/llm_team/clients/openrouter_client"
require_relative "../lib/llm_team/clients/openai_client"
require_relative "../lib/llm_team/clients/ollama_client"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Configure output formatting
  config.color = true
  config.tty = true
  config.formatter = :documentation

  # Configure test isolation
  config.before(:each) do
    # Reset configuration to defaults before each test
    LlmTeam.configuration.reset! if defined?(LlmTeam.configuration)

    # Mock OpenAI client to avoid real API calls
    mock_openai_client
  end

  config.after(:each) do
    # Clean up any test-specific state
    # Configuration is already reset in before hook
  end

  # Helper method to mock OpenAI client
  def mock_openai_client
    # Create a mock client that returns consistent test responses
    mock_client = double("OpenAI::Client")

    # Mock the chat method that's used in Agent#call_llm
    allow(mock_client).to receive(:chat).with(parameters: anything).and_return(
      {
        "choices" => [
          {
            "message" => {
              "content" => "Mock response from OpenAI API",
              "role" => "assistant"
            }
          }
        ],
        "usage" => {
          "total_tokens" => 100,
          "prompt_tokens" => 50,
          "completion_tokens" => 50
        }
      }
    )

    # Mock the OpenAI::Client constructor
    allow(OpenAI::Client).to receive(:new).and_return(mock_client)
  end

  # Helper method to create test configuration
  def test_configuration
    config = LlmTeam::Configuration.new
    config.api_key = "test-api-key"
    config.model = "test-model"
    config.verbose = false
    config.quiet = true
    config
  end

  # Helper method to create mock API response with tool calls
  def mock_tool_call_response(tool_name, arguments = {})
    {
      "choices" => [
        {
          "message" => {
            "content" => nil,
            "role" => "assistant",
            "tool_calls" => [
              {
                "id" => "test-tool-call-id",
                "type" => "function",
                "function" => {
                  "name" => tool_name,
                  "arguments" => arguments.to_json
                }
              }
            ]
          }
        }
      ],
      "usage" => {
        "total_tokens" => 150,
        "prompt_tokens" => 75,
        "completion_tokens" => 75
      }
    }
  end

  # Helper method to create mock tool response
  def mock_tool_response(content)
    {
      "choices" => [
        {
          "message" => {
            "content" => content,
            "role" => "assistant"
          }
        }
      ],
      "usage" => {
        "total_tokens" => 200,
        "prompt_tokens" => 100,
        "completion_tokens" => 100
      }
    }
  end
end
