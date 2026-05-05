# **形式手法（Alloy、Quint、TLA+等）に基づくテスト生成およびプロパティベースドテスト（PBT）統合の理論と応用**

## **1\. 序論および研究の背景**

近年のソフトウェア工学およびシステム開発において、品質保証と検証のプロセスはますます複雑化の度合いを深めている。従来の手動によるブラックボックステストやホワイトボックステストのケース作成は、人的リソースの観点からコストが極めて高いだけでなく、保守フェーズにおける継続的なアップデートに対しても限界を露呈している1。特に、分散システム、ブロックチェーンプロトコル、および複雑な関係性を持つデータ構造を扱うソフトウェアにおいては、非決定的な状態遷移や、エッジケースに潜む並行処理のバグを網羅的に検出することが事実上不可能となっている4。

この課題に対処するための有力なアプローチとして、システムの実行可能な仕様からテストデータを自動的かつ機械的に生成し、振る舞いを網羅的に検証する技術が進化を遂げてきた。その中核となるのが「プロパティベースドテスト（Property-Based Testing: PBT）」と「モデルベースドテスト（Model-Based Testing: MBT）」である5。PBTは、個別の入出力例を記述する代わりに、システムが満たすべき普遍的な特性（プロパティ）を定義し、ランダムまたは体系的に生成した大量の入力データを用いて検証する手法である9。一方のMBTは、形式仕様言語（Formal Specification Languages）で記述された数学的かつ厳密なモデルから、システムが取り得る有効な状態遷移トレースを導出し、それをテスト実行のオラクル（判定基準）として用いる手法である5。

本報告書は、Alloy、TLA+、およびQuintといった形式手法で記述された仕様から、PBTフレームワーク（QuickCheck、Hypothesisなど）やMBTのテストケースを機械的に生成する学術研究、ツール群、および産業界における先行事例を網羅的かつ詳細に分析するものである。形式手法はこれまで、定理証明やモデル検査による「静的検証（Static Verification）」の領域で主に用いられ、数学的バックグラウンドを持つ一部の専門家に利用が限られていた12。しかし、仕様から具体的なテストケースを生成し、実装の「動的検証（Dynamic Testing）」に適用するハイブリッドなアプローチの台頭、さらに大規模言語モデル（LLM）を用いたテストハーネスの自動生成技術の進展により、形式仕様と実装コード（Java、Rust、Pythonなど）の間に存在する「意味的ギャップ」を解消する試みが急速に実用化されている3。

本報告書では、これら形式仕様とテスト生成技術の交差点に位置する理論的背景から出発し、Alloyを用いた制約ベースのテスト生成、TLA+およびQuintを用いた分散システムのモデルベースドテスト、そして最新のAI駆動型テスト生成パラダイムに至るまで、そのメカニズムと技術的課題を包括的に詳述する。

## **2\. プロパティベースドテスト（PBT）の理論的基盤と形式手法との親和性**

形式仕様からのテスト生成を深く理解するためには、検証手法の基礎概念であるプロパティベースドテスト（PBT）の特性、および形式手法の背後にある「スモールスコープ仮説（Small Scope Hypothesis）」の理論的背景を整理する必要がある。

### **2.1 PBTのメカニズムとその限界**

プロパティベースドテスト（PBT）は、2000年のICFP（International Conference on Functional Programming）においてKoen ClaessenとJohn Hughesによって発表されたHaskell向けテストツール「QuickCheck」に端を発する4。PBTの基本理念は、プログラマが特定の入出力ペア（例えば add(2, 3\) \== 5）を単体テストとして記述するのではなく、関数が常に満たすべき数学的特性（例えば reverse(reverse(xs)) \== xs）を仕様として記述することにある9。QuickCheckは、型クラスとモナドを巧妙に利用してテストデータを自動的にランダム生成し、プロパティが偽となる反例（Counter-example）を発見する9。さらに、反例が見つかった場合には、テストフレームワークが入力データを段階的に小さくしていく「縮小（Shrinking）」機能を提供し、デバッグを容易にする最小の失敗ケースを特定する10。

QuickCheckの成功以降、PBTの概念はPythonのHypothesis、ErlangのPropEr、Javaのjqwik、Rustのproptestなど、多数のプログラミング言語のエコシステムに移植され、広く普及している19。PBTは仕様そのものを機械で検査可能なドキュメントとして機能させる利点を持つが、重大な技術的課題も抱えている。それが「事前条件が希薄な入力（Sparse Preconditions）」の生成問題である8。

ランダム生成ジェネレータは、数値や文字列といった単純なデータ型の生成には優れている。しかし、関数の入力が「重複のない要素で構成されるソート済みリスト」や「循環を持たない赤黒木」といった、構文的構造から逸脱した厳密な意味的・構造的制約（セマンティックインバリアント）を要求する場合、ランダムに生成された入力の大部分は事前条件を満たさずに破棄されてしまう8。この問題を解決するために開発者が複雑なカスタムジェネレータを手動で記述することは、多大な労力を要し、テストコード自体のバグを誘発する原因となる22。

### **2.2 スモールスコープ仮説による解法**

このPBTの限界を克服するために導入されたのが、形式手法における「スモールスコープ仮説（Small Scope Hypothesis）」である。この仮説は、「ソフトウェアのバグの大半は、非常に小さなサイズの入力や状態空間（例えば、要素数が3程度のリストや、ごく短い遷移ステップ数）で再現可能である」という経験則に基づく23。

この仮説を応用することで、PBTのジェネレータを盲目的なランダム生成から、制約充足ソルバ（SATソルバやSMTソルバ）を用いた有界徹底的（Bounded-exhaustive）な生成へと転換させることが可能になる25。つまり、Alloy Analyzerなどのモデルファインダを用いて、小さな有界スコープ内で指定された複雑な事前条件（インバリアント）を完全に満たす有効なインスタンスのみを漏れなく生成し、それをPBTのテストデータとして実装に供給するアーキテクチャが構築されるのである22。

以下の表は、従来のランダム生成ベースのPBTと、形式仕様（制約ベース）を組み込んだPBTの特性を比較したものである。

| 比較項目 | 従来のPBT（純粋なQuickCheck等） | 形式仕様ベースのPBT（Alloy/Kodkod連携等） |
| :---- | :---- | :---- |
| **テストデータ生成方式** | 型に基づく擬似ランダム生成および縮小（Shrinking） | 制約ソルバ（SAT/SMT）による有界内の徹底的（Exhaustive）探索 |
| **事前条件の厳しい入力** | 非常に非効率（大部分が破棄されるか手動ジェネレータが必要） | 非常に効率的（論理式を満たすインスタンスのみを直接生成） |
| **カバレッジの保証** | 確率論的（実行回数に依存） | 指定されたスコープ内での完全な網羅性（同型を除外可能） |
| **適用範囲** | 単純なデータ変換、文字列処理、数学関数 | 複雑なグラフ構造、再帰的データ型、プロトコル状態機械 |

## **3\. Alloyを用いた関係論理仕様からのテスト自動生成**

Alloyは、MITのDaniel Jacksonらによって開発された、関係論理（Relational Logic）と一階述語論理に基づく宣言型の形式仕様言語である4。ソフトウェアの構造的な特性や複雑なデータ構造をモデリングするのに非常に優れており、背後にあるKodkod（SATベースの制約ソルバ）を用いてモデルのインスタンスを探索・列挙する強力な能力を持つ13。この特性から、Alloyはテスト自動生成の分野で最も広く応用されている形式手法の先駆者となっている。

### **3.1 TestEra：有界徹底テストフレームワークの詳細**

Alloyを用いたテスト生成の代表的かつ古典的な先行研究として、Javaプログラム向けの自動テスト生成フレームワーク「TestEra」が存在する25。TestEraは、関数の事前条件と事後条件をAlloyの仕様として定義し、Javaコードの実行可能なJUnitテストスイートへと昇華させる一連のパイプラインを確立した33。

TestEraによるテスト生成プロセスは、以下の段階を経て実行される。

