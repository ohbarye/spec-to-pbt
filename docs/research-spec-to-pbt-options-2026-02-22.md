# 形式手法/仕様ソースから Ruby Property-Based Tests を生成するための手法選定リサーチ

- 調査実施日: 2026-02-22（JST）
- 初版作成日: 2026-02-22
- 改訂日: 2026-02-22（方針変更反映）
- 対象プロジェクト: `spec-to-pbt`（旧: `spec-to-pbt`）
- 文書目的: 研究発表・今後の設計判断に使うための詳細リサーチ記録
- 文書ステータス: 改訂版1（`pbt + stateful PBT` 主軸方針を反映）

## 1. 背景と問題設定

このプロジェクトは、もともと `Alloy -> Ruby PBT` の PoC として開始された。

その後の検討で、プロダクト要件は次のように明確化された。

1. `OpenAPI / JSON Schema` 由来のテスト生成はやらない
2. `Alloy` にはこだわらない（必要なら捨てる）
3. テスト実行バックエンドは `pbt` に固定したい
4. `pbt` 自体に `stateful PBT` を導入することを視野に入れる

この変更により、問いは「どの仕様言語をフロントにするか」から、次の問いへ移る。

1. `pbt に stateful PBT をどう入れるか`
2. その設計・実験場としてこのプロジェクトをどう使うか
3. 形式手法初心者でも進められる実装可能な方法は何か

本改訂版では、初版の比較調査を踏まえつつ、`stateful PBT / Model-Based Testing (MBT)` を主軸に再整理する。

## 2. 先に結論（改訂版サマリ）

### 2.1 現在の推奨方針

このプロジェクトの主軸は、`Alloy 変換器` ではなく次に置くのが最適である。

1. `pbt 向け stateful PBT 基盤の設計・検証`
2. `Ruby の実行可能な状態モデル`（command-based state machine model）を記述する方式
3. 必要に応じて `Alloy / Quint / TLA+` は将来 importer として検討

### 2.2 なぜこの方針が強いか

1. `pbt の owner` が開発者本人であり、ランタイム側の制約を解消できる
2. Ruby コミュニティに説明しやすい（Ruby DSL / Ruby API で完結しやすい）
3. 実務価値が高い（状態遷移バグを直接狙える）
4. 将来の形式仕様 importer を載せる余地を残せる

### 2.3 Alloy の位置づけ（改訂）

Alloy は研究的には妥当であり、継続利用・更新も確認できる。

ただし現在のプロダクト目標に対しては、主軸にする必然性がない。

1. `採用してもよいが必須ではない`
2. `今は捨ててもよい`
3. 後から `importer` として復帰できる設計にするのが最も柔軟

## 3. 現在のプロジェクト（spec-to-pbt / 旧 spec-to-pbt）評価

### 3.1 現状の強み（PoCとして）

ローカルコードベース確認の結果、PoC としての構造は良い。

1. 責務分離が明確
   - `parser`
   - `property_pattern`
   - `type_inferrer`
   - `pattern_code_generator`
   - `generator`
2. 生成パイプラインが理解しやすく、拡張しやすい
3. README で制約を明示している
4. テストが整備されている（確認時点で `80 examples, 0 failures`）

### 3.2 現状の限界（PoCから実用へ進む際の壁）

1. `regex ベース parser` の限界
   - Alloy の広い構文を安定に扱うのが難しい
2. `字面ベース pattern detection`
   - predicate 名や本文の正規表現に依存し、意味レベルの保証が弱い
3. `型推論の活用が薄い`
   - 実装上、生成器が `Pbt.array(Pbt.integer)` に固定される箇所がある
4. `module 名 = operation 名` の単純化
   - 実用では、仕様要素と Ruby API の対応付けが必要
5. Alloy Analyzer 未連携
   - Alloy の bounded analysis の強みをまだ使っていない

### 3.3 改訂後の位置づけ（重要）

