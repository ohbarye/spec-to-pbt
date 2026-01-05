# 会話サマリー (TL;DR)

## 一言で言うと

Alloy仕様 → Ruby PBT (pbt gem) の自動生成ツールを作る。POC完了、次は本格実装。

## 決定事項

| 項目 | 決定 | 理由 |
|------|------|------|
| 形式仕様言語 | **Alloy** | Java API充実、学習曲線緩やか |
| 独自DSL | **使わない** | 学習コスト、既存資産問題 |
| 実装言語 | Ruby (+ Java連携) | pbt gemとの統合 |

## POCで実証したこと

✅ Alloy仕様をパースできる  
✅ プロパティパターンを自動検出できる  
✅ pbt互換のRubyコードを生成できる  

## 次やること

1. Alloy Java APIと連携（簡易パーサー→本格版）
2. Ruby gem化
3. TLA+サポート追加（オプション）

## ファイル

```
alloy2pbt-poc/
├── HANDOFF.md          # ← 詳細な引き継ぎドキュメント
├── README.md           # プロジェクト説明
├── alloy_parser.py     # パーサー
├── improved_generator.py # ジェネレーター
├── alloy2pbt.py        # CLI
├── sort.als / stack.als # サンプル仕様
└── generated/          # 生成されたPBT
```

## 使い方

```bash
python3 alloy2pbt.py sort.als output.rb
```
