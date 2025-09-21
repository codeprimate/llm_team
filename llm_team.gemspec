# frozen_string_literal: true

require_relative "lib/llm_team/version"

Gem::Specification.new do |spec|
  spec.name = "llm_team"
  spec.version = LlmTeam::VERSION
  spec.authors = ["Patrick Morgan"]
  spec.email = ["patrick@patrick-morgan.net"]

  spec.summary = "Multi-agent LLM orchestration system with tool calling and conversation management"
  spec.description = "A Ruby gem for orchestrating multiple LLM agents with sophisticated conversation management, tool calling, and workflow coordination. Features research, critique, and synthesis agents with LLM-driven orchestration."
  spec.homepage = "https://github.com/codeprimate/llm_team"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/codeprimate/llm_team"
  spec.metadata["changelog_uri"] = "https://github.com/codeprimate/llm_team/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "bin"
  spec.executables = spec.files.grep(%r{\Abin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "ruby-openai", "~> 7.0"
  spec.add_dependency "colorize", "~> 1.1"
  spec.add_dependency "symbolic", "~> 0.3"
  
  # Development dependencies
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rake", "~> 13.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