この repo の既存資産は、今後 `Alloy 専用ツール` として育てるより、`stateful PBT / spec importer 実験のスパイク環境` として再利用する方が価値が高い。

具体的には次の役割が適切である。

1. `pbt stateful API` の設計スパイク
2. モデルベーステストのサンプル実装置き場
3. 将来 importer（Alloy/Quint 等）の実験場

## 4. 選定基準（改訂版）

現在の意思決定後は、手法比較の軸も変わる。重視すべき点は次である。

1. `pbt への導入しやすさ`
   - ランタイム実装しやすいか
   - shrinking/replay/reporting と整合するか
2. `Ruby 開発者の記述しやすさ`
   - Ruby DSL / Ruby API で自然に書けるか
3. `状態モデル表現力`
   - precondition / transition / postcondition / invariant を表現できるか
4. `段階導入しやすさ`
   - MVP を作ってから強化できるか
5. `将来の形式仕様接続性`
   - Alloy/TLA+/Quint 等から取り込める余地があるか

## 5. 候補手法の比較（改訂後の位置づけ）

## 5.1 Ruby 状態機械 DSL（Model-Based Testing / Stateful PBT）【主軸採用】

### 概要

Ruby で実行可能なモデルを記述し、`pbt` でコマンド列を生成・実行・縮小する方式。

想定するモデル要素:

1. `initial_state`
2. `commands`
3. `precondition`
4. `next_state`
5. `postcondition`
6. `invariant`（任意）

### 強み

1. Ruby コミュニティへの導入障壁が低い
2. `pbt` ランタイムと密に設計できる
3. stateful バグを直接検出しやすい
4. 後から外部仕様 importer を接続しやすい（IR にしやすい）

### 弱み

1. DSL/Runner/Shrinker 設計の難度がある
2. 失敗時レポートの UX を詰める必要がある
3. precondition と shrinking の相互作用が難所

### 結論

`このプロジェクトと pbt の両方にとって最も相応しい第一主軸`。

## 5.2 RBS（Ruby 型シグネチャ）【補助候補】

### 概要

RBS を、stateful PBT の主軸ではなく `引数 generator 補助` として使う案。

### 強み

1. Ruby との親和性が高い
2. コマンド引数の generator 導出に使える
3. 将来の API 設計にも活かせる

### 弱み

1. 振る舞い仕様は表現できない
2. stateful PBT の中核機能にはならない

### 結論

`採用すると便利だが必須ではない`。MVP 後の補強として有望。

## 5.3 Alloy（関係モデル + bounded analysis）【任意 / 将来 importer】

### 概要

関係モデル記述と bounded analysis に強い形式仕様言語。

### 強み

1. 研究的な正当性が高い
2. 構造制約・関係制約に強い
3. TestEra/AUnit/COMBA など関連研究がある

### 弱み

1. Ruby コミュニティにとって学習コストが高い
2. Ruby 実装への写像が難しい
3. 現時点の主目的（pbt stateful PBT 導入）に対する直接価値が低い

### 結論

`今は非主軸。必要時に importer として再評価` が妥当。

## 5.4 Quint / TLA+（形式仕様・モデル検査）【将来 importer 候補】

### 概要

状態遷移系の仕様記述・モデル検査ツールチェーン。counterexample trace を得やすい。

### 強み

1. 行動仕様（遷移）に強い
2. trace をテストケースとして活用しやすい
3. stateful PBT/MBT の理論的背景と相性が良い

### 弱み

1. Ruby 導入の説明コストが高い
2. 外部ツール依存が増える

### 結論

`stateful PBT 基盤が固まった後の上級拡張` として有望。

## 5.5 OpenAPI / JSON Schema（比較対象・今回は非採用）

### 概要

初版では強い候補だったが、今回のプロダクト方針では対象外とする。

### 非採用理由（今回）

1. 対象を API スキーマ生成に広げるとスコープがぶれる
2. 今回の本命は `pbt の stateful PBT 導入` である
3. バックエンドを `pbt` に固定し、ランタイム価値に集中したい

