# alloy2pbt - Proof of Concept

Alloy仕様からRuby PBT (Property-Based Testing) コードを生成する実験的ツール。

## 実験結果

### ✅ 成功したこと

1. **Alloy仕様のパース** — 簡易的なパーサーでsig, pred, assert, factを抽出
2. **プロパティパターンの検出** — invariant, roundtrip, idempotent等のパターンを自動認識
3. **pbtコードの生成** — 型情報からArbitrary、述語からプロパティを生成

### 📁 ファイル構成

```
alloy2pbt-poc/
├── alloy_parser.py      # Alloyパーサー
├── improved_generator.py # パターン認識付きPBTジェネレーター
├── alloy2pbt.py         # CLIツール
├── sort.als             # サンプル: ソート仕様
├── stack.als            # サンプル: スタック仕様
└── generated/
    ├── sort_pbt.rb      # 生成されたソートのPBT
    └── stack_pbt.rb     # 生成されたスタックのPBT
```

## 使い方

```bash
python3 alloy2pbt.py <input.als> [output.rb]
```

### 例: ソート仕様からPBT生成

```bash
python3 alloy2pbt.py sort.als generated/sort_pbt.rb
```

出力:
```
╔═══════════════════════════════════════════════════════════╗
║                      alloy2pbt                            ║
║     Alloy Specification → Ruby Property-Based Tests       ║
╚═══════════════════════════════════════════════════════════╝

📖 Reading: sort.als
✓ Parsed successfully
  - Module: sort
  - Signatures: 2
  - Predicates: 4
  - Assertions: 1

🔍 Detected Property Patterns:
   Sorted: invariant, size
   LengthPreserved: invariant, size
   SameElements: elements
   Idempotent: idempotent, invariant

✅ Generated: generated/sort_pbt.rb
```

## Alloy仕様の例

### sort.als

```alloy
module sort

sig Element { value: one Int }
sig List { elements: seq Element }

pred Sorted[l: List] {
  all i: Int | (i >= 0 and i < sub[#l.elements, 1]) implies
    l.elements[i].value <= l.elements[add[i, 1]].value
}

pred LengthPreserved[input, output: List] {
  #input.elements = #output.elements
}

pred SameElements[input, output: List] {
  input.elements.elems = output.elements.elems
}

pred Idempotent[l: List] {
  Sorted[l] implies l.elements = l.elements
}
```

### 生成されるRuby PBT

```ruby
Pbt.assert do
  Pbt.property(Pbt.array(Pbt.integer)) do |input|
    output = sort(input)

    # Property 1: Sorted
    raise "Sorted failed" unless output.each_cons(2).all? { |a, b| a <= b }

    # Property 2: LengthPreserved
    raise "LengthPreserved failed" unless input.length == output.length

    # Property 3: SameElements
    raise "SameElements failed" unless input.sort == output.sort

    # Property 4: Idempotent
    raise "Idempotent failed" unless sort(output) == output
  end
end
```

## 検出可能なプロパティパターン

| パターン | 検出キーワード | 生成されるプロパティ |
|----------|---------------|---------------------|
| invariant | sorted, valid, preserved | 不変条件チェック |
| roundtrip | push/pop, encode/decode | 逆操作でデータ復元 |
| idempotent | idempotent, twice | 2回実行で同じ結果 |
| size | length, #, add/sub | サイズの変化をチェック |
| elements | elems, permutation | 要素の保存をチェック |
| empty | empty, nil, #x = 0 | 空判定 |
| ordering | LIFO, FIFO, head/tail | 順序の保存 |

## 制限事項

- Alloy構文の一部のみサポート（sig, pred, assert, fact）
- 複雑な式の変換は手動調整が必要な場合あり
- 時相論理（□, ◇）は未サポート

## 今後の方向性

1. **Alloy Java APIとの連携** — より正確なAST取得
2. **TLA+サポート** — Apalache経由でJSON取得
3. **Ruby gem化** — `gem install alloy2pbt`
4. **AIエージェント連携** — 仕様生成→PBT生成→テスト実行の自動化

## 結論

**実現可能性: 高い** 🎉

形式仕様（Alloy）からProperty-Based Testを自動生成することは技術的に可能。
今回のPOCで以下を実証:

- Alloyの基本構文をパースしてJSON/dict形式に変換できる
- プロパティパターンを自動検出できる
- pbt gemと互換性のあるRubyコードを生成できる

次のステップとしては、本格的なパーサー（Alloy Java API）との連携、
またはTLA+ (Apalache経由) のサポートが考えられる。
