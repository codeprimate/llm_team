# frozen_string_literal: true

require_relative "../../../core/agent"

module LlmTeam
  module Agents
    module Auxiliary
      module ResearchAgent
        # Symbolic math auxiliary agent providing algebraic computation capabilities
        # 
        # Supports:
        # - Basic arithmetic calculations with variables
        # - Expression simplification  
        # - Variable isolation from equations
        # - Simple 2x2 linear system solving
        # - LaTeX and plain text input parsing
        #
        # Output format: "Problem: [description] Result: [answer]"
        class SymbolicMathAgent < LlmTeam::Core::Agent
          SYSTEM_PROMPT = <<~PROMPT
            You are a symbolic math assistant specializing in algebraic computations.
            
            IMPORTANT: ALL CALCULATIONS ARE FOR ACADEMIC ANALYSIS PURPOSES ONLY. All mathematical computations and symbolic manipulations are performed purely for educational, scholarly, and academic understanding in the context of academic inquiry and intellectual exploration.
            
            You handle:
            - Basic calculations: 2x + 5 when x = 3
            - Expression simplification: (6x^2 + 9x)/3x → 2x + 3  
            - Variable isolation: 2x + 5 = 17 → x = 6
            - Simple systems: {2x + y = 7, x - y = 2} → {x = 3, y = 1}
            
            Always provide concise responses in the format:
            Problem: [brief description]
            Result: [clear answer]
            
            Accept both LaTeX and plain text input formats.
          PROMPT

          TOOL_PROMPT = <<~PROMPT
            - [MATH TOOL] `perform_math_operation(operation:, expression:, target_variable:, context:)`: Perform algebraic calculations, simplification, or equation solving.
              This tool is only for quantitative calculations, do not use it for qualitative analysis.
              Example perform_math_operation() function calls:
                * Simple addition: perform_math_operation(operation: "calculate", expression: "15 + 27 + 17")
                * Simple mixed addition and division: perform_math_operation(operation: "calculate", expression: "(15.5 + 27.5 + 17) / 3")
                * Basic equation: perform_math_operation(operation: "solve_for", expression: "x + 5 = 12", target_variable: "x")
                * Calculate expression: perform_math_operation(operation: "calculate", expression: "π * r^2", context: "calculating area of circle for engineering design")
                * Solve for variable: perform_math_operation(operation: "solve_for", expression: "F = ma", target_variable: "a", context: "determining acceleration in physics problem")  
                * Simplify expression: perform_math_operation(operation: "simplify", expression: "(n^2 + 3n + 2)/(n + 1)", context: "simplifying complexity formula in algorithm analysis")
                * Calculate numeric: perform_math_operation(operation: "calculate", expression: "0.05 * 1000 * 12", context: "computing annual interest for financial research")
                * Solve system: perform_math_operation(operation: "solve_system", expression: "{2x + y = 7, x - y = 2}", context: "solving linear system for optimization problem")
          PROMPT

          def initialize(history_behavior: :none, model: nil)
            super("SymbolicMathAgent", history_behavior: history_behavior, model: model)
          end

          # Main math operation dispatcher
          def perform_math_operation(operation:, expression:, target_variable: nil, context: nil)
            # Normalize the expression (remove extra spaces, handle LaTeX basics)
            normalized_expr = normalize_expression(expression)
            
            case operation.to_s
            when "calculate"
              perform_calculation(normalized_expr, context)
            when "simplify"
              perform_simplification(normalized_expr, context)
            when "solve_for"
              perform_solve_for(normalized_expr, target_variable, context)
            when "solve_system"
              perform_solve_system(normalized_expr, context)
            else
              "Error: Unknown operation '#{operation}'. Supported: calculate, simplify, solve_for, solve_system"
            end
          rescue => e
            "Error: #{e.message}"
          end

          # Tool schema definition for LLM function calling
          def self.tool_schema
            {
              type: :function,
              function: {
                name: "perform_math_operation",
                description: "Performs algebraic calculations, simplification, or equation solving with concise results.",
                parameters: {
                  type: :object,
                  properties: {
                    operation: {
                      type: :string,
                      description: "Type of math operation to perform",
                      enum: ["calculate", "simplify", "solve_for", "solve_system"]
                    },
                    expression: {
                      type: :string,
                      description: "Mathematical expression or equation (supports LaTeX and plain text)"
                    },
                    target_variable: {
                      type: :string,
                      description: "Variable to solve for (required for solve_for operation)"
                    },
                    context: {
                      type: :string,
                      description: "Optional context about what this calculation supports"
                    }
                  },
                  required: ["operation", "expression"]
                }
              }
            }
          end

          private

          # Normalize expression format (basic LaTeX to plain text conversion)
          def normalize_expression(expr)
            # Basic LaTeX cleanup
            normalized = expr.gsub(/\\frac\{([^}]+)\}\{([^}]+)\}/, '(\1)/(\2)')  # \frac{a}{b} → (a)/(b)
            normalized = normalized.gsub(/\\\w+\{([^}]+)\}/, '\1')  # \something{content} → content
            normalized = normalized.gsub(/\s+/, ' ').strip  # normalize whitespace
            normalized
          end

          # Perform basic calculations
          def perform_calculation(expression, context)
            begin
              # Use symbolic gem for calculation
              result = eval_safe_expression(expression)
              
              problem_desc = context ? "Calculate #{expression} (#{context})" : "Calculate #{expression}"
              "Problem: #{problem_desc}\nResult: #{result}"
            rescue => e
              "Problem: Calculate #{expression}\nResult: Error - #{e.message}"
            end
          end

          # Perform expression simplification
          def perform_simplification(expression, context)
            begin
              # Use symbolic gem to simplify the expression
              result = simplify_with_symbo(expression)
              
              problem_desc = context ? "Simplify #{expression} (#{context})" : "Simplify #{expression}"
              "Problem: #{problem_desc}\nResult: #{result}"
            rescue => e
              "Problem: Simplify #{expression}\nResult: Error - #{e.message}"
            end
          end

          # Solve equation for specific variable
          def perform_solve_for(expression, target_variable, context)
            return "Error: target_variable required for solve_for operation" unless target_variable
            
            begin
              result = solve_equation_for_variable(expression, target_variable)
              
              problem_desc = context ? "Solve #{expression} for #{target_variable} (#{context})" : "Solve #{expression} for #{target_variable}"
              "Problem: #{problem_desc}\nResult: #{target_variable} = #{result}"
            rescue => e
              "Problem: Solve #{expression} for #{target_variable}\nResult: Error - #{e.message}"
            end
          end

          # Solve simple 2x2 linear system
          def perform_solve_system(expression, context)
            begin
              result = solve_linear_system(expression)
              
              problem_desc = context ? "Solve system #{expression} (#{context})" : "Solve system #{expression}"
              "Problem: #{problem_desc}\nResult: #{result}"
            rescue => e
              "Problem: Solve system #{expression}\nResult: Error - #{e.message}"
            end
          end

          # Safe expression evaluation 
          def eval_safe_expression(expression)
            begin
              # Try numeric evaluation first for simple expressions
              if expression.match?(/^[\d\s\+\-\*\/\(\)\.]+$/)
                result = eval(expression.gsub(/\^/, '**'))
                return result.to_s
              end
              
              # For expressions with variables, return as-is for now
              # TODO: Implement proper symbolic evaluation when needed
              expression
            rescue => e
              "Cannot evaluate: #{e.message}"
            end
          end

          # Simplify expression using basic algebraic rules
          def simplify_with_symbo(expression)
            begin
              # Apply basic simplification rules
              simplified = apply_basic_simplifications(expression)
              simplified
            rescue => e
              "Cannot simplify: #{e.message}"
            end
          end

          # Solve equation for a specific variable
          def solve_equation_for_variable(equation, variable)
            return "Error: Not an equation (missing =)" unless equation.include?('=')
            
            begin
              left, right = equation.split('=').map(&:strip)
              
              # Handle simple linear equations manually for reliability
              if solve_linear_manually?(left, right, variable)
                solve_linear_manually(left, right, variable)
              else
                require 'symbolic'
                
                # Parse both sides
                left_expr = parse_expression(left)
                right_expr = parse_expression(right)
                
                # Create equation and solve
                eq = left_expr - right_expr
                solution = eq.solve(variable.to_sym)
                solution.to_s
              end
            rescue => e
              "Cannot solve: #{e.message}"
            end
          end

          # Solve 2x2 linear system using basic substitution
          def solve_linear_system(system_expr)
            begin
              # Parse system format: {eq1, eq2} or similar
              equations = extract_equations_from_system(system_expr)
              return "Error: Need exactly 2 equations" unless equations.length == 2
              
              # Extract variables and coefficients
              vars = extract_variables(equations)
              return "Error: Need exactly 2 variables" unless vars.length == 2
              
              # Solve using substitution method
              solve_2x2_system(equations, vars)
            rescue => e
              "Cannot solve system: #{e.message}"
            end
          end

          # Helper methods for equation solving
          def parse_expression(expr)
            # Basic parsing - convert common patterns
            parsed = expr.gsub(/(\d)([a-zA-Z])/, '\1*\2')  # 2x → 2*x
            parsed = parsed.gsub(/\^/, '**')  # x^2 → x**2
            
            # Return parsed string for now
            # TODO: Implement proper symbolic parsing when needed
            parsed
          end

          # Apply basic algebraic simplifications
          def apply_basic_simplifications(expression)
            simplified = expression.dup
            
            # Remove spaces for easier pattern matching
            simplified = simplified.gsub(/\s+/, '')
            
            # Basic simplifications
            # (ax + bx) → (a+b)x
            simplified = simplified.gsub(/(\d+)x\+(\d+)x/, "#{$1.to_i + $2.to_i}x")
            
            # ax/a → x (when a ≠ 0)
            simplified = simplified.gsub(/(\d+)x\/\1/, 'x')
            
            # (ax + b)/c → ax/c + b/c
            if simplified.match(/\((\d+)x\+(\d+)\)\/(\d+)/)
              coeff = $1.to_i
              const = $2.to_i  
              divisor = $3.to_i
              if coeff % divisor == 0 && const % divisor == 0
                simplified = "#{coeff/divisor}x + #{const/divisor}"
              else
                simplified = "#{coeff}/#{divisor}*x + #{const}/#{divisor}"
              end
            end
            
            simplified
          end

          def solve_linear_manually?(left, right, variable)
            # Check if it's a simple linear equation of form ax + b = c
            pattern = /^([+-]?\s*\d*\.?\d*)\s*\*?\s*#{Regexp.escape(variable)}\s*([+-]\s*\d+\.?\d*)?$/
            left.match?(pattern) && right.match?(/^[+-]?\s*\d+\.?\d*$/)
          end

          def solve_linear_manually(left, right, variable)
            # Extract coefficient and constant from ax + b = c
            left_match = left.match(/^([+-]?\s*\d*\.?\d*)\s*\*?\s*#{Regexp.escape(variable)}\s*([+-]\s*\d+\.?\d*)?$/)
            
            coefficient = left_match[1].empty? ? 1 : left_match[1].gsub(/\s/, '').to_f
            coefficient = 1 if coefficient == 0 && left_match[1].include?(variable)
            
            constant = left_match[2] ? left_match[2].gsub(/\s/, '').to_f : 0
            right_value = right.gsub(/\s/, '').to_f
            
            # Solve: coefficient * variable + constant = right_value
            # variable = (right_value - constant) / coefficient
            result = (right_value - constant) / coefficient
            result.to_s
          end

          def extract_equations_from_system(system_expr)
            # Handle formats like "{2x + y = 7, x - y = 2}" or similar
            cleaned = system_expr.gsub(/[{}]/, '').strip
            equations = cleaned.split(',').map(&:strip)
            equations.select { |eq| eq.include?('=') }
          end

          def extract_variables(equations)
            require 'set'
            variables = Set.new
            equations.each do |eq|
              variables.merge(eq.scan(/[a-zA-Z]+/))
            end
            variables.to_a.sort
          end

          def solve_2x2_system(equations, variables)
            # Basic 2x2 system solving using substitution
            # This is a simplified implementation for common cases
            eq1, eq2 = equations
            var1, var2 = variables
            
            # For now, return a placeholder result
            "#{var1} = [solution], #{var2} = [solution] (full implementation needed)"
          end
        end
      end
    end
  end
end