### 研究上の価値

他言語の成功事例（Schemathesis など）は、`仕様 -> PBT` が実務で成立することの補強として引き続き参照価値がある。

## 6. 他言語・類似事例・研究からの示唆（改訂版）

## 6.1 QuickCheck 系（最重要）

### 代表例

1. QuickCheck（Haskell）
2. QuviQ QuickCheck（Erlang/Elixir/C/C++）
3. FsCheck（.NET/F#）

### 本プロジェクトへの示唆

1. stateful PBT は実務で成立している
2. コア価値は `ランナー + shrinking + レポート`
3. 仕様言語より先に `state machine testing API` を整備するのが現実的

## 6.2 モデルベーステスト（MBT）の産業実績

### 代表例

1. Microsoft Spec Explorer
2. QuviQ QuickCheck state machine testing

### 本プロジェクトへの示唆

1. 単発 property より状態遷移列のテストが高い価値を持つ
2. 導入可否は DSL と UX（失敗時レポート）に強く依存する

## 6.3 Alloy 系研究（研究トラックとしての妥当性）

### 代表例

1. TestEra
2. AUnit / AUnit Analyzer
3. COMBA（ASE 2025）

### 本プロジェクトへの示唆

1. Alloy ベースのテスト生成は研究として筋が通る
2. ただし、今のプロダクト目標に対しては優先順位を下げてよい
3. 後から importer として戻す余地は残すべき

## 6.4 Schema-based PBT（比較対象・非採用だが参考）

### 代表例

1. Schemathesis
2. hypothesis-jsonschema

### 本プロジェクトへの示唆

1. `仕様 -> PBT` の価値提案自体は強い
2. 今回はその方向ではなく、`stateful PBT 基盤` に集中する

## 7. 推奨戦略（このプロジェクトに対して）

## 7.1 プロダクト方針の再定義

### 旧見立て

- `Alloy -> Ruby PBT`

### 改訂後の主軸

- `pbt 向け stateful PBT 基盤の設計・検証`

### 将来拡張（任意）

- `Alloy / Quint / TLA+` からの importer

## 7.2 この repo と `pbt` の責務分割（重要）

### `pbt` に入れるもの（本体）

1. stateful runner
2. command sequence generator
3. shrinking（シーケンス + 引数）
4. failure report / replay
5. RSpec 連携

### この repo に置くもの（スパイク / 研究）

1. stateful API の設計実験
2. サンプルモデル（stack, queue, cache 等）
3. importer 実験（Alloy/Quint など）
4. 評価レポート・比較資料

## 7.3 `pbt` stateful PBT の MVP 要件

### 必須（MVP）

1. コマンド列生成
2. precondition に基づくコマンド選択
3. `next_state` によるモデル状態更新
4. SUT 実行 + `postcondition` 検証
5. 失敗時の seed / command sequence 出力
6. 最低限の縮小（列削減 + 引数縮小）

### 後回し（MVP後）

1. 並行性テスト
2. 線形化検証
3. 高度な shrink 最適化
4. 複雑な symbolic precondition

## 7.4 推奨 API 形状（たたき台）

最初は DSL よりも、明示的なオブジェクト API を推奨する。理由は実装・検証がしやすいため。

想定インターフェース例（概念）:

1. `model.initial_state`
2. `model.commands(state)`
3. 各 command の責務
   - `gen(state)`
   - `pre?(state, args)`
   - `run!(sut, args)`
   - `next_state(state, args, result)`
   - `post?(before, after, args, result)`

その後に Ruby DSL を被せる。

## 8. 推奨ロードマップ（`pbt` 導入中心）

## 8.1 Phase 0: 位置づけ整理（短期）

1. README の主張を `Alloy PoC` から `stateful PBT スパイク` 寄りに調整
2. この doc を方針根拠としてリンク
3. `Alloy は任意` であることを明示

## 8.2 Phase 1: この repo で設計スパイク（最優先）