1. **仕様とアノテーションの記述**: 開発者は検証対象のJavaコード内に @TestEra というアノテーションを用いて仕様を直接記述する。このアノテーションには5つの重要な要素が含まれる25。isEnabled（テスト生成の対象とするか）、invariant（全インスタンスが満たすべきクラスの不変条件）、preCondition（メソッド実行前に入力が満たすべき制約）、postCondition（実行後の状態と戻り値 \\result に対する制約であり、' 演算子を用いて事前状態と事後状態の関係を示す）、そして runCommand（Alloy Analyzerに対する探索範囲・スコープの指定）である25。
2. **Alloyモデルへの自動変換（Translation）**: TestEraは、アノテーションが付与されたJavaソースコードを解析し、Alloyの形式モデルへと自動変換する。JavaのクラスはAlloyのシグネチャ（sig）に、フィールドはそのシグネチャ内の関係（Relation）にマッピングされる25。また、メモリ上のオブジェクトの状態遷移を表現するために、ヒープを状態シグネチャ（State）を用いたエッジラベル付きグラフとして階層的に表現し、メソッドの事前条件と事後条件をAlloyの述語（pred）へと変換する25。
3. **SATソルバによる抽象的入力の列挙**: 変換されたAlloyの仕様に対し、Alloy AnalyzerのSATベースのバックエンドが適用される。ここでTestEraは、事前条件と不変条件を充足するすべての「非同型（Non-isomorphic）」な抽象状態を、指定されたスコープ内で徹底的（Bounded-exhaustive）に列挙する25。同型なインスタンス（ポインタのアドレスが異なるだけで論理的構造が同一のもの）を自動的に排除することで、テストケースの爆発を防ぎつつ無駄のないテストスイートを生成する。
4. **具体化（Concretization）とJUnit実行**: 生成された抽象的なAlloyインスタンスは、そのままではJava環境で実行できないため、TestEraはこれを実行可能なJavaオブジェクトへと「具体化」する。具体化エンジンは、デフォルトコンストラクタを用いてJavaオブジェクトを生成し、Alloyのモデル上で示された関係に従ってフィールドへの参照を構築（結線）する25。こうして構築されたオブジェクト（プレステート）を入力として、対象メソッドが実行される33。
5. **抽象化（Abstraction）と事後条件の検証**: メソッド実行後、TestEraのランタイムは変更されたJavaオブジェクトの事後状態（ポストステート）と戻り値をトラバースし、再度Alloyのモデル空間（関係データ）へと「抽象化」する25。この抽象化の過程では、巡回リストのような無限ループを引き起こす可能性のある不正な出力に対しても、トラバース済みのノードを記録する仕組みにより堅牢に対処する33。最後に、抽象化された事後状態が、アノテーションで定義された事後条件の述語（Alloyの論理式）を満たしているかを判定し、テストの合否を決定する25。

### **3.2 AUnitと宣言型モデルのミューテーションテスト**

TestEraが「形式仕様を用いて命令型言語（Java）の実装をテストする」アプローチであるのに対し、Alloyモデル自身の正しさを検証するためのフレームワークとして「AUnit」が提案されている4。AUnitは、命令型言語において広く普及しているユニットテストの概念を、宣言型パラダイムであるAlloyに初めて持ち込んだ画期的な研究である4。

AUnitにおいて、テストケース ![][image1] は ![][image2] というペアで厳密に定義される。ここで ![][image3] は特定の関係の割り当てを示す「評価（Valuation）」または状態であり、![][image4] は対象となる「コマンド（Command）」である4。通常のAlloy解析が論理式からインスタンスを探索する「制約解決問題」であるのに対し、AUnitのテスト実行は、与えられた評価 ![][image3] が特定のコマンド ![][image4] の制約を満たすかを確認する「制約検査問題（Constraint Checking）」として定式化されている4。

AUnitフレームワークは、Alloyモデルにおける二つの主要なフォールト（欠陥）である「過少制約（Underconstraint：無効な状態を許容してしまう）」と「過剰制約（Overconstraint：有効な状態を排除してしまう）」を検出するために、以下の3つの自動テスト生成技術（AGen）を提供する4。

* **AGenBB（ブラックボックステスト生成）**: 有界スコープ内のすべての非同型インスタンスを列挙し、テストスイートを生成する。この手法はTestEraの思想をモデル自身のテストに逆輸入したものであり、カバレッジに基づく手法よりも高いミューテーションスコアを達成する傾向にあるが、テストスイートが肥大化しやすいというトレードオフが存在する4。
* **AGenCov（ホワイトボックス/カバレッジ指向テスト生成）**: モデル内の論理式に対するカバレッジ基準を定義し、それを満たす最小の非同型テストスイートを生成する技術である。命令型言語のステートメントカバレッジと同様に、論理式が空集合、シングルトン、複数要素に評価されるかを確認し、さらに量化子（Quantified formulas）に対しては、ドメインが空であることによる「空虚な真（Vacuous truth）」と、要素が存在する場合の「非空虚な真（Non-vacuous truth）」の両方を網羅する制約解決問題として定式化される4。
* **AGenMu（ミューテーションベーステスト生成）**: 推移的閉包（^）を反射的推移的閉包（\*）に置換する、あるいは関係演算子を変更するといった意図的なフォールト（ミュータント）をAlloyモデルに注入する。そして、オリジナルモデルとミュータントの評価結果を異ならせる（Killする）ことに特化したテストを生成する4。

特にAGenMuにおいて特筆すべきは、SATソルバを用いることで、構文的には異なるが論理的には等価である「等価ミュータント（Equivalent Mutant）」を自動検知し、計算の無駄を排除できる点である4。このフレームワークは大学の大学院課程における課題モデルの検証実験において、手動の採点では見逃されていた複雑な複合論理式のバグを100%検出するなど、高い有効性が実証されている4。

### **3.3 産業界および学術界におけるAlloyの応用事例**

Alloyの高度なテスト生成能力と関係論理によるモデリングは、多岐にわたる産業用システムの分析に応用されてきた12。

代表的な応用事例として、以下の領域でのテスト・検証が挙げられる。

1. **分散型インフラとメモリモデル**: Java Memory Modelにおけるプログラム変換の妥当性検証や、Flash Filesystemのフォーマルモデリングを通じたテストデータ生成に活用されている13。
2. **Mondex電子マネーシステム**: 形式手法の古典的かつ非常に厳密な産業ケーススタディとして知られるMondexにおいて、仕様の記述と詳細化（Refinement）の妥当性チェックにAlloyが使用された13。
3. **JDOLLYとSafeRefactor**: JavaやErlangのプログラムに対する自動リファクタリングエンジンが正しく動作するかをテストするために、Alloy Analyzerを用いてリファクタリング対象の抽象構文木（プログラム自体）を徹底的に生成し、その動作を検証するアーキテクチャが構築されている35。
4. **SQLクエリとデータベースのテスト生成**: クエリに依存したテストデータベース生成において、データベースのスキーマ制約とクエリの前提条件をAlloyモデルとしてエンコードし、効果的なテスト用テーブルデータを生成する研究が行われている13。

これらの事例は、Alloyが単なる「静的な設計のスケッチツール」に留まらず、動的テストデータの源泉（オラクルおよびジェネレータ）として産業要件に十分応え得る表現力を持っていることを証明している。

## **4\. プロパティベースドテスト（PBT）ライブラリとの高度な統合研究**

TestEraのような独自フレームワークとは別に、既存の実用的なPBTライブラリ（HaskellのQuickCheck、PythonのHypothesisなど）のジェネレータ部分を、Alloyやその他の形式仕様の制約ソルバで置き換える（あるいは補完する）アプローチが研究されている。

### **4.1 QuickCheckと定理証明・SATソルバの結合**

Haskellのエコシステムにおいては、QuickCheckのランダム生成の限界を補完するため、定理証明器Isabelle/HOLとSATソルバを組み合わせた「Nitpick」という反例生成器が開発されている26。Nitpickは、AlloyのバックエンドであるKodkodを内部的に利用している27。

