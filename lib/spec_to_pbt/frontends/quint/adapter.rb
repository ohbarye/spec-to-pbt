# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  module Frontends
    module Quint
      class Adapter
        SUPPORTED_DEF_QUALIFIERS = %w[action val puredef].freeze #: Array[String]
        UNSUPPORTED_DEF_QUALIFIERS = %w[temporal].freeze #: Array[String]
        SUPPORTED_VAR_TYPES = %w[int str list set].freeze #: Array[String]

        # @rbs parse_json: Hash[String, untyped]
        # @rbs typecheck_json: Hash[String, untyped]
        # @rbs return: Core::SpecDocument
        def adapt(parse_json:, typecheck_json:)
          parse_module = extract_module(parse_json)
          type_module = extract_module(typecheck_json)
          module_name = type_module.fetch("name")
          declarations = Array(type_module["declarations"])
          type_table = typecheck_json.fetch("types", {})
          state_variables = declarations.select { |decl| decl["kind"] == "var" }
          state_type_name = state_variables.empty? ? nil : "#{camelize(module_name)}State"

          reject_unsupported_declarations!(declarations)

          type_entities = state_type_name ? [build_state_type(state_type_name, state_variables, type_table)] : []
          function_entities = [] #: Array[Core::Entity]
          property_entities = [] #: Array[Core::Entity]
          pure_defs = declarations.select { |decl| decl["kind"] == "def" && decl["qualifier"] == "puredef" } #: Array[Hash[String, untyped]]
          operation_name = nil #: String?
          operation_parameter = nil #: Hash[Symbol, String]?

          if state_variables.empty?
            operation_name, operation_parameter = select_operation!(pure_defs, type_table)
          end

          declarations.each do |decl|
            next if decl["kind"] == "var"

            case decl.fetch("qualifier")
            when "action"
              property_entities << adapt_action(decl, state_type_name, state_variables, type_table)
            when "val"
              property_entities << adapt_val(decl, state_type_name, state_variables)
            when "puredef"
              function_entities << adapt_pure_def(decl, type_table)
            else
              raise SpecToPbt::FrontendError, "Unsupported Quint declaration qualifier #{decl['qualifier'].inspect}"
            end
          end

          metadata = {
            state_variables: state_variables.map { |decl| field_metadata(decl, type_table) },
            operation_name: operation_name,
            operation_parameter: operation_parameter,
            raw_parse: parse_module,
            raw_typecheck: type_module
          } #: Hash[Symbol, untyped]

          Core::SpecDocument.new(
            name: module_name,
            entities: type_entities + function_entities + property_entities,
            types: type_entities,
            properties: property_entities,
            assertions: [],
            facts: [],
            source_format: :quint,
            metadata: metadata
          )
        end

        private

        # @rbs document: Hash[String, untyped]
        # @rbs return: Hash[String, untyped]
        def extract_module(document)
          modules = Array(document["modules"])
          raise SpecToPbt::FrontendError, "Expected exactly one Quint module" unless modules.length == 1

          modules.first
        end

        # @rbs declarations: Array[Hash[String, untyped]]
        # @rbs return: void
        def reject_unsupported_declarations!(declarations)
          declarations.each do |decl|
            if decl["kind"] != "var" && decl["kind"] != "def"
              raise SpecToPbt::FrontendError, "Unsupported Quint declaration kind #{decl['kind'].inspect} is out of scope for v1"
            end

            next unless decl["kind"] == "def"

            qualifier = decl["qualifier"]
            if UNSUPPORTED_DEF_QUALIFIERS.include?(qualifier)
              raise SpecToPbt::FrontendError, "Quint #{qualifier} properties are out of scope for v1"
            end
            next if SUPPORTED_DEF_QUALIFIERS.include?(qualifier)

            raise SpecToPbt::FrontendError, "Unsupported Quint definition qualifier #{qualifier.inspect} is out of scope for v1"
          end
        end

        # @rbs state_type_name: String
        # @rbs state_variables: Array[Hash[String, untyped]]
        # @rbs type_table: Hash[String, untyped]
        # @rbs return: Core::Entity
        def build_state_type(state_type_name, state_variables, type_table)
          Core::Entity.new(
            name: state_type_name,
            kind: :type,
            fields: state_variables.map do |decl|
              field = field_metadata(decl, type_table)
              Core::Field.new(name: field[:name], type: field[:type], multiplicity: field[:multiplicity])
            end,
            metadata: { category: :module_state_type, source: :quint }
          )
        end

        # @rbs decl: Hash[String, untyped]
        # @rbs type_table: Hash[String, untyped]
        # @rbs return: Hash[Symbol, untyped]
        def field_metadata(decl, type_table)
          type_name, multiplicity = decode_type(type_for(decl.fetch("id"), type_table) || decl["typeAnnotation"])
          {
            name: decl.fetch("name"),
            type: type_name,
            multiplicity: multiplicity
          }
        end

        # @rbs decl: Hash[String, untyped]
        # @rbs state_type_name: String?
        # @rbs state_variables: Array[Hash[String, untyped]]
        # @rbs type_table: Hash[String, untyped]
        # @rbs return: Core::Entity
        def adapt_action(decl, state_type_name, state_variables, type_table)
          params, expr = extract_callable(decl, type_table)
          state_fields = state_variables.to_h do |var_decl|
            field = field_metadata(var_decl, type_table)
            [field[:name], field]
          end
          guards, updates = extract_action_components(expr, state_fields, params)
          state_field = updates.first && updates.first[:field]
          update = updates.first

          Core::Entity.new(
            name: decl.fetch("name"),
            kind: :property,
            params: params,
            raw_text: render_expr(expr),
            normalized_text: normalize_text(render_expr(expr)),
            metadata: {
              semantic_hints: {
                qualifier: :action,
                state_type: state_type_name,
                state_param_names: [],
                guards: guards,
                state_updates: updates,
                state_field: state_field,
                size_delta: update && update[:size_delta],
                transition_kind: update && update[:transition_kind],
                result_position: update && update[:result_position],
                scalar_update_kind: update && update[:scalar_update_kind],
                state_update_shape: update && update[:update_shape],
                command_confidence: update && update[:command_confidence]
              }
            }
          )
        end

        # @rbs decl: Hash[String, untyped]
        # @rbs state_type_name: String?
        # @rbs state_variables: Array[Hash[String, untyped]]
        # @rbs return: Core::Entity
        def adapt_val(decl, state_type_name, state_variables)
          expr = decl.fetch("expr")
          state_names = state_variables.map { |item| item.fetch("name") }
          property_category = state_names.any? { |name| expr_uses_name?(expr, name) } ? :invariant : nil

          Core::Entity.new(
            name: decl.fetch("name"),
            kind: :property,
            raw_text: render_expr(expr),
            normalized_text: normalize_text(render_expr(expr)),
            metadata: {
              semantic_hints: {
                qualifier: :val,
                state_type: state_type_name,
                property_category: property_category
              }
            }
          )
        end

        # @rbs decl: Hash[String, untyped]
        # @rbs type_table: Hash[String, untyped]
        # @rbs return: Core::Entity
        def adapt_pure_def(decl, type_table)
          params, expr = extract_callable(decl, type_table)

          Core::Entity.new(
            name: decl.fetch("name"),
            kind: :function,
            params: params,
            raw_text: render_expr(expr),
            normalized_text: normalize_text(render_expr(expr)),
            metadata: {
              semantic_hints: {
                qualifier: :puredef
              }
            }
          )
        end

        # @rbs pure_defs: Array[Hash[String, untyped]]
        # @rbs type_table: Hash[String, untyped]
        # @rbs return: [String, Hash[Symbol, String]]
        def select_operation!(pure_defs, type_table)
          raise SpecToPbt::FrontendError, "Stateless Quint support requires exactly one pure top-level def" unless pure_defs.length == 1

          pure_def = pure_defs.first
          params, = extract_callable(pure_def, type_table)
          raise SpecToPbt::FrontendError, "Stateless Quint support requires a unary pure top-level def" unless params.length == 1

          param = params.first
          [pure_def.fetch("name"), { type: param.type, multiplicity: param.metadata[:multiplicity] || "one" }]
        end

        # @rbs decl: Hash[String, untyped]
        # @rbs type_table: Hash[String, untyped]
        # @rbs return: [Array[Core::Parameter], Hash[String, untyped]]
        def extract_callable(decl, type_table)
          expr = decl.fetch("expr")
          return [[], expr] unless expr["kind"] == "lambda"

          params = Array(expr["params"]).map do |param|
            type_name, multiplicity = decode_type(type_for(param.fetch("id"), type_table) || param["typeAnnotation"])
            Core::Parameter.new(name: param.fetch("name"), type: type_name, role: :argument, metadata: { multiplicity: multiplicity })
          end
          [params, expr.fetch("expr")]
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs state_fields: Hash[String, Hash[Symbol, untyped]]
        # @rbs params: Array[Core::Parameter]
        # @rbs return: [Array[Hash[Symbol, untyped]], Array[Hash[Symbol, untyped]]]
        def extract_action_components(expr, state_fields, params)
          components =
            if expr["kind"] == "app" && expr["opcode"] == "actionAll"
              Array(expr["args"])
            else
              [expr]
            end

          guards = [] #: Array[Hash[Symbol, untyped]]
          updates = [] #: Array[Hash[Symbol, untyped]]

          components.each do |component|
            if assignment?(component)
              updates << classify_assignment(component, state_fields, params)
            else
              guards << classify_guard(component)
            end
          end

          [guards.compact, updates]
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs return: bool
        def assignment?(expr)
          expr["kind"] == "app" && expr["opcode"] == "assign"
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs return: Hash[Symbol, untyped]?
        def classify_guard(expr)
          return nil unless expr["kind"] == "app"

          opcode = expr["opcode"]
          args = Array(expr["args"])
          if non_empty_collection_guard?(opcode, args[0], args[1])
            return { kind: :non_empty, field: args[0]["args"][0]["name"], constant: nil }
          end
          if positive_scalar_guard?(opcode, args[0], args[1])
            return { kind: :non_empty, field: args[0]["name"], constant: nil }
          end
          if opcode == "eq" && name_node?(args[0]) && int_node?(args[1])
            return { kind: :state_equals_constant, field: args[0]["name"], constant: args[1]["value"].to_s }
          end

          nil
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs state_fields: Hash[String, Hash[Symbol, untyped]]
        # @rbs params: Array[Core::Parameter]
        # @rbs return: Hash[Symbol, untyped]
        def classify_assignment(expr, state_fields, params)
          lhs, rhs = Array(expr.fetch("args"))
          field_name = lhs.fetch("name")
          field = state_fields.fetch(field_name)
          param_names = params.map(&:name)
          rhs_info = classify_rhs(rhs, field_name, param_names)

          {
            field: field_name,
            kind: :assignment,
            update_shape: rhs_info.fetch(:update_shape),
            rhs_kind: rhs_info.fetch(:rhs_kind),
            rhs_source_kind: rhs_info.fetch(:rhs_source_kind),
            rhs_source_field: rhs_info[:rhs_source_field],
            rhs_arg_name: rhs_info[:rhs_arg_name],
            rhs_constant: rhs_info[:rhs_constant],
            size_delta: rhs_info[:size_delta],
            transition_kind: rhs_info[:transition_kind],
            result_position: rhs_info[:result_position],
            scalar_update_kind: rhs_info[:scalar_update_kind],
            command_confidence: rhs_info.fetch(:command_confidence),
            state_field_multiplicity: field[:multiplicity]
          }
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs field_name: String
        # @rbs param_names: Array[String]
        # @rbs return: Hash[Symbol, untyped]
        def classify_rhs(expr, field_name, param_names)
          if expr["kind"] == "app"
            args = Array(expr["args"])
            case expr["opcode"]
            when "iadd"
              if name_for(args[0]) == field_name && int_literal?(args[1], 1)
                return {
                  update_shape: :increment,
                  rhs_kind: :increment,
                  rhs_source_kind: :constant,
                  rhs_constant: 1,
                  size_delta: 1,
                  transition_kind: nil,
                  result_position: nil,
                  scalar_update_kind: :increment_like,
                  command_confidence: :medium
                }
              end
            when "isub"
              if name_for(args[0]) == field_name && int_literal?(args[1], 1)
                return {
                  update_shape: :decrement,
                  rhs_kind: :decrement,
                  rhs_source_kind: :constant,
                  rhs_constant: 1,
                  size_delta: -1,
                  transition_kind: nil,
                  result_position: nil,
                  scalar_update_kind: :decrement_like,
                  command_confidence: :medium
                }
              end
            when "append"
              if name_for(args[0]) == field_name && name_node?(args[1]) && param_names.include?(args[1]["name"])
                return {
                  update_shape: :append_like,
                  rhs_kind: :append_arg,
                  rhs_source_kind: :arg,
                  rhs_arg_name: args[1]["name"],
                  size_delta: 1,
                  transition_kind: :append,
                  result_position: nil,
                  scalar_update_kind: nil,
                  command_confidence: :high
                }
              end
            when "tail"
              if name_for(args[0]) == field_name
                return {
                  update_shape: :remove_first,
                  rhs_kind: :remove_first,
                  rhs_source_kind: :state_field,
                  rhs_source_field: field_name,
                  size_delta: -1,
                  transition_kind: :dequeue,
                  result_position: :first,
                  scalar_update_kind: nil,
                  command_confidence: :high
                }
              end
            end
          end

          if name_node?(expr) && expr["name"] == field_name
            return {
              update_shape: :preserve_value,
              rhs_kind: :preserve_value,
              rhs_source_kind: :state_field,
              rhs_source_field: field_name,
              size_delta: 0,
              transition_kind: nil,
              result_position: nil,
              scalar_update_kind: :replace_like,
              command_confidence: :medium
            }
          end

          if name_node?(expr) && param_names.include?(expr["name"])
            return {
              update_shape: :replace_with_arg,
              rhs_kind: :replace_with_arg,
              rhs_source_kind: :arg,
              rhs_arg_name: expr["name"],
              size_delta: nil,
              transition_kind: nil,
              result_position: nil,
              scalar_update_kind: :replace_like,
              command_confidence: :medium
            }
          end

          if int_node?(expr)
            return {
              update_shape: :replace_constant,
              rhs_kind: :replace_constant,
              rhs_source_kind: :constant,
              rhs_constant: expr["value"],
              size_delta: nil,
              transition_kind: nil,
              result_position: nil,
              scalar_update_kind: :replace_like,
              command_confidence: :medium
            }
          end

          raise SpecToPbt::FrontendError, "Unsupported Quint assignment shape for #{field_name.inspect} is out of scope for v1"
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs name: String
        # @rbs return: bool
        def expr_uses_name?(expr, name)
          return true if expr["kind"] == "name" && expr["name"] == name
          return false unless expr["kind"] == "app"

          Array(expr["args"]).any? { |child| expr_uses_name?(child, name) }
        end

        # @rbs id: Integer
        # @rbs type_table: Hash[String, untyped]
        # @rbs return: Hash[String, untyped]?
        def type_for(id, type_table)
          entry = type_table[id.to_s]
          entry && entry["type"]
        end

        # @rbs type_json: Hash[String, untyped]?
        # @rbs return: [String, String]
        def decode_type(type_json)
          raise SpecToPbt::FrontendError, "Missing Quint type information" unless type_json

          case type_json["kind"]
          when "int"
            ["Int", "one"]
          when "str"
            ["String", "one"]
          when "list"
            elem_type, = decode_type(type_json["elem"])
            [elem_type, "seq"]
          when "set"
            elem_type, = decode_type(type_json["elem"])
            [elem_type, "set"]
          else
            raise SpecToPbt::FrontendError, "Unsupported Quint type #{type_json['kind'].inspect} is out of scope for v1"
          end
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs return: String
        def render_expr(expr)
          case expr["kind"]
          when "name"
            expr.fetch("name")
          when "int"
            expr.fetch("value").to_s
          when "app"
            render_app(expr)
          when "lambda"
            render_expr(expr.fetch("expr"))
          else
            expr.inspect
          end
        end

        # @rbs expr: Hash[String, untyped]
        # @rbs return: String
        def render_app(expr)
          opcode = expr.fetch("opcode")
          args = Array(expr["args"])

          case opcode
          when "iadd"
            "#{render_expr(args[0])} + #{render_expr(args[1])}"
          when "isub"
            "#{render_expr(args[0])} - #{render_expr(args[1])}"
          when "eq"
            "#{render_expr(args[0])} == #{render_expr(args[1])}"
          when "igte"
            "#{render_expr(args[0])} >= #{render_expr(args[1])}"
          when "igt"
            "#{render_expr(args[0])} > #{render_expr(args[1])}"
          when "length"
            "length(#{render_expr(args[0])})"
          when "append"
            "append(#{args.map { |arg| render_expr(arg) }.join(', ')})"
          when "tail"
            "tail(#{render_expr(args[0])})"
          when "assign"
            "#{render_expr(args[0])}' = #{render_expr(args[1])}"
          when "actionAll"
            args.map { |arg| render_expr(arg) }.join(" and ")
          else
            "#{opcode}(#{args.map { |arg| render_expr(arg) }.join(', ')})"
          end
        end

        # @rbs value: String
        # @rbs return: String
        def normalize_text(value)
          value.gsub(/\s+/, " ").gsub(/\s*([=+\-<>\(\),])\s*/, '\1').strip
        end

        # @rbs expr: Hash[String, untyped]?
        # @rbs return: bool
        def name_node?(expr)
          !expr.nil? && expr["kind"] == "name"
        end

        # @rbs expr: Hash[String, untyped]?
        # @rbs return: String?
        def name_for(expr)
          expr && expr["kind"] == "name" ? expr["name"] : nil
        end

        # @rbs expr: Hash[String, untyped]?
        # @rbs return: bool
        def int_node?(expr)
          !expr.nil? && expr["kind"] == "int"
        end

        # @rbs expr: Hash[String, untyped]?
        # @rbs value: Integer
        # @rbs return: bool
        def int_literal?(expr, value)
          int_node?(expr) && expr["value"] == value
        end

        # @rbs opcode: String
        # @rbs lhs: Hash[String, untyped]?
        # @rbs return: bool
        def non_empty_collection_guard?(opcode, lhs, rhs)
          return false unless length_of_name?(lhs)
          return true if opcode == "igt" && int_literal?(rhs, 0)
          return true if opcode == "igte" && int_literal?(rhs, 1)

          false
        end

        # @rbs opcode: String
        # @rbs lhs: Hash[String, untyped]?
        # @rbs rhs: Hash[String, untyped]?
        # @rbs return: bool
        def positive_scalar_guard?(opcode, lhs, rhs)
          return false unless name_node?(lhs)
          return true if opcode == "igt" && int_literal?(rhs, 0)
          return true if opcode == "igte" && int_literal?(rhs, 1)

          false
        end

        # @rbs expr: Hash[String, untyped]?
        # @rbs return: bool
        def length_of_name?(expr)
          expr && expr["kind"] == "app" && expr["opcode"] == "length" && name_node?(Array(expr["args"]).first)
        end

        # @rbs value: String
        # @rbs return: String
        def camelize(value)
          value.to_s.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
        end
      end
    end
  end
end
