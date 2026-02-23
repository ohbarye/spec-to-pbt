# Codex引き継ぎ用プロンプト（pbt stateful PBT MVP スパイク）

- 作成日: 2026-02-22（JST）
- 目的: 別の Codex セッションで、現在の stateful PBT スパイク作業を中断点から再開するため

## そのまま貼れるプロンプト

以下を新しい Codex セッションに貼ってください。

```md
`/Users/ohbarye/ghq/github.com/ohbarye/pbt` と `/Users/ohbarye/Desktop/alloy-to-pbt` を参照・編集して、前回の stateful PBT スパイク作業を引き継いでください。

前提:
- バックエンドは `pbt` 固定
- 主眼は `Alloy -> PBT` ではなく、`pbt` に stateful PBT を導入するための MVP 設計・実装
- この repo (`alloy-to-pbt`) は設計メモ / リサーチ / スパイク補助の役割

最初にやってほしいこと:
1. `pbt` リポジトリの現在ブランチ・差分を確認
2. 追加済みの stateful PBT スパイク実装を読み、設計意図を把握
3. `bundle install` が必要なら実行して、追加した spec を実行
4. failing/green を確認した上で次の実装（`Pbt.assert` 経由の e2e と report 改善）に進む

## 現在の状態（前セッションの作業結果）

### pbt リポジトリ

- パス: `/Users/ohbarye/ghq/github.com/ohbarye/pbt`
- ブランチ: `stateful-pbt-mvp-spike`
- 未コミット変更あり

変更ファイル:
- `lib/pbt.rb`
- `lib/pbt/stateful/property.rb`（新規）
- `spec/pbt/stateful/property_spec.rb`（新規）

実装内容（MVPスパイク）:
- `Pbt.stateful(model:, sut:, max_steps:)` を追加
- 既存 runner に載る `Property 互換オブジェクト`（`generate`, `shrink`, `run`）を追加
- stateful sequence を「1つの値」として扱う方式
- shrink は `shorter prefixes` のみ（最小実装）
- `StackModel` + `CorrectStack` / `BuggyStack` の spec を追加

重要な設計意図:
- まずは runner (`Pbt.assert` / `Pbt.check`) 本体を大きく変えない
- `stateful` は新しい Property 実装として差し込む
- DSL ではなく、明示的な object API（duck typing）から始める

### alloy-to-pbt リポジトリ

- パス: `/Users/ohbarye/Desktop/alloy-to-pbt`
- ブランチ: `main`（ローカルで `ahead 1`）
- ユーザー由来/既存変更あり（触る場合は注意）

主な関連 docs:
- `docs/research-spec-to-pbt-options-2026-02-22.md`
  - 改訂済み。`pbt + stateful PBT` 主軸方針に更新済み

## 前セッションで確認できたこと

- `pbt` の runner は `generate / shrink / run` 抽象への依存が中心で、stateful PBT を Property 互換として載せやすい
  - `lib/pbt/check/runner_methods.rb`
  - `lib/pbt/check/runner_iterator.rb`
  - `lib/pbt/check/property.rb`
- スモーク（手動 Ruby スクリプト）で `generate/run/shrink` の基本動作は確認済み
- 構文チェックは OK:
  - `lib/pbt.rb`
  - `lib/pbt/stateful/property.rb`
  - `spec/pbt/stateful/property_spec.rb`

## 未完了・未検証事項（重要）

- `pbt` 側で `bundle exec rspec` は未実行
- 理由: 依存 gem 未インストール（`bundle check` で `rspec`, `rake` 等が不足）
- したがって TDD 的には「テスト追加までは済み、赤/緑の正式確認は未完」

## 次の具体タスク（優先順）

### A. まず検証を通す（最優先）

1. `pbt` で `bundle install`
2. `spec/pbt/stateful/property_spec.rb` を実行
3. 必要なら失敗内容を見て最小修正

### B. `Pbt.assert` 経由の E2E を追加

目的:
- stateful property が既存 runner に乗ることを実証
- failure 時に `counterexample` / `num_shrinks` が出ることを確認

候補:
- `spec/e2e/stateful_e2e_spec.rb`（新規）

### C. 表示と DX 改善（MVP+）

1. command step の `inspect` 改善（`{command: #<Object...>, args: ...}` は見づらい）
2. `Step` 構造体の導入検討
3. failure message に step index や command name を含める

### D. shrink を一段強くする（MVP+）

1. いまは prefix shrink のみ
2. 次に command 引数の shrink を追加（既存 arbitrary の `shrink` を活用）

## 現在の API（スパイク版の想定）

- `Pbt.stateful(model:, sut:, max_steps: 20)` -> `Property 互換オブジェクト`

model 側の期待インターフェース:
- `initial_state`
- `commands(state)` -> `Array<command>`

command 側の期待インターフェース:
- `name`
- `arguments`（Pbt arbitrary）
- `applicable?(state)`
- `next_state(state, args)`
- `run!(sut, args)`
- `verify!(before_state:, after_state:, args:, result:, sut:)`

## 変更ファイル参照（前セッション）

- `/Users/ohbarye/ghq/github.com/ohbarye/pbt/lib/pbt.rb`
- `/Users/ohbarye/ghq/github.com/ohbarye/pbt/lib/pbt/stateful/property.rb`
- `/Users/ohbarye/ghq/github.com/ohbarye/pbt/spec/pbt/stateful/property_spec.rb`
- `/Users/ohbarye/Desktop/alloy-to-pbt/docs/research-spec-to-pbt-options-2026-02-22.md`

## 作業方針の注意

- `pbt` の runner 本体は最初は触りすぎない
- まずは stateful を Property 互換として成立させる
- 依存導入後は TDD で進める（spec -> fail -> implement -> pass）
- `alloy-to-pbt` 側には既存の未コミット変更があるので破壊しない
```

## 補足（人間向け）

この handoff は、次セッションで「状況説明からやり直す」時間を減らすためのものです。
最初の再開ポイントは `pbt` の `stateful-pbt-mvp-spike` ブランチで、`bundle install` 後に `spec/pbt/stateful/property_spec.rb` を通すところからです。