QuickCheckは帰納的データ型に対するランダムテストには非常に優れているものの、無制限の量化子（Unbounded quantification）を含む実行不可能な論理式をテストすることはできない27。これに対しNitpickは、高階論理（HOL）の式を関係論理に変換し、無限のデータ型を有限の部分集合によって近似した上で、KodkodによるSAT解決を行う。これにより、QuickCheckが探索不可能な空間から反例（テスト失敗ケース）を見つけ出すことができる27。また、ハードウェア設計言語などの分野においては、Alloyによるモデル化に加えてHaskellのQuickCheckを併用するテスト手法が普及しつつあり、BlueCheckのような派生ツールを通じて、ランダムなメソッド呼び出しシーケンスを生成し、デッドロックの検出やトレースの最小化を行う試みも存在している37。

### **4.2 Brown UniversityのHypothesis統合ツール**

より実用的なプログラミング教育および検証環境の構築に向け、Brown Universityの研究グループは、PBTフレームワークであるPythonの「Hypothesis」とAlloy（Pardinusソルバ）を組み合わせた革新的なテスト評価アーキテクチャを発表した28。

この研究は、テスト対象の複雑なプロパティを単一のテストケースとして処理するのではなく、複数の独立した（または関連する）「サブプロパティ」へと意味的に分解することから始まる39。例えば、トポロジカルソートの正当性を確認する Toposortacle の検証において、「出力要素の順序が入力の半順序関係に違反していないか」というサブプロパティをAlloyの関係演算子（推移的閉包 ^ や直積 \-\>）を用いて厳密に定義する28。

このツールは、以下の2つのコンポーネントのみで動作する28。

1. 問題領域と各サブプロパティを記述したAlloy仕様。
2. ソルバの領域（関係の集合）と具体的なテストケース（テスト文字列など）の間のマッピングを行うRacketモジュール。

このアーキテクチャの最大の利点は、SATベースの入力ジェネレータ（Alloy）と、値ベースのジェネレータ（Hypothesis）の性能を直接比較し、両者の長所をハイブリッドに活用できる点にある39。Hypothesisは一般的なケースを高速に生成し、AlloyはPBTジェネレータが決して到達できないエッジケース（特定の有向非巡回グラフなど）を確実かつ数学的に導き出す。これにより、学生が書いたPBTのプロパティのどこに論理的欠陥があるのかを、単なる「パス/フェイル」ではなく、意味的なサブプロパティレベルでピンポイントに特定することが可能となった39。

### **4.3 Whiley言語におけるWyQC**

同様の思想は、仕様記述とプログラミングを融合させた研究言語「Whiley」のテストツールであるWyQC（QuickCheck for Whiley）にも見られる22。WyQCは、不完全な仕様しか記述されていない関数や、副作用のスコープ（フレーミング問題）が曖昧なメソッドに対しても、Whiley中間言語（WyIL）から自動的に型ジェネレータを構築し、動的テストを生成する22。これは、完全な静的検証（Static Verification）に到達する前の段階として、自動テスト生成がいかに実用的な橋渡しとなるかを示す好例である22。

## **5\. TLA+を用いた分散システムのテストおよびPBTとの比較**

Alloyが構造的なモデリングや関係代数に優れている一方で、システムの状態遷移と時間的論理（LivenessやSafety）を記述することに強みを持つ形式手法が「TLA+（Temporal Logic of Actions）」である40。Leslie Lamportによって開発されたTLA+は、分散プロトコル、データベースのレプリケーション機構、並行アルゴリズムの設計仕様において業界標準の地位を確立している40。

### **5.1 TLA+とプロパティベースドテストの機能的相違点**

TLA+とPBTは「特性（プロパティ）を用いてシステムを検証する」という点で共通の哲学を持っているが、そのスコープと表現力には大きな差異が存在する21。古典的なパズルである「Die Hard 3の水差し問題（Jug problem）」を例にとると、HypothesisのようなPBTツールでも、状態機械を用いたテストジェネレータを書くことで「4ガロンの水を正確に測り取る」という解を縮小（Shrinking）プロセスを通じて特定できる20。

しかし、開発現場における分散システムの監視やREST APIのテストにこれらの手法をどう適用するかという観点では、両者のアプローチは分岐する21。TLA+は、高レベルな数学的疑似コード（PlusCal）とZermelo-Fränkel集合論を用いてシステム全体を俯瞰し、非決定性や並行性（マルチスレッド・分散ノードのインターリーブ）を完璧にモデリングすることができる21。一方でPBTツール（HypothesisやElixirのPropCheck等）は、並行処理プロパティのテスト機能（Stateful testingやParallel testing）を追加しようとする試みはあるものの、本質的に実装言語の実行コンテキストに強く依存するため、プロトコル設計レベルでの状態空間の爆発や非決定性を扱うには限界がある20。

### **5.2 Amazon AWSとMongoDBにおける産業界の成功事例**

この「TLA+によるモデリング」と「実装に対するPBTまたはMBT」の組み合わせは、産業界で非常に強力な結果を生み出している。

Amazon AWSでは、S3などのミッションクリティカルなサービスの設計検証において、TLA+による仕様記述とPBTフレームワークによる動的テストを連携させている6。非決定的な性質により再現が極めて困難な間欠的（Intermittent）な並行処理バグ（例えばGoogle LevelDBで発見された複雑なマルチステップバグ等）に対し、TLA+を用いて期待されるシステムプロパティに違反するイベントシーケンスを体系的に特定する6。その後、PBTのジェネレータを用いて実環境でそのイベントシーケンスを模倣・実行することで、抽象的なモデルで発見されたバグの芽を実際の実装テストで確実に捉えるというアプローチを採用している6。

MongoDBにおいても、「アジャイル開発と厳密な形式仕様の結合」という哲学の下、TLA+を活用している46。彼らは実装（C++やJava）の進化と仕様を同期させ、TLA+モデルからテストケースを自動生成し、さらにトレース検査（Trace-checking）によって実際の実装が出力した実行履歴が仕様で許容された範囲に収まっているかを確認している46。これにより、分散トランザクションシステムの未知の不整合を実装の早期段階で発見することに成功している。

### **5.3 Mocket：TLA+空間の探索によるJava実装へのフォールト注入**

学術的なフレームワークとして、分散プロトコル（Raft、XRaft、ZooKeeperのZabなど）のTLA+仕様から、実際のJava実装に対するテストを自動生成する「Mocket」がEuroSys 2023で発表された46。

Mocketは、TLA+のモデル検査器を利用してプロトコルの状態空間グラフを走査し、極端なエッジケースを含む「実行可能なテストケース」を生成する47。このツールの技術的な革新性は、TLA+の仕様上の変数（抽象状態）と、Java実装内の実際のクラス変数・メソッド変数をマッピングし、実装側に自動的に「シャドウフィールド（Shadow Field）」と「シャドウ変数」を追加するコード計装（Instrumentation）を施す点にある47。

テスト実行中、実装されたシステムは生成されたTLA+のトレースパスを決定論的に辿るように強制される。各アクションの実行直後、シャドウ変数の値とTLA+仕様の事後状態が一致するかを検証することで、同期ズレやバグを検出する46。さらにMocketは、メッセージの重複（Message duplication）やプロセスの再起動（Process restart）といった、通常のPBTでは生成が極めて困難なネットワークレベルのフォルトアクションを意図的に導入したテストシナリオを生成できるため、ZabやRaftの実装から複数の未知のバグを発見するという成果を挙げている47。

## **6\. Apalacheによる記号的モデル検査とテストトレース生成**

従来のTLA+の検証は、TLCモデル検査器による「明示的状態探索（Explicit-state Model Checking）」に依存していた。TLCは非常に堅牢だが、探索対象のパラメータ（ノード数やメッセージ数）が大きくなると状態空間爆発（State space explosion）を避けられないという弱点があった40。この限界を打ち破るべく、ウィーン工科大学およびInformal Systemsによって開発されたのが「Apalache」である49。

### **6.1 SMTソルバ（Z3）を用いた記号的モデル検査**

Apalacheは、TLA+仕様をSMT（Satisfiability Modulo Theories）ソルバであるZ3が解釈可能な数式に変換して検証を行う「記号的モデル検査器（Symbolic Model Checker）」である49。Apalacheは個別の状態を一つずつ列挙するのではなく、状態の集合全体を論理式として表現し、不変条件の違反や到達可能性（Reachability）を代数的に探索する。これにより、TLCでは扱いきれない大規模なパラメータを持つシステムに対しても、反例（Counterexample）やテストトレースを高速に抽出することが可能となった11。

