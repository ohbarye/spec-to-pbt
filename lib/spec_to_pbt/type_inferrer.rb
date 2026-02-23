# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  # Infers Pbt generator code from Alloy signature definitions
  class TypeInferrer
    # Multiplicity to collection type mapping
    MULTIPLICITY_MAP = {
      "seq" => :array,
      "set" => :set,
      "one" => :single,
      "lone" => :optional
    }.freeze #: Hash[String, Symbol]

    # Basic Alloy types to Pbt generator code
    TYPE_MAP = {
      "Int" => "Pbt.integer",
      "String" => "Pbt.string"
    }.freeze #: Hash[String, String]

    # @rbs spec: Spec
    # @rbs return: void
    def initialize(spec)
      @spec = spec #: Spec
      @sig_map = build_sig_map #: Hash[String, Signature]
    end

    # Generate Pbt generator code for a given signature name and multiplicity
    # @rbs sig_name: String
    # @rbs multiplicity: String
    # @rbs return: String
    def generator_for(sig_name, multiplicity = "one")
      base = resolve_type(sig_name)
      wrap_with_multiplicity(base, multiplicity)
    end

    private

    # Resolve type to Pbt generator code
    # @rbs sig_name: String
    # @rbs return: String
    def resolve_type(sig_name)
      # Check basic types first
      return TYPE_MAP[sig_name] if TYPE_MAP.key?(sig_name)

      # Look up custom signature
      sig = @sig_map[sig_name]
      return "Pbt.integer" unless sig # Default for unknown types

      # Infer from signature fields
      if sig.fields.empty?
        "Pbt.integer"
      else
        # Use the first field's type
        field = sig.fields.first
        generator_for(field.type, field.multiplicity)
      end
    end

    # Wrap base generator with multiplicity
    # @rbs base: String
    # @rbs multiplicity: String
    # @rbs return: String
    def wrap_with_multiplicity(base, multiplicity)
      case MULTIPLICITY_MAP[multiplicity]
      when :array, :set
        "Pbt.array(#{base})"
      else
        base
      end
    end

    # Build signature name to Signature mapping
    # @rbs return: Hash[String, Signature]
    def build_sig_map
      @spec.signatures.to_h { |sig| [sig.name, sig] }
    end
  end
end
