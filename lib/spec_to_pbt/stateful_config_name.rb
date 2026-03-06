# frozen_string_literal: true

# rbs_inline: enabled

module SpecToPbt
  class StatefulConfigName
    # @rbs spec_name: String?
    # @rbs return: Hash[Symbol, String]
    def self.for(spec_name)
      module_name = spec_name.to_s
      camelized = module_name.split(/[^a-zA-Z0-9]+/).reject(&:empty?).map { |part| part[0].upcase + part[1..] }.join
      underscored = module_name.empty? ? "operation" : module_name

      {
        constant_name: "#{camelized}PbtConfig",
        file_basename: "#{underscored}_pbt_config"
      }
    end
  end
end
