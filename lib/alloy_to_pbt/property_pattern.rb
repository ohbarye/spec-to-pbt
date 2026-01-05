# frozen_string_literal: true

module AlloyToPbt
  # Recognizes common property patterns in Alloy predicates
  class PropertyPattern
    PATTERNS = {
      roundtrip: [
        /push.*pop|pop.*push/i,
        /encode.*decode|decode.*encode/i,
        /serialize.*deserialize/i,
        /add.*remove|remove.*add/i
      ],
      idempotent: [
        /(\w+)\[.*\]\s*=\s*\1\[/i,
        /idempotent/i,
        /twice|same.*result/i
      ],
      invariant: [
        /sorted|ordered/i,
        /valid|invariant/i,
        /preserved|maintained/i
      ],
      size: [
        /#\w+.*=.*#\w+/,
        /length|size|count/i,
        /add\[.*1\]|sub\[.*1\]/i
      ],
      elements: [
        /elems\s*=\s*elems/i,
        /same.*elements/i,
        /permutation/i
      ],
      empty: [
        /#\w+\s*=\s*0/,
        /empty|nil|none/i
      ],
      ordering: [
        /lifo|fifo/i,
        /first.*last|last.*first/i,
        /head|tail|front|back/i
      ]
    }.freeze

    # Detect which patterns apply to a predicate
    # @param name [String] predicate name
    # @param body [String] predicate body
    # @return [Array<Symbol>] detected pattern names
    def self.detect(name, body)
      text = "#{name} #{body}"
      detected = []

      PATTERNS.each do |pattern_name, regexes|
        if regexes.any? { |regex| text.match?(regex) }
          detected << pattern_name
        end
      end

      detected
    end
  end
end
