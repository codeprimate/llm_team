# frozen_string_literal: true

require "net/http"
require "json"
require_relative "../../../core/agent"

module LlmTeam
  module Agents
    module Auxiliary
      module ResearchAgent
        # SearXNG MCP auxiliary agent providing web research capabilities
        #
        # Supports:
        # - Web search using SearXNG metasearch engine via MCP
        # - URL content fetching with HTML stripping
        # - Multi-page crawling with filtering
        #
        # Output format: "Research: [operation] Result: [content]"
        class SearxngMcpAgent < LlmTeam::Core::Agent
          # Error raised when MCP server communication fails
          class MCPFailureError < StandardError; end
          SYSTEM_PROMPT = <<~PROMPT
            You are a web research assistant specializing in real-time information gathering.
            
            You handle:
            - Web search: Find current information using metasearch engines
            - Content fetching: Extract clean text from specific URLs
            - Page crawling: Gather content from pages and related subpages
            
            Always provide concise responses in the format:
            Research: [operation description]
            Result: [research findings]
            Sources: [list of URLs and source information for citation]
            
            Focus on factual, current information for academic and research purposes.
            Always include source URLs and publication information for proper citation.
          PROMPT

          TOOL_PROMPT = <<~PROMPT
            - [WEB SEARCH TOOL] `web_research(operation:, query:, url:, categories:, engines:, language:, headers:, filters:, subpage_limit:)`: Perform web research operations using MCP tools.
              This tool provides real-time web research capabilities.
              IMPORTANT: If this tool returns error messages indicating web research is unavailable, DO NOT use it and ignore its output completely.
              Example web_research() function calls:
                * Web search: web_research(operation: "search", query: "artificial intelligence trends 2024")
                * Fetch content: web_research(operation: "fetch", url: "https://example.com/article")
                * Crawl pages: web_research(operation: "crawl", url: "https://example.com", subpage_limit: 3)
                * Search with filters: web_research(operation: "search", query: "machine learning", categories: "science", language: "en")
                * Crawl with filters: web_research(operation: "crawl", url: "https://docs.example.com", filters: ["api", "reference"])
          PROMPT

          def initialize(history_behavior: :none, model: nil)
            super("SearxngMcpAgent", history_behavior: history_behavior, model: model)
          end

          # Main web search operation dispatcher
          def web_research(operation:, query: nil, url: nil, categories: nil, engines: nil, language: "en", headers: nil, filters: nil, subpage_limit: 5)
            case operation.to_s
            when "search"
              perform_search(query, categories, engines, language)
            when "fetch"
              perform_fetch(url, headers)
            when "crawl"
              perform_crawl(url, filters, headers, subpage_limit)
            else
              "Error: Unknown operation '#{operation}'. Supported: search, fetch, crawl"
            end
          rescue => e
            "Error: #{e.message}"
          end

          # Tool schema definition for LLM function calling
          def self.tool_schema
            return {} unless service_healthy?

            {
              type: :function,
              function: {
                name: "web_research",
                description: "Perform web research operations using MCP tools for real-time information gathering.",
                parameters: {
                  type: :object,
                  properties: {
                    operation: {
                      type: :string,
                      description: "Type of research operation to perform. search: perform a web search, fetch: fetch the content of a specific URL to gather further information, crawl: crawl a specific URL for deep research",
                      enum: ["search", "fetch", "crawl"]
                    },
                    query: {
                      type: :string,
                      description: "Search query (required for search operation)"
                    },
                    url: {
                      type: :string,
                      description: "URL to fetch or crawl (required for fetch/crawl operations)"
                    },
                    categories: {
                      type: :string,
                      description: "Comma-separated categories (optional)"
                    },
                    engines: {
                      type: :string,
                      description: "Comma-separated engines (optional)"
                    },
                    language: {
                      type: :string,
                      description: "Language code (default: en)"
                    },
                    headers: {
                      type: :object,
                      description: "Optional custom headers as key-value pairs",
                      additionalProperties: {type: :string}
                    },
                    filters: {
                      type: :array,
                      items: {type: :string},
                      description: "Array of strings to filter anchor text (at least one must match)"
                    },
                    subpage_limit: {
                      type: :integer,
                      description: "Maximum number of subpages to crawl (default: 5)",
                      default: 5
                    }
                  },
                  required: ["operation"]
                }
              }
            }
          end

          # Check if the MCP service is healthy
          def self.service_healthy?
            require "net/http"
            require "json"

            mcp_url = LlmTeam.configuration.searxng_url
            uri = URI("#{mcp_url}/health")
            http = Net::HTTP.new(uri.host, uri.port)
            http.read_timeout = 2
            http.open_timeout = 2

            request = Net::HTTP::Get.new(uri)
            response = http.request(request)

            if response.code == "200"
              result = JSON.parse(response.body)
              result["status"] == "healthy"
            else
              false
            end
          rescue
            # Silently handle health check failures to avoid dependency issues
            false
          end

          private

          # Perform web search
          def perform_search(query, categories, engines, language)
            return "Error: query required for search operation" unless query

            parameters = {query: query, language: language}
            parameters[:categories] = categories if categories
            parameters[:engines] = engines if engines

            begin
              result = call_mcp_tool("search", parameters)
              sources = extract_sources_from_search_result(result)
              "Research: Web search for '#{query}'\nResult: #{result}\nSources: #{sources}"
            rescue MCPFailureError
              "TOOL_UNAVAILABLE: Web search service is down. Ignore this tool's output and do not use it."
            end
          end

          # Perform content fetching
          def perform_fetch(url, headers)
            return "Error: url required for fetch operation" unless url

            parameters = {url: url}
            parameters[:headers] = headers if headers

            begin
              result = call_mcp_tool("fetch", parameters)
              "Research: Fetch content from #{url}\nResult: #{result}\nSources: [Web] Content from #{url}"
            rescue MCPFailureError
              "TOOL_UNAVAILABLE: Web content fetching service is down. Ignore this tool's output and do not use it."
            end
          end

          # Perform page crawling
          def perform_crawl(url, filters, headers, subpage_limit)
            return "Error: url required for crawl operation" unless url

            parameters = {url: url, subpage_limit: subpage_limit}
            parameters[:filters] = filters if filters
            parameters[:headers] = headers if headers

            begin
              result = call_mcp_tool("crawl", parameters)
              sources = extract_sources_from_crawl_result(result, url)
              "Research: Crawl #{url} (limit: #{subpage_limit})\nResult: #{result}\nSources: #{sources}"
            rescue MCPFailureError
              "TOOL_UNAVAILABLE: Web crawling service is down. Ignore this tool's output and do not use it."
            end
          end

          # Extract source information from search results
          def extract_sources_from_search_result(result)
            return "No sources available" unless result.is_a?(Hash) && result["results"]

            sources = result["results"].map do |item|
              title = item["title"] || "Untitled"
              url = item["url"] || ""
              "[Web] \"#{title}\" - #{url}"
            end

            sources.empty? ? "No sources available" : sources.join("; ")
          end

          # Extract source information from crawl results
          def extract_sources_from_crawl_result(result, base_url)
            sources = ["[Web] Crawled content from #{base_url}"]

            if result.is_a?(Hash) && result["subpages"]
              result["subpages"].each do |subpage|
                url = subpage["url"] || ""
                title = subpage["title"] || "Subpage"
                sources << "[Web] \"#{title}\" - #{url}"
              end
            end

            sources.join("; ")
          end

          # HTTP client for MCP server communication
          def call_mcp_tool(tool_name, parameters)
            mcp_url = LlmTeam.configuration.searxng_url
            uri = URI("#{mcp_url}/#{tool_name}")
            http = Net::HTTP.new(uri.host, uri.port)

            request = Net::HTTP::Post.new(uri)
            request["Content-Type"] = "application/json"
            request.body = parameters.to_json

            LlmTeam::Output.puts("Calling MCP server for #{tool_name}", type: :technical)
            LlmTeam::Output.puts("Parameters: #{parameters.inspect}", type: :debug)

            response = http.request(request)

            LlmTeam::Output.puts("MCP Response: #{response.code} - #{response.body[0..200]}...", type: :debug)

            if response.code == "200"
              result = JSON.parse(response.body)
              LlmTeam::Output.puts("MCP Result: #{result.inspect[0..200]}...", type: :debug)
              result
            else
              LlmTeam::Output.puts("MCP server returned #{response.code} - #{response.body}", type: :error)
              raise MCPFailureError, "MCP server returned #{response.code}"
            end
          rescue => e
            LlmTeam::Output.puts("Failed to connect to MCP server - #{e.message}", type: :error)
            raise MCPFailureError, "MCP connection failed: #{e.message}"
          end
        end
      end
    end
  end
end