### **6.2 Tendermintにおけるモデルベースドテスト（MBT）ワークフロー**

Informal Systemsは、ブロックチェーンのコンセンサスエンジンであるTendermintプロトコルやCosmosエコシステムのRust実装の品質保証において、Apalacheを中核に据えたMBT（Verification-Driven Development: VDD）を実践している11。

このワークフローにおけるテスト生成と検証は、以下のアーキテクチャで行われる15。

1. **仕様の記述**: 英語の自然言語仕様の曖昧さを排除するため、純粋なTLA+でプロトコルを定義する11。
2. **トレース生成**: Apalacheを用いて、特定のカバレッジ基準を満たす、あるいは特定のアクションシーケンスを通過する「興味深いトレース（Interesting Trace）」を探索・抽出する15。
3. **具体化（Action Concretization）と実行**: 抽出されたトレース（抽象的な状態とアクションのシーケンス）を、テストハーネスに入力する。テストハーネスは、トレースのアクションを実際のAPI呼び出しやネットワークメッセージの送信といった実装レイヤーの命令に変換し、テスト対象システム（SUT）に対して実行する15。
4. **トレースバリデーション**: システムを実行して得られた実際の動作トレースを収集し、それがTLA+仕様の許容する状態遷移グラフの中に含まれているかを事後に検査する「Trace validation」も並行して行われる15。

このアプローチは手書きの統合テストよりも網羅性が高く、システムエンジニアから非常に好意的に受け入れられている11。

### **6.3 SMTを用いた対話的記号実行テスト（Interactive Symbolic Testing）**

MBTの最前線の研究として、2025年12月から2026年にかけてIgor Konnovらによって発表された「Interactive Symbolic Testing」という新たなアプローチが存在する15。従来のMBTでは、事前にApalache等で生成された「固定のトレース」をテストドライバを介して実装に流し込むだけであった。しかし、実際の分散システムでは、ネットワークの遅延や、実装が仕様の範囲内で自由に選択し得る非決定的な動作が存在するため、固定トレースとの完全な同期を取ることが極めて難しい15。

この課題を解決するため、KonnovらはApalacheに新たな「JSON-RPCサーバーAPI」を実装した15。これにより、外部ツールやスクリプトがテスト実行中にApalache内のSMTソルバとリアルタイムで対話することが可能になった。

この対話的テストプロセスでは、テストハーネスが対象システム（SUT）から出力された実際のステップごとの状態をJSON-RPC経由でApalacheに送信する15。ApalacheはバックエンドのZ3ソルバを用いて、「SUTから報告された現在の状態遷移が、TLA+仕様で定義された許容される遷移の集合（Next action）に数学的に属しているか」を動的に評価する15。この手法は、複数のオープンソースTFTP（Trivial File Transfer Protocol）実装に対する適合性テスト（Conformance testing）に適用され、プロトコル仕様に対する無害だが予期せぬ逸脱（Adversarial behaviorに対するテスト等）を、動的かつ完全に自動化された形で検出することに成功した15。

## **7\. Quint：開発者体験を重視した仕様記述と言語エコシステム**

TLA+はその強力な表現力と実績にもかかわらず、ソフトウェアエンジニアの間に広く普及しているとは言い難い。その最大の理由は、数学やLaTeXに由来する特有の記号表現（![][image5] 等）や、インデントベースでパースが難しい構文を持つため、一般的なプログラマにとって学習曲線が急峻であることにある52。この問題を解決し、形式仕様をアプリケーション開発の日常的なツールチェーンに組み込むことを目指して開発されたのが「Quint」である50。

### **7.1 Quintの特徴とエコシステム**

Quintは、TLA+の堅牢な理論的基盤（アクションの時相論理）を完全に維持しつつ、現代の型付きプログラミング言語（TypeScriptやRust等）に近い構文を採用している50。TLA+にはネイティブの型システムが存在しないが、Quintは静的解析、表現力豊かな型推論、および状態更新の一貫性を保証する効果システム（Effect System）を備えている50。

また、Quintのエコシステムは現代のソフトウェア開発ツールに極めて近い。VS Code等のエディタで「定義へ移動」やリアルタイムのエラーハイライトを実現するLSP（Language Server Protocol）サポート、対話的に仕様を検証できるREPL、そして実行可能なシミュレータ（quint run）を標準装備している50。これらの開発者体験（DX）の向上により、ブロックチェーンプロトコルやP2Pネットワークのエンジニアから熱狂的な支持を集めている50。

### **7.2 QuintによるテストジェネレーションとITFトレース**

Quintを用いたテスト生成のワークフローは、非常に直感的である。開発者はコマンドラインから quint run（シミュレータ）を実行することで、仕様のモデルに基づいたランダムな状態遷移の探索とトレースの抽出を行うことができる5。内部的には、Quintの仕様はTLA+にトランスパイルされ、必要に応じてApalacheを用いた高度な記号的モデル検査（quint verify）にシームレスに引き継がれる51。

モデルベースドテストを実行する際、開発者は \--mbt および \--out-itf オプションを使用してシミュレータを実行する（例: quint run \--mbt \--n-traces 100 \--out-itf traces.json bank.qnt）。これにより、状態遷移の記録がJSONベースのITF（Interchain Testing Framework）フォーマットで出力される5。このフォーマットは、テストドライバが解釈しやすいよう標準化されており、TLA+特有の数学的出力よりもパースが容易である。

### **7.3 Quint Connect：Rust向けMBTフレームワークと技術的課題**

生成されたITF形式のトレースを、実際の実装コード（特にRustなどのシステムプログラミング言語）の自動テストに接続するための実用的ライブラリとして「Quint Connect」が存在する5。Quint Connectは、プロシージャルマクロ（quint-connect-macros）を提供し、トレースデータの読み込み、ディスパッチ、および実装関数へのアサーションを半自動化する55。

しかし、どんなに優れたツールを用いても、抽象的な仕様の世界（モデル）と具体的な実装の世界（コード）を結びつける作業（Glue Codeの作成）には、回避不可能な固有の技術的課題が立ちはだかる5。

1. **型のマッピングとシリアライゼーション（Type Mapping）**:
   仕様上で定義されたデータ構造と、Rust実装の構造体は完全には一致しない。開発者は、JSONトレースのデータ型をRustの型空間へ適切にデシリアライズするために、手動での型マッピング定義や serde アノテーションを記述する必要がある。
2. **非決定性の解決とメタデータの解釈（nondet\_picks）**: 形式仕様において「任意の有効なユーザーアドレスを選ぶ」といった非決定的な選択（Non-deterministic choice）が行われた場合、実装のテストドライバは、その特定のトレースステップで仕様が「具体的に何を選んだか」を知る必要がある。Quintの \--mbt オプションは、この課題を解決するためにトレース内に mbt::actionTaken（実行されたアクション名）や nondet\_picks というメタデータを付与する。テストドライバはこれをパースし、実装の関数を呼び出す際の正確なパラメータとして適用する5。
3. **アクションから実装関数へのバインディング**:
   トレースの actionTaken によって識別される仕様上のアクションを、実装内の対応する関数コール、または複数のモジュールに跨る一連の手続きへとマッピングするテストディスパッチャを構築する必要がある。
4. **初期状態（Init）の特別処理とアサーション**:
   仕様の "init" アクションはトレースの最初の状態でのみ発生するため、メインの遷移ループに先立ってシステムをブートストラップする特別なハンドリングが求められる。また、実装内の状態（残高やトランザクション履歴など）がトレース内の状態と完全に一致することをアサーションするだけでなく、仕様が「このアクションではエラーが発生すべき」と規定した場合、実装が正しくパニックまたはエラー型を返すことを厳密に検証するロジックが必要となる。

Quint Connectはこれらの課題に対し、堅牢なフレームワークとマクロを提供することで、開発者が「仕様と実装の意味的結合」に集中できる環境を構築している。実際、Matter LabsにおけるChonkyBFTのような巨大なコンセンサスアルゴリズムの検証においても、Quintの非決定性を利用して単体テストをプロパティベースドテストへ拡張し、Apalacheの制約解決（Z3に送られる数百MBの制約）がタイムアウトするようなエッジケースにおいても、ランダムシミュレータを用いたテストフォールバックを利用してシステムの安全性を確認している51。

