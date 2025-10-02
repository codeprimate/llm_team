# frozen_string_literal: true

module LlmTeam
  # Shared logic for discovering and loading auxiliary agents
  # Used by both Agent class and API discovery methods
  module AuxiliaryAgentDiscovery
    # Discover auxiliary agent files in configured paths
    #
    # @param config [LlmTeam::Configuration] Configuration object
    # @return [Array<String>] Array of auxiliary agent file paths
    def self.discover_auxiliary_agent_files(config)
      return [] unless config.auxiliary_agents_paths&.any?

      files = []
      config.auxiliary_agents_paths.each do |path|
        auxiliary_agents_path = File.expand_path(path)
        next unless Dir.exist?(auxiliary_agents_path)

        files.concat(discover_files_in_path(auxiliary_agents_path))
      end

      files
    end

    # Discover auxiliary agent files in a specific path
    #
    # @param path [String] The path to scan
    # @return [Array<String>] Array of auxiliary agent file paths
    def self.discover_files_in_path(path)
      Dir.glob(File.join(path, "**", "*_agent.rb"))
    end

    # Extract auxiliary agent information from a file
    #
    # @param file [String] The auxiliary agent file path
    # @param base_path [String] The base path for relative path calculation
    # @return [Hash, nil] Agent information hash or nil if invalid
    def self.extract_agent_info_from_file(file, base_path)
      auxiliary_agents_path = File.expand_path(base_path)

      # Get the relative path from the auxiliary agents directory
      relative_path = file.sub(auxiliary_agents_path + "/", "").gsub(/\.rb$/, "")

      # Build namespace from directory structure and filename
      namespace_parts = relative_path.split("/").map do |part|
        part.split("_").map(&:capitalize).join
      end

      # Build full class name
      full_class_name = "LlmTeam::Agents::Auxiliary::#{namespace_parts.join("::")}"

      # Check if this auxiliary agent belongs to any agent's namespace
      unless full_class_name.start_with?("LlmTeam::Agents::Auxiliary::") &&
          full_class_name.split("::").length >= 5
        return nil
      end

      # Check if the expected class exists and extract information
      begin
        require file
        agent_class = Object.const_get(full_class_name)

        # Validate that the loaded class is a proper auxiliary agent
        return nil unless validate_auxiliary_agent_class(agent_class)

        # Extract tool name from schema
        tool_name = agent_class.tool_schema[:function][:name].to_sym

        {
          tool_name: tool_name,
          class_name: full_class_name,
          file_path: file,
          relative_path: relative_path,
          agent_class: agent_class
        }
      rescue => e
        # Silently skip invalid agents (following existing pattern)
        nil
      end
    end

    # Extract tool names from auxiliary agent files
    #
    # @param config [LlmTeam::Configuration] Configuration object
    # @return [Array<Symbol>] Array of auxiliary agent tool names
    def self.extract_tool_names(config)
      files = discover_auxiliary_agent_files(config)
      tool_names = []

      files.each do |file|
        # Determine base path for this file
        base_path = find_base_path_for_file(file, config)
        next unless base_path

        agent_info = extract_agent_info_from_file(file, base_path)
        tool_names << agent_info[:tool_name] if agent_info
      end

      tool_names
    end

    # Validate that the loaded class is a proper auxiliary agent
    #
    # @param agent_class [Class] The class to validate
    # @return [Boolean] True if valid auxiliary agent
    def self.validate_auxiliary_agent_class(agent_class)
      return false unless agent_class < LlmTeam::Core::Agent
      return false unless agent_class.respond_to?(:tool_schema)
      return false unless agent_class.tool_schema.is_a?(Hash)
      return false unless agent_class.tool_schema.dig(:function, :name)
      true
    rescue
      false
    end

    private

    # Find the base path for a given file by matching against configured paths
    #
    # @param file [String] The file path
    # @param config [LlmTeam::Configuration] Configuration object
    # @return [String, nil] The base path or nil if not found
    def self.find_base_path_for_file(file, config)
      config.auxiliary_agents_paths.each do |path|
        auxiliary_agents_path = File.expand_path(path)
        if file.start_with?(auxiliary_agents_path)
          return auxiliary_agents_path
        end
      end
      nil
    end
  end
end
