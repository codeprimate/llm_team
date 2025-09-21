# frozen_string_literal: true

require "colorize"

module LlmTeam
  module Output
    OUTPUT_TYPES = {
      # Application Level - always visible
      app:           { icon: "🤖", color: [:blue, :bold],   indent: 0, level: :normal },
      user:          { icon: "💬", color: :cyan,            indent: 0, level: :normal },
      result:        { icon: "🎯", color: [:green, :bold],  indent: 0, level: :normal },
      
      # Workflow Level - visible in normal mode
      workflow:      { icon: "🔄", color: [:blue, :bold],   indent: 0, level: :normal },
      tool:          { icon: "🔧", color: :magenta,         indent: 2, level: :normal },
      status:        { icon: "✅", color: [:green, :bold],  indent: 2, level: :normal },
      
      # Technical Level - verbose only  
      technical:     { icon: "📡", color: :cyan,            indent: 2, level: :verbose },
      performance:   { icon: "⏱️", color: :light_black,     indent: 2, level: :verbose },
      data:          { icon: "📊", color: :light_black,     indent: 4, level: :verbose },
      
      # Error/Warning Level - context-sensitive
      error:         { icon: "❌", color: [:red, :bold],    indent: 0, level: :critical },
      warning:       { icon: "⚠️", color: :yellow,          indent: 0, level: :normal },
      retry:         { icon: "🔄", color: :yellow,          indent: 2, level: :verbose },
      
      # Debug Level - verbose only, deepest indent
      debug:         { icon: "🔍", color: :light_black,     indent: 6, level: :verbose }
    }
    
    def self.puts(message, type:, level: nil, color: nil, indent: nil)
      type_config = OUTPUT_TYPES[type]
      raise ArgumentError, "Unknown output type: #{type}" unless type_config
      
      effective_level = level || type_config[:level]
      return unless should_display?(effective_level)
      
      formatted_message = format_message(
        message, 
        type_config, 
        color: color, 
        indent: indent
      )
      Kernel.puts(formatted_message)
    end
    
    # Specific method for final answers to handle quiet mode formatting
    def self.final_answer(content)
      config = LlmTeam.configuration
      if config.quiet
        # Quiet mode: just the content, no decorations
        Kernel.puts(content)
      else
        # Normal/verbose mode: use result type with decorations
        Kernel.puts("\n" + "=" * 50)
        puts("FINAL ANSWER:", type: :result)
        Kernel.puts("=" * 50)
        Kernel.puts(content)
        Kernel.puts("=" * 50)
      end
    end
    
    # Special method for user prompts that need to show even in quiet mode for interactive use
    def self.user_prompt(prompt)
      config = LlmTeam.configuration
      # User prompts must be visible even in quiet mode for interactive operation
      if config.quiet
        # Minimal prompt in quiet mode
        print prompt
      else
        # Formatted prompt in normal/verbose mode
        formatted = format_message(prompt, OUTPUT_TYPES[:user])
        print formatted
      end
    end
    
    private
    
    def self.should_display?(level)
      config = LlmTeam.configuration
      
      # In quiet mode, only show critical errors and user prompts
      return false if config.quiet && level != :critical && level != :user_prompt
      
      # Always show critical and normal level messages
      return true if level == :critical || level == :normal
      
      # Show verbose level messages only when verbose is enabled
      return config.verbose if level == :verbose
      
      false
    end
    
    def self.format_message(message, type_config, color: nil, indent: nil)
      effective_color = color || type_config[:color]
      effective_indent = indent || type_config[:indent]
      icon = type_config[:icon]
      
      formatted = " " * effective_indent + icon + " " + message
      
      # Handle both single colors and color arrays (e.g., [:blue, :bold])
      if effective_color.is_a?(Array)
        effective_color.reduce(formatted) { |str, color_method| str.send(color_method) }
      else
        formatted.send(effective_color)
      end
    end
  end
end
