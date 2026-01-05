# Plan: alloy_to_pbt Ruby化

## 概要
Python POCをRubyに移植。Alloy仕様からpbt gem互換のProperty-Based Testを生成。

## 決定事項

| 項目 | 決定 | 理由 |
|------|------|------|
| プロジェクト名 | `alloy_to_pbt` | Ruby命名規約 |
| Rubyバージョン | 3.2+ | Data.define使用 |
| データクラス | Data.define | immutable, pattern match |
| CLI引数解析 | OptionParser | Ruby標準 |
| テンプレート | ERB | 可読性、拡張性 |
| テストFW（自身） | RSpec | ユニット+統合 |
| 生成コードFW | RSpec形式 | describe/it |
| 仮実装スタブ | 含める | デモ用 |
| スコープ | sort/stack優先、汎用拡張可能 | 段階的 |
| エラー処理 | 例外raise | シンプル |
| CLI出力 | シンプル | 最小限 |
| 出力先 | generated/ | 整理 |
| Pythonファイル | alloy2pbt-poc放置 | 新規ディレクトリで作業 |

## ファイル構成

```
poc/
├── alloy2pbt-poc/                 # 旧Python実装（放置）
└── alloy_to_pbt/                  # 新規Ruby実装
    ├── lib/
    │   ├── alloy_to_pbt.rb           # メインエントリー
    │   └── alloy_to_pbt/
    │       ├── version.rb            # バージョン定義
    │       ├── parser.rb             # Alloyパーサー
    │       ├── property_pattern.rb   # パターン認識
    │       ├── generator.rb          # PBTコード生成
    │       └── templates/
    │           ├── sort.erb          # sortテンプレート
    │           ├── stack.erb         # stackテンプレート
    │           └── generic.erb       # 汎用テンプレート
    ├── bin/
    │   └── alloy_to_pbt              # CLI実行ファイル
    ├── spec/
    │   ├── spec_helper.rb
    │   ├── alloy_to_pbt/
    │   │   ├── parser_spec.rb
    │   │   ├── property_pattern_spec.rb
    │   │   └── generator_spec.rb
    │   └── integration/
    │       └── cli_spec.rb           # E2Eテスト
    ├── fixtures/
    │   ├── sort.als                  # テスト用サンプル（alloy2pbt-pocからコピー）
    │   └── stack.als
    ├── generated/                     # 生成ファイル出力先
    ├── Gemfile
    └── .ruby-version                  # 3.2.0
```

## 実装ステップ

### Step 1: プロジェクト構造セットアップ
- [ ] poc/alloy_to_pbt/ディレクトリ構造作成
- [ ] Gemfile作成（pbt, rspec依存）
- [ ] .ruby-version作成
- [ ] sort.als, stack.alsをalloy2pbt-pocからfixtures/へコピー

### Step 2: Parser実装
**ファイル**: `lib/alloy_to_pbt/parser.rb`
```ruby
module AlloyToPbt
  Field = Data.define(:name, :type, :multiplicity)
  Signature = Data.define(:name, :fields, :extends)
  Predicate = Data.define(:name, :params, :body)
  Assertion = Data.define(:name, :body)
  Fact = Data.define(:name, :body)
  Spec = Data.define(:module_name, :signatures, :predicates, :assertions, :facts)

  class Parser
    def parse(source) -> Spec
    def to_h -> Hash
    def to_json -> String
  end

  class ParseError < StandardError; end
end
```

### Step 3: PropertyPattern実装
**ファイル**: `lib/alloy_to_pbt/property_pattern.rb`
```ruby
module AlloyToPbt
  class PropertyPattern
    PATTERNS = {
      roundtrip: [...],
      idempotent: [...],
      invariant: [...],
      size: [...],
      elements: [...],
      empty: [...],
      ordering: [...]
    }

    def self.detect(name, body) -> Array[Symbol]
  end
end
```

### Step 4: Generator実装
**ファイル**: `lib/alloy_to_pbt/generator.rb`
```ruby
module AlloyToPbt
  class Generator
    def initialize(spec)
    def analyze -> Hash  # パターン検出結果
    def generate -> String  # ERBでRubyコード生成
  end
end
```

### Step 5: ERBテンプレート作成
**ファイル**: `lib/alloy_to_pbt/templates/sort.erb`
```erb
# frozen_string_literal: true
# Auto-generated from Alloy specification: <%= spec.module_name %>

require "pbt"

def sort(array)
  array.sort
end

RSpec.describe "<%= spec.module_name %>" do
  describe "Sort Properties" do
    it "satisfies all properties" do
      Pbt.assert do
        Pbt.property(Pbt.array(Pbt.integer)) do |input|
          output = sort(input)
          <% properties.each do |prop| %>
          # Property: <%= prop.name %>
          <%= prop.check_code %>
          <% end %>
        end
      end
    end
  end
end
```

### Step 6: CLI実装
**ファイル**: `bin/alloy_to_pbt`
```ruby
#!/usr/bin/env ruby
require "optparse"
require "alloy_to_pbt"

options = { output_dir: "generated" }
OptionParser.new do |opts|
  opts.banner = "Usage: alloy_to_pbt INPUT.als [options]"
  opts.on("-o", "--output DIR", "Output directory") { |v| options[:output_dir] = v }
  opts.on("-h", "--help", "Show help") { puts opts; exit }
end.parse!

# パース → 生成 → 出力
```

### Step 7: RSpecテスト実装
- [ ] `spec/alloy_to_pbt/parser_spec.rb`
  - sort.als, stack.alsのパース検証
  - 各要素（sig, pred, assert, fact）の抽出確認
- [ ] `spec/alloy_to_pbt/property_pattern_spec.rb`
  - パターン検出のテスト
- [ ] `spec/alloy_to_pbt/generator_spec.rb`
  - 生成コードの構文チェック
- [ ] `spec/integration/cli_spec.rb`
  - E2E: .als → .rb 変換全体

### Step 8: 動作確認
- [ ] `bundle exec bin/alloy_to_pbt fixtures/sort.als`
- [ ] 生成された `generated/sort_pbt.rb` を確認
- [ ] `bundle exec rspec generated/sort_pbt.rb` で実行

## 移植対応表

| Python | Ruby |
|--------|------|
| `alloy_parser.py` | `lib/alloy_to_pbt/parser.rb` |
| `improved_generator.py` PropertyPattern | `lib/alloy_to_pbt/property_pattern.rb` |
| `improved_generator.py` ImprovedPbtGenerator | `lib/alloy_to_pbt/generator.rb` |
| `alloy2pbt.py` | `bin/alloy_to_pbt` |
| 文字列連結テンプレート | `lib/alloy_to_pbt/templates/*.erb` |

## 主要な変換例

### Python dataclass → Ruby Data.define
```python
@dataclass
class Field:
    name: str
    type: str
    multiplicity: str = "one"
```
↓
```ruby
Field = Data.define(:name, :type, :multiplicity) do
  def initialize(name:, type:, multiplicity: "one") = super
end
```

### 正規表現パターン（変更なし）
```ruby
SIG_PATTERN = /sig\s+(\w+)(?:\s+extends\s+(\w+))?\s*\{([^}]*)\}/m
```
