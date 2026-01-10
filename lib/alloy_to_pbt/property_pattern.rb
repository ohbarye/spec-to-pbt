# frozen_string_literal: true

# rbs_inline: enabled

module AlloyToPbt
  # Recognizes common property patterns in Alloy predicates
  class PropertyPattern
    # Pattern name to regex array mapping
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
      ],
      associativity: [
        /associative/i,
        /\(.*\+.*\)\s*\+.*=.*\+\s*\(.*\+.*\)/
      ],
      commutativity: [
        /commutative/i,
        /(\w+)\s*\+\s*(\w+)\s*=\s*\2\s*\+\s*\1/
      ],
      membership: [
        /contains|member/i,
        /in\s+\w+\.elements/i,
        /add.*implies.*contains/i
      ]
    }.freeze #: Hash[Symbol, Array[Regexp]]

    # Detect which patterns apply to a predicate
    # @rbs name: String
    # @rbs body: String
    # @rbs return: Array[Symbol]
    def self.detect(name, body)
      text = "#{name} #{body}"
      detected = [] #: Array[Symbol]

      PATTERNS.each do |pattern_name, regexes|
        if regexes.any? { |regex| text.match?(regex) }
          detected << pattern_name
        end
      end

      detected
    end
  end
end