1. `Stack` / `Queue` のモデルを Ruby で記述
2. command API の最小形を決める
3. 失敗レポート形式（表示内容）を決める
4. 縮小戦略（最低限）を決める

成果物:

1. API 提案
2. 実行トレース例
3. 失敗時の最小再現例

## 8.3 Phase 2: `pbt` に MVP 実装

1. stateful runner
2. sequence shrink（単純版）
3. replay support
4. RSpec 統合

## 8.4 Phase 3: 実用性強化

1. command weights
2. coverage/統計出力（どの command を何回叩いたか）
3. invariant hooks
4. setup/teardown hooks

## 8.5 Phase 4: 形式仕様 importer の再評価（任意）

1. Alloy importer を残すか再判断
2. Quint/TLA+ trace importer の可能性検証
3. 外部仕様から state machine IR へのマッピング設計

## 9. 初心者（形式手法未経験）向けの学習順（改訂）

形式手法初心者が、実装を進めながら理解を深める順序として次を推奨する。

1. `PBT の基礎`
   - generator / shrinking / seed / replay
2. `Stateful PBT / MBT`
   - state, command, pre/post, invariant
3. `QuickCheck 系の state machine testing`
   - QuviQ / FsCheck の設計を読む
4. `RBS`（必要なら generator 補助として）
5. `Alloy`（関係モデルに戻りたくなったら）
6. `Quint/TLA+`（trace importer をやりたくなったら）

## 10. 研究発表向けの主張案（改訂版）

本プロジェクトは、次の主張で発表しやすい。

1. `Ruby における stateful PBT 基盤の実装設計`
   - ランタイム設計・縮小・再現性・UX を中心に議論できる
2. `Lightweight Formal Methods としての実行可能モデル`
   - Ruby DSL による pre/post/invariant を形式的記述として扱う
3. `形式仕様 importer への拡張可能性`
   - Alloy/Quint/TLA+ を将来接続できる構造を先に作る
4. `tool-builder の立場からの実践知`
   - `pbt` owner だからこそ可能な設計判断（バックエンド固定、機能統合）

## 11. リスクと対策（改訂版）

## 11.1 リスク: `pbt` 本体への組み込みが先に重くなる

stateful PBT はランタイム機能として複雑で、最初から本体実装に入ると反復が遅くなる。

対策:

1. この repo で API/失敗UX/縮小を先にスパイクする
2. `pbt` 側は MVP のみ移植する
3. フィードバックを得てから DSL 化する

## 11.2 リスク: shrinking の難度が高い

stateful では、列削減で precondition が壊れやすい。

対策:

1. 最初は `列削減` を主にする
2. 無効列の扱い（discard / skip / 再生成）を仕様化する
3. shrunk sequence の再実行を必須にする

## 11.3 リスク: Alloy 資産が宙に浮く

既存の `spec-to-pbt`（現 `spec-to-pbt`）資産が使われなくなる可能性がある。

対策:

1. この repo を stateful PBT スパイク環境として再定義する
2. Alloy 実装は `importer 実験` として保持する
3. README と docs で位置づけを明確化する

## 11.4 リスク: 形式手法として弱く見える

外部形式仕様言語を前面に出さないため、研究発表で「単なるテストフレームワーク拡張」に見える可能性がある。

対策:

1. `MBT / Lightweight Formal Methods` の文脈で位置づける
2. pre/post/invariant を形式的仕様として扱う
3. 将来 importer（Alloy/Quint/TLA+）の接続点を設計として示す

## 12. 今回のリサーチで確認した主な資料（外部）

以下は、今回の調査で参照した主要資料。研究発表で引用候補として再利用しやすいものを優先して列挙する。

### 12.1 Alloy / Alloy系研究（継続性確認 + 研究文脈）

