# frozen_string_literal: true

require "bundler/gem_tasks"

# Test tasks
desc "Run tests"
task :test do
  sh "bundle exec rspec"
end

desc "Run tests with coverage"
task "test:coverage" do
  sh "bundle exec rspec --format documentation"
end

# Lint tasks
desc "Run StandardRB linter"
task :standardrb do
  sh "bundle exec standardrb"
end

desc "Run all linting tools"
task lint: :standardrb

# Build tasks
desc "Build and validate gem"
task :build_validate do
  sh "bundle exec gem build llm_team.gemspec"
  sh "bundle exec gem install llm_team-*.gem --local"
  sh "bundle exec ruby -e \"require 'llm_team'; puts 'Gem loads successfully'\""
end

desc "Install gem locally for testing"
task :install_local do
  sh "bundle exec gem build llm_team.gemspec"
  sh "bundle exec gem install llm_team-*.gem --local"
end

desc "Uninstall local gem"
task :uninstall_local do
  sh "bundle exec gem uninstall llm_team -x"
end

desc "Clean build artifacts"
task :clean do
  sh "rm -f llm_team-*.gem"
  sh "rm -rf pkg/"
end

# Default task runs linting and tests
task default: %i[standardrb test]
