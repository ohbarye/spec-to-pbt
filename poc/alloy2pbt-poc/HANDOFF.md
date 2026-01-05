# AI Agent Handoff Document
# 形式手法からProperty-Based Testを生成するプロジェクト

## メタ情報

- **作成日**: 2026-01-04
- **プロジェクトオーナー**: ohbarye (pbt gem作者)
- **現在のフェーズ**: POC完了、方向性決定済み
- **次のフェーズ**: 本格実装

---

## 1. プロジェクト概要

### 目的
形式手法（Formal Methods）の仕様定義から、Ruby用のProperty-Based Test (PBT) を自動生成するツールを作る。

### 背景・動機
- オーナーはRuby用PBTライブラリ [pbt](https://github.com/ohbarye/pbt) の作者
- AIコーディングエージェント時代に、「仕様→実装→テスト」のループを自動化したい
- 形式手法には詳しくないが、プロダクト品質向上に貢献するなら学びたい

### 成功の定義
1. 形式仕様を書く → PBTコードが自動生成される
2. AIエージェントが仕様を生成し、実装を書き、PBTで検証できる
3. 既存の形式手法の知識資産を活用できる（独自DSLは避ける）

---

## 2. 検討したアプローチと評価

### 2.1 アプローチ一覧

| アプローチ | 説明 | 評価 |
|-----------|------|------|
| **A. 独自DSL** | RubyでDSLを作り、そこからPBT生成 | ❌ 学習コスト高、既存資産使えない |
| **B. YAML/Markdown形式** | 構造化テキストで仕様記述 | ❌ 結局独自形式、同じ問題 |
| **C. TLA+ → PBT** | TLA+仕様をパースしてPBT生成 | ⭕ 産業実績あり、Apalache経由でJSON可能 |
| **D. Alloy → PBT** | Alloy仕様をパースしてPBT生成 | ✅ **採用** Java API充実、学習曲線緩やか |
| **E. 両方サポート** | 共通中間表現を定義し両対応 | 🔄 将来的に検討 |

### 2.2 決定事項

**Alloyから始める理由**:
1. Java APIが充実しており、パーサー実装不要でASTにアクセス可能
2. リレーショナルな記述がPBTと相性が良い（データ構造の不変条件）
3. 学習曲線がTLA+より緩やか（時相論理なし）
4. LLMがAlloyコードを生成できる（AIエージェント連携に有利）

### 2.3 却下したアプローチの理由

**独自DSL/YAML/Markdown**:
- 「また新しいDSL？」疲労
- 学習コストの二重払い（TLA+/Alloyを学んでも、独自形式を学んでも転用不可）
- 理論的基盤・エコシステムがない

**TLA+を最初に選ばなかった理由**:
- 時相論理（□, ◇）がPBTに変換しにくい
- パーサー連携がやや複雑（Apalache必須）
- ただし将来的には対応したい（産業実績が大きい）

---

## 3. 技術調査結果

### 3.1 Alloyの出力オプション

| 形式 | 内容 | 用途 |
|------|------|------|
| XML | インスタンス（反例/満足例） | テストケース生成 |
| Java API | AST直接アクセス | 仕様のパース・変換 |

Alloy Java APIの主要メソッド:
- `CompUtil.parseEverything_fromFile()` - ファイルをパース
- `Module.getAllFacts()` - fact一覧取得
- `Module.getAllFunc()` - 関数/述語一覧取得
- `Module.getAllAssertions()` - assertion一覧取得
- `Module.getAllReachableSigs()` - signature一覧取得

### 3.2 TLA+の出力オプション

Apalache（TLA+ツール）経由でJSONにパース可能:
```bash
apalache-mc parse --output=json spec.tla
```

### 3.3 プロパティパターン

PBTに変換可能な一般的なパターン:

| パターン | 説明 | Alloyでの表現例 |
|----------|------|----------------|
| Invariant | 常に成り立つ性質 | `fact Sorted { ... }` |
| Round-trip | 往復で元に戻る | `encode then decode = identity` |
| Idempotent | 2回実行で同じ結果 | `sort(sort(x)) = sort(x)` |
| Size preservation | サイズ不変 | `#output = #input` |
| Element preservation | 要素保存 | `output.elems = input.elems` |

---

## 4. POC実験結果

### 4.1 作成したもの

```
alloy2pbt-poc/
├── alloy_parser.py       # Alloy簡易パーサー（Python）
├── improved_generator.py # パターン認識付きPBTジェネレーター
├── alloy2pbt.py          # CLIツール
├── sort.als              # サンプル仕様: ソート
├── stack.als             # サンプル仕様: スタック
├── alloy_parser.rb       # Rubyパーサー（未完成）
└── generated/
    ├── sort_pbt.rb       # 生成されたPBT
    └── stack_pbt.rb      # 生成されたPBT
```

### 4.2 動作確認済みの機能

1. **Alloyパース**: sig, pred, assert, factを抽出
2. **パターン検出**: invariant, roundtrip, idempotent等を自動認識
3. **コード生成**: pbt gem互換のRubyコード出力

### 4.3 変換例

**入力 (sort.als)**:
```alloy
pred Sorted[l: List] {
  all i: Int | l.elements[i].value <= l.elements[add[i,1]].value
}
pred LengthPreserved[input, output: List] {
  #input.elements = #output.elements
}
```

**出力 (sort_pbt.rb)**:
```ruby
Pbt.assert do
  Pbt.property(Pbt.array(Pbt.integer)) do |input|
    output = sort(input)
    raise "Sorted failed" unless output.each_cons(2).all? { |a, b| a <= b }
    raise "LengthPreserved failed" unless input.length == output.length
  end
end
```

### 4.4 制限事項

- 簡易パーサーなのでAlloy構文の一部のみサポート
- 複雑な式の変換は手動調整が必要
- 時相論理（□, ◇）は未サポート
- ネストした構造体の型マッピングが不完全

---

## 5. 推奨する次のステップ

### Phase 1: Alloy Java APIとの連携 (推奨)

現在の簡易パーサーをAlloy Java APIに置き換える:

```
Alloy JAR (org.alloytools.alloy.dist.jar)
    ↓ Java API呼び出し
小さなJavaラッパー (alloy-bridge.jar)
    ↓ JSON出力
Ruby/Python コード
    ↓
pbt テストコード
```

実装方法の選択肢:
1. **JRuby使用** - RubyからJava APIを直接呼び出し
2. **サブプロセス** - Javaラッパーを別プロセスで実行、JSON通信
3. **GraalVM** - ポリグロット実行

### Phase 2: Ruby gem化

```ruby
# 使用イメージ
require 'alloy2pbt'

Alloy2Pbt.generate('sort.als', output: 'sort_pbt.rb')

# または
spec = Alloy2Pbt.parse('sort.als')
spec.predicates.each do |pred|
  puts pred.to_pbt
end
```

### Phase 3: TLA+サポート追加

Apalache経由でTLA+もサポート:
```ruby
Alloy2Pbt.generate('spec.tla', format: :tlaplus)
```

### Phase 4: AIエージェント連携

```
人間: 要件を自然言語で記述
  ↓
AI: Alloy仕様を生成
  ↓
alloy2pbt: PBTを生成
  ↓
AI: 実装を生成
  ↓
pbt: テスト実行
  ↓ 失敗
AI: 修正
```

---

## 6. 未解決の課題・検討事項

### 技術的課題

1. **型マッピングの汎用化**
   - Alloyの複雑な型（関係、集合）をどうArbitraryに変換するか
   - カスタム型への対応

2. **式の変換精度**
   - Alloyの量化子（all, some, no）をRubyに正確に変換
   - 関係演算子（join, projection）の扱い

3. **ステートフルPBT**
   - Alloyの状態遷移をpbtのステートフルテストに変換

### 設計判断が必要な点

1. **Alloy Java API連携方法**: JRuby vs サブプロセス vs GraalVM
2. **gem構成**: 単一gem vs alloy-parser + pbt-generator
3. **エラーハンドリング**: 変換できない式をどう扱うか

### 調査が必要な点

1. Alloy 6の時相論理拡張の扱い
2. 既存のAlloy→コード生成ツールとの差別化
3. pbt gemの拡張ポイント（カスタムArbitrary生成）

---

## 7. 参考リソース

### Alloy

- [Alloy公式サイト](https://alloytools.org/)
- [Alloy API Examples](https://alloytools.org/documentation/alloy-api-examples.html)
- [Software Abstractions (書籍)](https://mitpress.mit.edu/books/software-abstractions)
- [Formal Software Design with Alloy 6](https://haslab.github.io/formal-software-design/)

### TLA+

- [TLA+ Home](https://lamport.azurewebsites.net/tla/tla.html)
- [Learn TLA+](https://learntla.com/)
- [Apalache](https://apalache.informal.systems/)

### Property-Based Testing

- [pbt gem](https://github.com/ohbarye/pbt)
- [QuickCheck論文](https://dl.acm.org/doi/10.1145/351240.351266)
- [Choosing Properties for PBT](https://fsharpforfunandprofit.com/posts/property-based-testing-2/)

### 関連研究・ツール

- [Kiro IDE - Spec Driven Development](https://kiro.dev/blog/property-based-testing/)
- [tla-rust](https://github.com/spacejam/tla-rust) - TLA+とQuickCheckの連携

---

## 8. コードの場所

### POC成果物

```
/mnt/user-data/outputs/alloy2pbt-poc/
├── README.md              # プロジェクト説明
├── alloy_parser.py        # Alloyパーサー
├── improved_generator.py  # PBTジェネレーター（パターン認識付き）
├── alloy2pbt.py           # CLIツール
├── pbt_generator.py       # 初期版ジェネレーター
├── sort.als               # サンプル: ソート仕様
├── stack.als              # サンプル: スタック仕様
└── generated/
    ├── sort_pbt.rb        # 生成されたソートPBT
    └── stack_pbt.rb       # 生成されたスタックPBT
```

### 主要ファイルの役割

| ファイル | 役割 | 備考 |
|----------|------|------|
| alloy_parser.py | Alloy構文をパースしてdict/JSONに | 簡易実装、本格版はJava API使用推奨 |
| improved_generator.py | パターン検出 + PBTコード生成 | PropertyPatternクラスが核心 |
| alloy2pbt.py | CLIエントリポイント | `python3 alloy2pbt.py input.als output.rb` |

---

## 9. 思考過程のログ

### 最初の質問への回答

「形式手法の定義からPBTを生成する実現可能性は？」
→ 結論: **高い**。ただしスコープの絞り方が重要。

### 重要な方向転換

1. **独自DSL案 → 却下**
   - 理由: 学習コスト問題、既存資産活用不可
   
2. **YAML/Markdown案 → 却下**
   - 理由: 結局独自形式と同じ問題

3. **TLA+ vs Alloy → Alloyを選択**
   - 理由: Java APIの充実度、学習曲線

### キーインサイト

- AIエージェント時代では「人間の学習コスト」より「AIの読み書きしやすさ」が重要
- でも既存形式手法を使えば両方得られる
- Alloyはリレーショナルで、データ構造の不変条件を書きやすく、PBTと相性が良い

---

## 10. 引き継ぎAIへの注意事項

1. **オーナーの技術レベル**: PBTに精通、形式手法は初心者
2. **優先度**: 実用性 > 理論的完全性
3. **言語選好**: Ruby（pbt gemとの統合のため）
4. **制約**: 独自DSLは避ける、既存形式手法を活用

### やってほしいこと

- Alloy Java APIとの連携を本格実装
- Ruby gem化
- ドキュメント整備

### やらなくていいこと

- 新しいDSLの設計
- 形式手法の理論的な深堀り（実用優先）

---

*このドキュメントは2026-01-04時点の状態を反映しています。*