1. Alloy 公式サイト: https://alloytools.org/
2. Alloy About: https://alloytools.org/about
3. Alloy Analyzer docs: https://alloy.readthedocs.io/en/latest/tooling/analyzer.html
4. AlloyTools GitHub Releases（Alloy 6.2.0 等）: https://github.com/AlloyTools/org.alloytools.alloy/releases
5. TestEra（ASE Journal 2004, 要約ページ）: https://experts.illinois.edu/en/publications/testera-specification-based-testing-of-java-programs-using-sat/
6. TestEra 論文 PDF（MIT SDG）: https://groups.csail.mit.edu/sdg/pubs/2004/TestEra-ASE-J.pdf
7. AUnit 関連（SPIN 2014, 要約ページ）: https://experts.illinois.edu/en/publications/towards-a-test-automation-framework-for-alloy/
8. AUnit Analyzer site: https://sites.google.com/view/aunitanalyzer
9. COMBA（ASE 2025）: https://conf.researchr.org/details/ase-2025/ase-2025-papers/238/Automated-Combinatorial-Test-Generation-for-Alloy

### 12.2 PBT / MBT / Stateful Testing（主軸）

1. QuickCheck（ICFP 2000）情報: https://research.chalmers.se/en/publication/237427
2. QuviQ QuickCheck docs: https://quviq.com/documentation/eqc/overview-summary.html
3. QuviQ 製品ページ: https://www.quviq.com/products/
4. Microsoft Spec Explorer（MSR）: https://www.microsoft.com/en-us/research/publication/model-based-testing-of-object-oriented-reactive-systems-with-spec-explorer/
5. Spec Explorer 解説（MSDN archive）: https://learn.microsoft.com/en-us/archive/msdn-magazine/2013/december/model-based-testing-an-introduction-to-model-based-testing-and-spec-explorer
6. Korat（ISSTA 2002 要約）: https://experts.illinois.edu/en/publications/korat-automated-testing-based-on-java-predicates/
7. FsCheck Stateful Testing docs: https://fscheck.github.io/FsCheck/StatefulTestingNew.html

### 12.3 TLA+ / Quint（将来 importer 候補）

1. TLA+ Foundation: https://foundation.tlapl.us/
2. TLA+ Community Wiki: https://docs.tlapl.us/community
3. Quint GitHub: https://github.com/informalsystems/quint
4. Quint docs（概要）: https://quint-lang.org/docs/quint
5. Quint docs（何ができるか）: https://quint-lang.org/docs/what-does-quint-do
6. Apalache: https://apalache-mc.org/

### 12.4 Ruby / PBT 実装資産（主軸）

1. RBS: https://github.com/ruby/rbs
2. Steep: https://github.com/soutaro/steep
3. pbt（Ruby）: https://github.com/ohbarye/pbt
4. pbt RubyDoc: https://www.rubydoc.info/gems/pbt
5. prop_check（比較対象）: https://github.com/Qqwy/ruby-prop_check
6. prop_check（RubyGems）: https://rubygems.org/gems/prop_check

### 12.5 Schema-based PBT（今回は非採用だが比較参考）

1. Schemathesis: https://schemathesis.io/
2. Schemathesis docs: https://schemathesis.readthedocs.io/en/stable/
3. Schemathesis GitHub: https://github.com/schemathesis/schemathesis
4. hypothesis-jsonschema: https://github.com/python-jsonschema/hypothesis-jsonschema
5. rswag: https://github.com/rswag/rswag
6. json-schema gem: https://rubygems.org/gems/json-schema
7. openapi_parser gem: https://rubygems.org/gems/openapi_parser

## 13. この文書の使い方（今後）

本資料は、以下の用途を想定する。

1. 研究発表の背景・関連研究スライドの素材
2. `pbt` stateful PBT 導入の設計判断記録
3. この repo の役割再定義（スパイク / 実験場）の根拠
4. `README` や将来の設計 docs の改訂根拠

次に行うべき実務タスクとしては、`Stack/Queue` を題材にした `stateful PBT API` のスパイク実装をこの repo で作り、`pbt` へ移植する MVP の境界を定めることが有効である。
