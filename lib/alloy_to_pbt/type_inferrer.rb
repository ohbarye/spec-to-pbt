# frozen_string_literal: true

module AlloyToPbt
  # Infers Pbt generator code from Alloy signature definitions
  class TypeInferrer
    # Multiplicity to collection type mapping
    MULTIPLICITY_MAP = {
      "seq" => :array,
      "set" => :set,
      "one" => :single,
      "lone" => :optional
    }.freeze

    # Basic Alloy types to Pbt generator code
    TYPE_MAP = {
      "Int" => "Pbt.integer",
      "String" => "Pbt.string"
    }.freeze

    def initialize(spec)
      @spec = spec
      @sig_map = build_sig_map
    end

    # Generate Pbt generator code for a given signature name and multiplicity
    # @param sig_name [String] the signature name (e.g., "Element", "Int")
    # @param multiplicity [String] the multiplicity (e.g., "seq", "one")
    # @return [String] Pbt generator code (e.g., "Pbt.array(Pbt.integer)")
    def generator_for(sig_name, multiplicity = "one")
      base = resolve_type(sig_name)
      wrap_with_multiplicity(base, multiplicity)
    end

    private

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

    def wrap_with_multiplicity(base, multiplicity)
      case MULTIPLICITY_MAP[multiplicity]
      when :array, :set
        "Pbt.array(#{base})"
      else
        base
      end
    end

    def build_sig_map
      @spec.signatures.to_h { |sig| [sig.name, sig] }
    end
  end
end