## **8\. 大規模言語モデル（LLM）と形式仕様の融合によるテスト生成の新パラダイム**

近年、形式手法とテスト生成のパイプラインにおいて最も革新的な進展を見せているのが、GPT-4oやClaudeといった大規模言語モデル（LLM）の統合である。AI技術は、これまでの「モデルベースドテストの最後の壁」とされてきた技術的障壁を打破しつつある。

### **8.1 Vibe Codingの限界とExecutable Specificationの価値**

AIアシスタントを用いたコード生成（いわゆるVibe Coding）は、ゼロからの機能作成やボイラープレートの記述には優れているものの、複雑な既存システムの振る舞い（暗黙の契約関係、インバリアント、非機能要件）を維持しながらエッジケースを処理することには非常に脆い56。自然言語による曖昧な要件定義をプロンプトとして与えられたLLMは、実装のコーナーケースでハルシネーションを起こし、一貫性のないコードやテストを出力してしまう2。

この問題を解決する鍵が、TLA+やQuintで記述された「実行可能な仕様（Executable Specification）」をAIのプロンプトとして活用することである56。AIに対して曖昧な指示を出すのではなく、数学的に厳密で、システムの状態遷移とエッジケースが完全に定義された形式仕様を「契約（Contract）」として読み込ませることで、LLMはそれを正確に解釈し、論理的な不整合のない信頼性の高いテストハーネスや実装コードを生成できるエンジニアリングパートナーへと変貌する56。

### **8.2 テストドライバ（グルーコード）のLLMによる自動生成**

前章の「Quint Connectの課題」で述べたように、形式仕様からテストトレースを機械生成できたとしても、そのトレースを実装コードの型や関数にマッピングする「テストドライバ（グルーコード）」の作成には、多大な手作業と専門知識が必要となる14。

この課題に対し、Igor KonnovのTFTP（Trivial File Transfer Protocol）のケーススタディでは、Claudeを用いて劇的な効率化が実証された15。Konnovの手法では、Claudeに対して「TLA+の仕様コード」と「テスト対象となるC言語の実装コード」の両方をコンテキストとして入力し、Apalacheから出力されたJSONトレースをパースしてCの実装を駆動するテストハーネスの生成を依頼した15。その結果、型のシリアライズ/デシリアライズやアクションのディスパッチを行うグルーコードの大部分がLLMによって正確に自動生成されたのである15。

このように、LLMは「仕様からテストを導出する推論エンジン」としてだけでなく、「仕様ツール（Apalache等）が出力したデータと実装言語（C、Rust等）の構文的なギャップを埋めるトランスレータ」として驚異的な威力を発揮している14。Informal Systemsが提供する「Quint LLM Kit」などのAIエージェントも、Quint仕様の反復的な改善や、モデルベースドテスト用コードの生成を強力にサポートしている5。

また、RAG（Retrieval-Augmented Generation）技術を組み合わせ、過去に検証済みのTLA+の証明データベースから類似の証明パターンを検索し、LLMにプロンプトとして与えることで、未検証のモデルに対する証明生成やテストアサーションの構築を支援する研究も進行している57。

以下の表は、形式手法とPBT/MBTの連携に向けた主要ツール群のアプローチを総括したものである。

| ツール / フレームワーク | ベース形式仕様 | バックエンド / ソルバ | テスト生成アプローチおよび特徴 | 主な適用領域・連携技術 |
| :---- | :---- | :---- | :---- | :---- |
| **TestEra** 25 | Alloy (Java用) | Alloy Analyzer (SAT) | 有界徹底的状態探索とオブジェクトの具体化（JUnit統合） | 複雑なデータ構造の単体テスト、構造検証 |
| **AUnit** 4 | Alloy | Kodkod (SAT) | AGenBB/Cov/Muを用いた宣言型モデル自身のテストと等価ミュータント検知 | 仕様のデバッグ、ミューテーションテスト |
| **Nitpick / WyQC** 22 | Isabelle/HOL, Whiley | Kodkod (SAT) 等 | 無限データ型の有限近似と、QuickCheckがカバーできない範囲のテスト生成 | Haskell/Whileyの関数型テスト、定理証明の補助 |
| **Brown Univ PBT** 28 | Alloy | Pardinus (SAT) | 複雑なプロパティを分解し、Hypothesis（値ベース）とSATを組み合わせた生成 | PBTのジェネレータ補完、プログラミング教育 |
| **Mocket** 47 | TLA+ | TLC Model Checker | 状態空間走査に基づくトレース生成と、実装へのシャドウ変数計装・フォルト注入 | Raft, ZooKeeperなどの分散プロトコル |
| **Apalache MBT** 15 | TLA+ / Quint | Z3 (SMT) | 記号的モデル検査による高速なトレース抽出とJSON-RPC経由のInteractive Symbolic Testing | Tendermint, Cosmosエコシステム, TFTPプロトコル |
| **Quint Connect** 50 | Quint | Apalache / Simulator | シミュレータによる非決定性を含むトレース生成と、Rustマクロを用いた型マッピング | 分散ステートマシン、スマートコントラクト |
| **LLM \+ MBT** 14 | Quint / TLA+ | Claude / GPT-4o 等 | 形式仕様を厳密なプロンプトとした、実装連携用テストハーネス（グルーコード）の自動生成 | 既存プロトコルのテスト自動化、ハルシネーションの排除 |

## **9\. 結論および将来展望**

形式手法（Alloy、Quint、TLA+等）で記述された実行可能な仕様から、機械的にテスト（特にプロパティベースドテストおよびモデルベースドテスト）を生成する研究は、単なる学術的関心を超え、複雑化する現代ソフトウェアシステムにおける品質保証の不可欠なパラダイムとして確立しつつある。

本報告書の分析が示すように、この技術領域は明確な進化の軌跡を描いている。第一段階として、HaskellのQuickCheckに代表される純粋なランダムPBTが普及したが、厳しい事前条件を持つ入力空間の探索において「Sparse Preconditions問題」という限界に直面した8。第二段階として、Alloyのような関係論理とSATソルバ（Kodkod等）の制約解決能力を統合することで、この限界が突破された。TestEra、AUnit、あるいはNitpickといったツール群は、スモールスコープ仮説に基づき、複雑なインバリアントを完全に満たす有効なエッジケースを徹底的に生成し、PBTのジェネレータとしての形式手法の強力さを証明した4。

第三段階として、焦点は構造的モデリングから、分散システムや並行処理の時相論理モデリング（TLA+）へと移行した。AWSやMongoDBの産業事例、そしてMocketのようなツールは、非決定的な状態遷移の中で引き起こされる間欠的なバグを特定するために、TLA+のモデル検査空間から生成されたイベントシーケンスを実装に対するテストとして適用するアプローチの有効性を示した6。さらにApalacheの登場により、Z3を用いた記号的モデル検査が実用化され、状態空間爆発を抑えながら巨大なプロトコルのテストトレースを高速に抽出する基盤が整備された15。

そして現在、この分野は第四段階である「開発者体験の向上と動的結合」のフェーズにある。Quintは、プログラマに馴染み深い構文と型システムを提供することで形式仕様の学習曲線を劇的に下げ、Quint Connect等を通じてRustなどの実装コードへのテストバインディングをマクロレベルで自動化した50。同時に、Igor KonnovらによるJSON-RPCを利用したInteractive Symbolic Testingは、固定トレースを流し込む従来のMBTの限界を超え、実装側の非決定的な出力とSMTソルバをリアルタイムに対話させることで、より柔軟かつ厳密な適合性テストを実現した15。

今後の将来展望として、最大のブレイクスルーはAI（LLM）との完全な統合にあると結論付けられる。モデルと実装を結びつける「グルーコード」や型マッピングの作成は長らくMBTのボトルネックであったが、形式仕様を「曖昧さのない完全なプロンプト（Contract）」としてLLMに入力することで、AIはハルシネーションを起こすことなく、テストハーネスやアサーションコードを自動生成する能力を獲得しつつある14。

総じて、形式仕様に基づくプロパティテストおよびモデルベースドテストの生成技術は、仕様の妥当性確認（Validation）と実装の検証（Verification）をシームレスに結合するものである。ソルバ技術の進化、Quintのような近代的な言語エコシステム、そしてLLMの推論能力が融合することで、要件定義から形式仕様の記述、そして実装へのテスト自動適用に至るまでの一貫したソフトウェア工学のパイプラインが、今後数年で産業界の標準的プラクティスとなっていくことが強く示唆される。

#### **Works cited**

1. Generating Test Cases from Formal Specifications \- Trepo, accessed April 4, 2026, [https://trepo.tuni.fi/bitstream/handle/123456789/25415/Helinko.pdf?sequence=4\&isAllowed=y](https://trepo.tuni.fi/bitstream/handle/123456789/25415/Helinko.pdf?sequence=4&isAllowed=y)
2. Automated Test Generation From Software Requirements Using an LLM \- Diva-portal.org, accessed April 4, 2026, [https://www.diva-portal.org/smash/get/diva2:1986692/FULLTEXT01.pdf](https://www.diva-portal.org/smash/get/diva2:1986692/FULLTEXT01.pdf)
3. Automated Test Generation And Verified Software\* \- Computer Science Laboratory, accessed April 4, 2026, [https://www.csl.sri.com/\~rushby/papers/vstte07.pdf](https://www.csl.sri.com/~rushby/papers/vstte07.pdf)
4. Automated Test Generation and Mutation Testing for Alloy \- Kaiyuan Wang, accessed April 4, 2026, [https://kaiyuanw.github.io/papers/paper4-icst17.pdf](https://kaiyuanw.github.io/papers/paper4-icst17.pdf)
5. Model-based Testing \- Quint, accessed April 4, 2026, [https://quint-lang.org/docs/model-based-testing](https://quint-lang.org/docs/model-based-testing)
6. How Property Based Testing helps \- Richard Seidl, accessed April 4, 2026, [https://www.richard-seidl.com/en/blog/propertybased-testing](https://www.richard-seidl.com/en/blog/propertybased-testing)
7. \[2406.10053\] Property-Based Testing by Elaborating Proof Outlines \- arXiv, accessed April 4, 2026, [https://arxiv.org/abs/2406.10053](https://arxiv.org/abs/2406.10053)
8. (PDF) Coverage guided, property based testing \- ResearchGate, accessed April 4, 2026, [https://www.researchgate.net/publication/336453666\_Coverage\_guided\_property\_based\_testing](https://www.researchgate.net/publication/336453666_Coverage_guided_property_based_testing)
9. CSE230 Wi14 \- QuickCheck: Type-directed Property Testing, accessed April 4, 2026, [https://cseweb.ucsd.edu/classes/wi14/cse230-a/lectures/lec-quickcheck.html](https://cseweb.ucsd.edu/classes/wi14/cse230-a/lectures/lec-quickcheck.html)
10. Property-based Testing With QuickCheck \- Typeable, accessed April 4, 2026, [https://typeable.io/blog/2021-08-09-pbt.html](https://typeable.io/blog/2021-08-09-pbt.html)
11. Model-based testing with TLA and Apalache, accessed April 4, 2026, [https://conf.tlapl.us/2020/09-Kuprianov\_and\_Konnov-Model-based\_testing\_with\_TLA\_+\_and\_Apalache.pdf](https://conf.tlapl.us/2020/09-Kuprianov_and_Konnov-Model-based_testing_with_TLA_+_and_Apalache.pdf)
12. Formal methods \- Wikipedia, accessed April 4, 2026, [https://en.wikipedia.org/wiki/Formal\_methods](https://en.wikipedia.org/wiki/Formal_methods)
13. Applications and extensions of Alloy: past, present and future ..., accessed April 4, 2026, [https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/applications-and-extensions-of-alloy-past-present-and-future/FC9B69F562740A19560376ACE76BAC2C](https://www.cambridge.org/core/journals/mathematical-structures-in-computer-science/article/applications-and-extensions-of-alloy-past-present-and-future/FC9B69F562740A19560376ACE76BAC2C)
14. Reliable Software in the LLM Era \- Quint, accessed April 4, 2026, [https://quint-lang.org/posts/llm\_era](https://quint-lang.org/posts/llm_era)
15. Interactive Symbolic Testing of TFTP with TLA+ and Apalache | Protocols Made Fun, accessed April 4, 2026, [https://protocols-made-fun.com/tlaplus/2025/12/15/tftp-symbolic-testing.html](https://protocols-made-fun.com/tlaplus/2025/12/15/tftp-symbolic-testing.html)
16. QuickCheck: A Lightweight Tool for Random Testing of Haskell Programs \- Department of Computer Science, accessed April 4, 2026, [https://www.cs.tufts.edu/\~nr/cs257/archive/john-hughes/quick.pdf](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf)
17. Haskell Programming With Tests, and Some Alloy \- Homepages of UvA/FNWI staff, accessed April 4, 2026, [https://staff.fnwi.uva.nl/d.j.n.vaneijck2/courses/10/pdfs/Week6.pdf](https://staff.fnwi.uva.nl/d.j.n.vaneijck2/courses/10/pdfs/Week6.pdf)
18. QuickCheck: An Automatic Testing Tool for Haskell, accessed April 4, 2026, [https://www.cse.chalmers.se/\~rjmh/QuickCheck/manual.html](https://www.cse.chalmers.se/~rjmh/QuickCheck/manual.html)
19. Testing — list of Rust libraries/crates // Lib.rs, accessed April 4, 2026, [https://lib.rs/development-tools/testing?sort=popular.atom](https://lib.rs/development-tools/testing?sort=popular.atom)
20. The sad state of property-based testing libraries \- Stevan's notes, accessed April 4, 2026, [https://stevana.github.io/the\_sad\_state\_of\_property-based\_testing\_libraries.html](https://stevana.github.io/the_sad_state_of_property-based_testing_libraries.html)
21. Differences between TLA+ Specification and Property Based Testing \- Google Groups, accessed April 4, 2026, [https://groups.google.com/g/tlaplus/c/1AMoUwbEiJ4/m/-6f2J1\_8AwAJ](https://groups.google.com/g/tlaplus/c/1AMoUwbEiJ4/m/-6f2J1_8AwAJ)
22. Finding Bugs with Specification-Based Testing is Easy\! \- arXiv, accessed April 4, 2026, [https://arxiv.org/pdf/2103.00032](https://arxiv.org/pdf/2103.00032)
23. 5: Introduction to Modeling with Alloy \- HackMD, accessed April 4, 2026, [https://cs.wellesley.edu/\~cs340/notes/05.html](https://cs.wellesley.edu/~cs340/notes/05.html)
24. arXiv:2302.02703v2 \[cs.DC\] 16 Oct 2023, accessed April 4, 2026, [https://arxiv.org/pdf/2302.02703](https://arxiv.org/pdf/2302.02703)
25. TestEra: A Tool for Testing Java Programs Using ... \- Lingming Zhang, accessed April 4, 2026, [https://lingming.cs.illinois.edu/publications/ase2011.pdf](https://lingming.cs.illinois.edu/publications/ase2011.pdf)
26. Automatic Proof and Disproof in Isabelle/HOL | Semantic Scholar, accessed April 4, 2026, [https://pdfs.semanticscholar.org/1575/1a87bf3cc204d3ed35325db4d55cd9c7b169.pdf](https://pdfs.semanticscholar.org/1575/1a87bf3cc204d3ed35325db4d55cd9c7b169.pdf)
27. Nitpick: A Counterexample Generator for Higher-Order Logic Based on a Relational Model Finder \- LMU München, accessed April 4, 2026, [https://www.tcs.ifi.lmu.de/staff/jasmin-blanchette/itp2010-nitpick.pdf](https://www.tcs.ifi.lmu.de/staff/jasmin-blanchette/itp2010-nitpick.pdf)
28. Automated, Targeted Testing of Property-Based Testing Predicates \- Brown Computer Science, accessed April 4, 2026, [https://cs.brown.edu/\~tbn/publications/nrsdwk-pj21-pbt.pdf](https://cs.brown.edu/~tbn/publications/nrsdwk-pj21-pbt.pdf)
29. Alloy Analyzer, accessed April 4, 2026, [https://alloytools.org/](https://alloytools.org/)
30. Alloy\*: A General-Purpose Higher-Order Relational Constraint Solver \- ResearchGate, accessed April 4, 2026, [https://www.researchgate.net/publication/308839029\_Alloy\_A\_General-Purpose\_Higher-Order\_Relational\_Constraint\_Solver](https://www.researchgate.net/publication/308839029_Alloy_A_General-Purpose_Higher-Order_Relational_Constraint_Solver)
31. Test generation from bounded algebraic specifications using alloy \- SciSpace, accessed April 4, 2026, [https://scispace.com/pdf/test-generation-from-bounded-algebraic-specifications-using-3tfkysxova.pdf](https://scispace.com/pdf/test-generation-from-bounded-algebraic-specifications-using-3tfkysxova.pdf)
32. TestEra: Specification-based Testing of Java Programs Using SAT, accessed April 4, 2026, [https://users.ece.utexas.edu/\~khurshid/papers/TestEra-ASE-J.pdf](https://users.ece.utexas.edu/~khurshid/papers/TestEra-ASE-J.pdf)
33. TestEra: A Novel Framework for Automated Testing of Java Programs, accessed April 4, 2026, [https://ase-conferences.org/olbib/2001kurshid.pdf](https://ase-conferences.org/olbib/2001kurshid.pdf)
34. TestEra: A tool for testing Java programs using alloy specifications \- IEEE Xplore, accessed April 4, 2026, [https://ieeexplore.ieee.org/document/6100137/](https://ieeexplore.ieee.org/document/6100137/)
35. Automated Behavioral Testing of Refactoring Engines \- Microsoft, accessed April 4, 2026, [https://www.microsoft.com/en-us/research/wp-content/uploads/2020/08/tse12.pdf](https://www.microsoft.com/en-us/research/wp-content/uploads/2020/08/tse12.pdf)
36. Random testing in Isabelle/HOL \- TUM, accessed April 4, 2026, [https://www21.in.tum.de/\~berghofe/papers/SEFM04.pdf](https://www21.in.tum.de/~berghofe/papers/SEFM04.pdf)
37. Modular SMT-Based Verification of Rule-Based Hardware Designs Andrew C. Wright \- DSpace@MIT, accessed April 4, 2026, [https://dspace.mit.edu/bitstream/handle/1721.1/139491/Wright-acwright-PhD-EECS-2021-thesis.pdf?sequence=1\&isAllowed=y](https://dspace.mit.edu/bitstream/handle/1721.1/139491/Wright-acwright-PhD-EECS-2021-thesis.pdf?sequence=1&isAllowed=y)
38. PyMTL Tutorial Schedule \- Computer Systems Laboratory, accessed April 4, 2026, [https://www.csl.cornell.edu/pymtl2019/pymtl-tutorial-ex02-isca2019.pdf](https://www.csl.cornell.edu/pymtl2019/pymtl-tutorial-ex02-isca2019.pdf)
39. Automated, Targeted Testing of Property-Based Testing Predicates, accessed April 4, 2026, [https://blog.brownplt.org/2021/11/24/pbt-revisited.html](https://blog.brownplt.org/2021/11/24/pbt-revisited.html)
40. The TLA Toolbox \- Leslie Lamport, accessed April 4, 2026, [https://lamport.azurewebsites.net/pubs/toolbox.pdf](https://lamport.azurewebsites.net/pubs/toolbox.pdf)
41. Specifying Systems \- Leslie Lamport, accessed April 4, 2026, [https://lamport.azurewebsites.net/tla/book-21-07-04.pdf](https://lamport.azurewebsites.net/tla/book-21-07-04.pdf)
42. How to go about property testing a consensus protocol using PropCheck \- Elixir Forum, accessed April 4, 2026, [https://elixirforum.com/t/how-to-go-about-property-testing-a-consensus-protocol-using-propcheck/28466](https://elixirforum.com/t/how-to-go-about-property-testing-a-consensus-protocol-using-propcheck/28466)
43. TLA \+ in Practice and Theory Part 1: The Principles of TLA \+, accessed April 4, 2026, [https://pron.github.io/posts/tlaplus\_part1](https://pron.github.io/posts/tlaplus_part1)
44. Differences between TLA+ Specification and Property Based Testing, accessed April 4, 2026, [https://discuss.tlapl.us/msg01866.html](https://discuss.tlapl.us/msg01866.html)
45. Property-Based Testing Against a Model of a Web Application | Concerning Quality, accessed April 4, 2026, [https://concerningquality.com/model-based-testing/](https://concerningquality.com/model-based-testing/)
46. Conformance Checking At MongoDB: Testing That Our Code Matches Our TLA+ Specs, accessed April 4, 2026, [https://www.mongodb.com/company/blog/engineering/conformance-checking-at-mongodb-testing-our-code-matches-our-tla-specs](https://www.mongodb.com/company/blog/engineering/conformance-checking-at-mongodb-testing-our-code-matches-our-tla-specs)
47. Model Checking Guided Testing for Distributed Systems \- Metadata, accessed April 4, 2026, [http://muratbuffalo.blogspot.com/2023/08/model-checking-guided-testing-for.html](http://muratbuffalo.blogspot.com/2023/08/model-checking-guided-testing-for.html)
48. accessed January 1, 1970, [http://muratbuffalo.blogspot.com/2023/08/model-based-testing-guided-testing-for.html](http://muratbuffalo.blogspot.com/2023/08/model-based-testing-guided-testing-for.html)
49. Symbolic Verification of TLA+ Specifications with Applications to Distributed Algorithms \- reposiTUm, accessed April 4, 2026, [https://repositum.tuwien.at/bitstream/20.500.12708/193082/1/Tran%20Thanh%20Hai%20-%202023%20-%20Symbolic%20verification%20of%20TLA%20specifications%20with...pdf](https://repositum.tuwien.at/bitstream/20.500.12708/193082/1/Tran%20Thanh%20Hai%20-%202023%20-%20Symbolic%20verification%20of%20TLA%20specifications%20with...pdf)
50. informalsystems/quint: An executable specification language with delightful tooling based on the temporal logic of actions (TLA) \- GitHub, accessed April 4, 2026, [https://github.com/informalsystems/quint](https://github.com/informalsystems/quint)
51. Specification and model checking of BFT consensus by Matter Labs | Protocols Made Fun, accessed April 4, 2026, [https://protocols-made-fun.com/consensus/matterlabs/quint/specification/modelchecking/2024/07/29/chonkybft.html](https://protocols-made-fun.com/consensus/matterlabs/quint/specification/modelchecking/2024/07/29/chonkybft.html)
52. Frequently Asked Questions \- Quint, accessed April 4, 2026, [https://quint-lang.org/docs/faq](https://quint-lang.org/docs/faq)
53. Quint: A specification language based on the temporal logic of actions (TLA) | Hacker News, accessed April 4, 2026, [https://news.ycombinator.com/item?id=38694278](https://news.ycombinator.com/item?id=38694278)
54. Summary of Quint, accessed April 4, 2026, [https://quint-lang.org/docs/lang](https://quint-lang.org/docs/lang)
55. Testing — list of Rust libraries/crates // Lib.rs, accessed April 4, 2026, [https://lib.rs/development-tools/testing](https://lib.rs/development-tools/testing)
56. Beyond Vibe Coding: Using TLA+ and Executable Specifications with Claude, accessed April 4, 2026, [https://shahbhat.medium.com/beyond-vibe-coding-using-tla-and-executable-specifications-with-claude-51df2a9460ff](https://shahbhat.medium.com/beyond-vibe-coding-using-tla-and-executable-specifications-with-claude-51df2a9460ff)
57. Towards Language Model Guided "TLA"⁺ Proof Automation \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2512.09758v1](https://arxiv.org/html/2512.09758v1)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAcAAAAZCAYAAAD9jjQ4AAAA3ElEQVR4AcyQuw4BURRFhwwRUYhCgloUWoWS+AGhplBpJT6BXu8jlBq1Bp1HROIDKDQKjcfa92ZkMhGlmNx19zlnz7mvsPPl+5EZ4ggRMCO4Z5fqEswPQbOBoe4H6vhNl0IJ1HlHjRkjSEEFkjAD5a46+yQbmMATRrCGvMwBQQ72MIc0ZGEnE3W0dIZA+yF2+E11rGzZzp7ZJNVpF+h7eGaHyhkOoFoPTSiIE5RhCrpfAa3BVeaNYAtRKMIYWmAeQU9VJdFd62gbLmBM6YlJ9x2iRzBDy5rg0/R35gsAAP//fa6DQwAAAAZJREFUAwAyASAzx9Z0xwAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAYCAYAAACMcW/9AAADDUlEQVR4AdSWSciNURjHr1mGhTLGQlFYsDFtZFgZiwyJRInIQohIFKVYWLJAJNMGC0WyMCUhhSQpZS5TCiXz8Pt93z238577Xve7ynf7bv/f+zznOed9z3POe855b+tCC/m1+ES712GinbSBlfq1Mq9uJ8H20JxqR2cXoCuUKS/R/rTqC9+gOfWVzk7AaChTXqLzaHUE6qEtdDofypSX6HhaHYZ66COdDoA+kFGa6Ahq78MvqJd8mwvSztNEN9LgJKQaS2AXDIegUTg7IH0Goapyw6yh1XHYAG4kTINMdEKDF13STjyWrkX1uo5uDs4tsK4HVq3nshpqPR0Wcs8d+ADbYSIcg6DPOI9hGJQUJzqZ6EH4CbGWUFgLIcFW+MoZ1taCg97HDSthPzyCcZDKt+pElOIhUe1eouch1VYCP2AVPIG3oC5zeQfpwAjlqi1Rl8pF7BlQ77kMAt8YpqRLeMYxjTLBRq9Q8EG/QyGyPngM5d7gugpt+lF+Dg4CU1UzaOH5fA4b62FcKPr2kdnQrYsVBpfjezRhyuTr8egIM2EDk9+G40MxVTWp2OJq0f7NuHldp6U2IVEDp7gshjaQypnwNYeknP1pNDoNQe7cpRSmQ57uFYMvizaYzjgzIdYsCi4TTKPiRI24Ez129GM8Wz1SuhHsCC5013NInFBhJBfXuRvSzilm5EfEJMNAPC2G0uIQhI2KW/D5/jm5bSGQJupxkY7Otru5nIVn8Apcm+5a3JJu4rlb3Wyd8FP5RqYQXAbe/wa7CVbAHgjyE34lFIJNE71OhedXOIIoNsgNswivJ/QCZwGT0XdKs+EB2B5TJs9Pnz+YGjfnXOxriGU/zn4cK6SJWuloHJV+jK/Zw9h/OXE89v1GDyHgxsPkyud8ouYLpOpC4Cm8gIzyEvUr4agyDZtY8BPsLDX1bE0fu5nAUShTXqJ+LXwdLvayG6oEDlDvpxZTszpwh3/xbmDLlJeojdZx+Zc/zpmdyjNqket6Kjd48mCyqpSoM5pt+f9LLpe7lbqplGil9nWL/wEAAP//wEIY3gAAAAZJREFUAwDB3YIxpam+nQAAAABJRU5ErkJggg==>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAoAAAAaCAYAAACO5M0mAAAA8klEQVR4AezQP0oDURAH4EWxEQtBbAULURA8gJ0Igp2X8ABaeAJBEAuxU1TwAoLYaCV2op1gZeO/RtIFUiRFkm8evCVJEZI2JMw3M7v55bHZiWLAzzjY90UN/XoWHHfBLctETWuP7FLEiXOWZ46Y5ZqoRW2LY1Jw03LKH6vENIoP7YR/UvDLcsY288SPjFR3+j0p+BoL8Sw/5gu5liznpGDMKW2FN1rk2rD8UgYnXcQf+TRzrVlmqFMGmy5qxMlGqn19j1TxemJpaJfscMAVT3yTKgfjuQ7dWeedOOnGLCsH842K5YEqXdUb7Pqy82Kkgm0AAAD//1MVb/0AAAAGSURBVAMAFvwlNcGO/V0AAAAASUVORK5CYII=>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAgAAAAaCAYAAACKER0bAAAAxUlEQVR4AeyQIQoCQRSGF/EQJoMINvEAKlj2ABbBIJgt4gEMnsEgmAQRLBZBNKtFBE0m2RMs1tXm9+vOMkwxC7u8771/3n5MmIz340uF7wO571BiPYYLbMG3hQ6LI+ygAQEsjVDhMIERrOEFTQgkZAkz0JwzVRGtKiQUCWXQ1Q+mqTshkpAnqFZqLhKe8fIaT3vkJNzYSKox7WpxmEoICT70YQgDWEAduhKY3p5WgA2coA09CI1A/tSZfoCkXCH5YcJfCG8AAAD///XmqdAAAAAGSURBVAMALu8gNZcGxH8AAAAASUVORK5CYII=>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEkAAAAXCAYAAABH92JbAAAD4UlEQVR4AeyXZ6gUVxTH14QkpCeEhBQCgUBIIE1BEAsidlRsiCCKigXFgggqothQQRGxoF9E7IoNwV6woB9VVFRU/CBWbKgoYi+/39NZZndn3szOE57iW/7/OXPPPefO3TP3nnvmg1zNLzECNUFKDFEuVxOklEH6NYXdx9h8C9OgAUYtK2HacRji7YAraX6KqQzGpj1MQi0M6sD/YtgDfQv4TsEg7WPGbWBlaE7napiEFxjMhdNjuBF9VfAJzo1gVvgSfUn+78rG+ILOf2AFNN7C3XgYhz/oOA8fwOpGVyawEn4Is8CX6K74JcG5Hf35NGSQzqC4DuMePIG+tfBtgNt1MhMZCbNiII5jYBzMv6Pp3AorYJCM7kxae+C2CP6L7gCsbtRnAsfhGtgHfgSz4CpOjeFvMAquot3hDoNk+wiXutAo90L2hMpFSBP7Y2RafIfhnzH8GX1WuIKW4nwbzoMGDVE2nuExCnaBUeiOciLMIwiSD96A9ht4Dbr9biA1dnVxmxq9sVwYwwHos8BEegvHo1As57IYZl1NHiAd8P8chmH5cgeFRLxCECRbLuG+3rzmj8jn8BwsBzMw9mFRHEdfFizAaQoM4As8ScNUgMiE7Xi5WxB5jOBuDixAOEgP6fF4/R4pOnFx2yGqFT/w9CbQoCDycFsMz7fKvzEPdwy5uYtMK6aekDpX8lmyit7W8FPo1jiGrG50ZgIGxD/AbR5uiZ9o/Q2z4D5Oh2ArKGZxMU0gAryS4ZWkZjYXK+t6SAP0BBlGLRomzDQFGaaJsDr3NInLLV8ywhC4F0ZhEsri1e4WbIu++L+hKsESNGOhRapfCRbWNAtRPJAF41NM3JuS2wJ8RWsn3AFrwyi4Ck2IUXQygc9n3ByGJtGGyCj4ltfT4YmEKIF/ypXkM4NOi81NNPRFVIpT9J6F/aHBeoQsQXGQNFjG5Wt4BRbjHgq3pLWGkadZAFfaCTT6BrxM+xK8AE2KLnNuc74Qk7HV/F8qItgNnScsIhbr6BkGAxgkT+dmgSJBus2mYbMfRiIqSGZ9Jxfl4GnXjw4HvosshoXp7ygNckATol/+1k/KzfQLbX17Jl+Dr66YQ1G4shGxWEGP2wZRgalcB8GbMA18qdaIcXMoSdwO6qR8u97H0aX8JqpwV56lx8GYB12M0YfVnsqu2rCuKQ1XPCIRbuXik7PAKWolFRhENCzCLDAtOiO6y1L9j7U54TTyTcEyxuCXW9/FPj9LkMwp1hixg5bR4ZbzE6EMl0RTc104RyU6JBlkCdIuBnVLIqoMPzMiT5QqjGzt4xaswhCFrlmCVDjCe9B6CQAA//9dSMuEAAAABklEQVQDACM7ri+3js3xAAAAAElFTkSuQmCC>
