# **2023年以降における形式手法の進化と人工知能（LLM）との相互作用による技術革新**

## **1\. 序論：形式手法と人工知能の融合がもたらす新パラダイム**

長年にわたり、ソフトウェア工学およびシステム設計における「形式手法（Formal Methods）」は、航空宇宙、原子力、特定の暗号技術など、極めて高い安全性が要求されるミッションクリティカルな領域に限定して適用されてきた。その最大の障壁は、TLA+やCoq、Isabelleといった仕様記述言語や定理証明支援系を扱うための高い学習コストと、証明構築に要する膨大な人的労力であった1。しかし、2023年から2026年にかけて、大規模言語モデル（LLM）の飛躍的な進化に伴い、形式手法を取り巻く状況は根本的なパラダイムシフトを迎えている。

このパラダイムシフトは双方向の性質を持っている。第一に、LLMの推論能力とコード生成能力を活用することで、これまで人間が行っていた形式仕様の記述や定理の証明プロセスが劇的に自動化・効率化されている点である2。第二に、LLM自身が生成するコードや、自律的に動作するAIエージェントの出力に対する信頼性を保証するために、確率的なテストではなく、数学的・決定論的な「形式検証（Formal Verification）」が不可欠なガードレールとして再評価されている点である4。

かつて専門家のみの領域であった形式手法は、よりソフトウェアエンジニアに親和性の高い次世代言語（QuintやFizzBeeなど）の台頭により民主化されつつある7。同時に、人工知能の推論プロセスにおけるハルシネーション（幻覚）の排除やセキュリティポリシーの遵守を担保するための基盤技術として、形式論理がかつてないほどの産業的価値を生み出している4。本報告では、Alloy、Quint、TLA+、FizzBeeなどの形式仕様言語の最新の進展と、Lean 4やIsabelle/HOLを用いた定理証明におけるLLMの統合、そして生成AIの安全性担保に向けた形式手法の応用事例について、網羅的かつ深層的な分析を行う。

## **2\. 次世代形式仕様言語の台頭と産業応用における目覚ましい成果**

分散システムや並行処理の検証において、長らくデファクトスタンダードであったTLA+は、強力な状態空間の検証能力を持つ一方で、数学的な集合論に基づく記法がソフトウェアエンジニアにとって心理的・技術的な障壁となっていた1。Amazon Web Services (AWS) における初期のTLA+導入においても、エンジニアにこの言語を習得させることが大きな課題であったことが報告されている1。この課題を解決するため、よりプログラマに親和性の高い構文と高度なツールチェーンを備えた次世代の形式仕様言語が台頭し、2023年以降の産業界で目覚ましい成果を上げている。

### **2.1. Quintと分散システムのモデリング：TLA+の堅牢性と開発者体験の融合**

Quintは、Informal Systemsによって開発された、TLA+の基礎理論であるTemporal Logic of Actions（TLA）の堅牢な理論的基盤を継承しつつ、TypeScriptやPythonに似た現代的なプログラミングパラダイムを取り入れた実行可能な仕様記述言語である7。型システムを持たないTLA+とは異なり、Quintは厳密な型チェックを備えており、IDEサポート（定義へのジャンプ等）やREPL、シミュレータを標準で統合しているため、数学者ではない一般的なソフトウェアエンジニアにとっても扱いやすい環境を提供している7。

Quintの検証バックエンドには、二つの異なる戦略を持つモデルチェッカーが用意されている。一つは、仕様をTLA+にトランスパイルした上で実行される明示的状態（Explicit-state）モデルチェッカーである「TLC」である12。TLCはすべての可能な状態を個別に列挙して検証を行うため、状態空間が十分に小さい場合には予測可能なパフォーマンスを発揮するが、無限集合（例えばすべての整数の集合）から数を選択するようなモデルには対応できないという制約がある12。もう一つは、Quintのツールチェーンにネイティブに統合されているシンボリックモデルチェッカー「Apalache」である12。Apalacheは、モデルとそのプロパティをSatisfiability Modulo Theories（SMT）の制約式に変換し、Z3 SMTソルバを用いて充足可能性をチェックする12。有界モデル検査（Bounded Model Checking）のパラダイムを採用しており、事前に定義された最大ステップ数（デフォルトでは10）の範囲内で、TLCでは不可能な巨大な数値範囲を持つ仕様の検証を可能にしている12。

産業応用において特筆すべき成功事例の一つが、Matter LabsによるZKsyncシステムのコンセンサスアルゴリズム「ChonkyBFT」の形式検証である14。ChonkyBFTは、HotStuffとFaB Paxosに着想を得たハイブリッドプロトコルであり、単一スロットのファイナリティと ![][image1] のビザンチン障害耐性を持つ15。Matter Labsのコンセンサスチームは、このアルゴリズムを完全なRust実装に移す前に、Rustライクな擬似コードの段階でQuintを用いた形式仕様化を実施した14。 検証プロセスにおいて、暗号学的ハッシュ関数は恒等関数として抽象化され、公開鍵・秘密鍵はノードのアイデンティティとして表現された14。乱数ベースのシミュレータを用いた初期テストでは、100万回の実行でも特定の実行経路（例えば単一のブロックのみがコミットされる状態）を発見できないケースがあったものの、Apalacheを用いたシンボリックな有界モデル検査に切り替えることで、わずか30分で当該のエッジケースを含む反例（Counter-example）を特定することに成功した14。このモデル検査により、擬似コード内に潜んでいた小さな矛盾や、悪意のあるノード（Byzantineノード）がシステムをフォークさせる可能性のあるメッセージ検証の欠落が実装前に発見・修正された14。また、特定の状態への到達を強制する「ガイド付きモデル検査（Guided Model Checking）」や、ビザンチン振る舞いをシミュレートするTwins技術のQuintへの適用も行われ、プロトコルの安全性とライブネス（Liveness）が数学的に保証された14。

さらに、Informal Systems自身も、複雑なBFTコンセンサスエンジン「Malachite」において、通信ステップを削減する「Fast Tendermint」への移行という大規模なコア変更作業にQuintを活用している12。通常の開発プロセスであれば数ヶ月を要すると推測されるこの変更において、開発チームはLLMにプロトコル設計を直接委ねるのではなく、人間が記述した英語の仕様書を基にLLM（Claude Codeを活用したQuint LLM Kitなどを利用）を「翻訳者」として機能させ、「Quint仕様」を構築した12。Quint上でシミュレータとモデルチェッカーを用いてAIが生成した仕様の振る舞いを検証することで、元の英語仕様書に存在した2つの論理バグをコード記述前の段階で即座に発見した12。その後、「Quint Connect」と呼ばれるモデルベーステスト（Model-Based Testing: MBT）フレームワークを用いて、検証済みのQuint仕様と実際のRust実装の動作を決定論的に同期させることで、わずか1週間でコード生成とテストを完了させるという驚異的な効率化を達成している12。

### **2.2. FizzBee：プログラマ向け仕様記述言語と暗黙的フォールトインジェクション**

Quintと同様に、分散システムの設計と検証を民主化することを目的として開発されたのが「FizzBee」である1。FizzBeeはPythonに極めて近い構文を持つ形式仕様記述言語であり、TLA+の厳密性を維持しつつ学習曲線を大幅に引き下げている8。ConfluentやDoorDash、Shopifyの現役エンジニアらが、数時間の学習で実践的なモデリングを行い、複雑な並行処理バグを発見した事例が多数報告されている8。DoorDashのエンジニアは、組み込みキーバリューストア「SlateDB」のマニフェスト設計において、FizzBeeを用いた仕様記述を通じて一晩で現実の並行性バグを特定した8。

FizzBeeの技術的特長は、一般的なプログラミングのメンタルモデルに即した状態遷移の定義と、分散システム特有の障害を自動的にシミュレートする「暗黙的フォールトインジェクション（Implicit Fault Injection）」機能にある8。TLA+などの伝統的なツールが厳格なアトミックアクション（単一の状態遷移）に依存しているのに対し、FizzBeeは「非アトミックアクション」というパラダイムを導入している8。これにより、開発者は複雑なシーケンシャルワークフローや分散トランザクションを直感的に記述できる。この非アトミックなアクションの実行中において、FizzBeeのモデルチェッカーは、ネットワークによるメッセージのドロップ、スレッドのクラッシュ（任意のイールドポイントでの停止）、さらにはエフェメラルな状態を喪失するプロセス全体のクラッシュやディスク障害などを自動的に注入し、検証空間を探索する8。開発者は手動でプログラムカウンタや障害シナリオをモデリングする認知的負荷から解放される8。

システム設計における制約条件や前提条件は、組み込みのガード句（Guard Clauses）やイネーブリング条件（Enabling Conditions）を通じて実装される8。FizzBeeは、特定のアクションが「実行可能（Enabled）」であるかを、内部のステートメント（代入や組み込み関数の呼び出しなどの単純なPython風ステートメント）が実際に実行されたかどうかに基づいて推論する8。制御文（if-elseなど）の評価前に状態変数の代入が行われてしまうと、意図せずアクションが有効化されてしまうという落とし穴を防ぐため、requireステートメントによる明示的なアクションの無効化機能も備えられている8。

さらに、システムが最終的に望ましい状態に到達することを保証する「ライブネス（Liveness）」の検証においては、線形時相論理（LTL）のサブセットであるalways eventually（常にいつかは発生する）やeventually always（いつかはその状態になり永遠に続く）といったキーワードが用いられる8。アクションの実行機会を保証する「フェアネス（Fairness）」の概念も、弱いフェアネス（継続的に有効なアクションが最終的に実行される）から強いフェアネス（無限に有効化されるアクションが無限に実行される）まで、ロールインスタンスごとにスコープを絞って定義可能である8。分散アルゴリズム（リーダー選出やコンセンサスなど）において非決定論的なタイミングやリトライのジッターがライブネスの条件となる場合には、専用の「非決定論的モデルチェッカー」を有効にすることで、厳密な探索が可能となる8。

FizzBeeは単なる振る舞いの正確性検証にとどまらず、確率的モデリング（Probabilistic Modeling）およびパフォーマンスモデリング機能を提供している点でも画期的である8。開発者は、特定の分岐（例えばキャッシュヒットとキャッシュミス）に対して確率を割り当て、レイテンシやコストといった「カウンター」を定義することができる8。モデルチェッカーが生成した状態空間に対してパフォーマンスチェッカーを実行することで、システム全体の平均レイテンシやエラー率、さらには99.9%タイルなどのテールレイテンシの分布（ヒストグラム）を分析し、特定のAPIが「ファイブ・ナイン（99.999%）」の可用性要件（SLA）を満たしているかを形式的に検証することが可能である8。

### **2.3. Alloy 6：時相論理のネイティブサポートとリレーショナルモデリングの進化**

ソフトウェアモデリングのためのオープンソース言語およびアナライザであるAlloyも、メジャーアップデートである「Alloy 6」によって大きな進化を遂げた18。以前のAlloy（バージョン4および5）は、一階述語論理に基づく関係的（Relational）な制約や構造のモデリングにおいて、TLA+を凌ぐ記述力と解析速度を持っていた。しかし、並行処理や時間の経過を伴う状態遷移（動的振る舞い）の表現が弱点とされており、開発者は時間をエミュレートするための複雑なトリックを用いる必要があった19。

2024年から2025年にかけて普及が進んだAlloy 6（最新リリースはバージョン6.2.0）では、この弱点が完全に克服され、線形時相論理（Linear Temporal Logic: LTL）の演算子と、状態の可変性を示すvarキーワードが言語仕様としてネイティブに導入された18。これにより、状態（シグネチャやリレーション）のステップ間の遷移を、always（常に）や他の未来指向の演算子を用いて直感的に記述できるようになり、複雑な分散プロトコルや動的システムの振る舞い仕様が極めて簡潔になった20。

バックエンドには改良されたSATソルバベースのモデルファインダー「Kodkod」が継続して採用されており、スコープ（探索する要素の最大数）を限定した有界探索において高速な反例生成を実現している18。また、状態遷移のトレースを視覚的にデバッグするためのビジュアライザも大幅に改良された。すべての有限スコープのトレースが終端または過去の状態へのループバックを持つ「Lassoトレース」として扱われる中で、開発者は「New Config（不変部分を変更して新たな構成を探索）」「New Init（初期状態を変更）」「New Trace（既存の初期状態から新たな遷移を探索）」「New Fork（トレースの途中から別の次状態を探索）」といったオプションを駆使して、システムの動的挙動を詳細に分析することが可能となった20。

産業界や学術界におけるAlloyとTLA+の比較（2025年のコンセンサス）によれば、それぞれの強みに基づく明確な棲み分けが形成されている。Alloy 6は時相論理のサポートによって状態遷移の表現力を向上させたものの、依然として複雑なデータ構造、関係データベースの設計、複雑なGUIフローに伴う状態推移など「構造的・関係的な複雑さ」を持つドメインにおいて最適であると評価されている21。一方で、TLA+（およびそれに類するQuintやFizzBee）は、並行処理や分散アルゴリズムといった純粋なステートマシンの検証において引き続き優位性を持っている22。

| 形式仕様言語 | 主なバックエンド / 検証手法 | 構文・パラダイムの特徴 | 強みと2023年以降の主要な進展 |
| :---- | :---- | :---- | :---- |
| **Quint** | TLC, Apalache (Z3 SMTソルバを用いた有界モデル検査) | TypeScript/Pythonライク。型システムを備える。 | シミュレータとシンボリック実行の統合。BFTコンセンサスの検証（Matter Labs）や、LLMエージェントを用いたモデルベーステスト（Informal Systems）で実証済みの成果12。 |
| **FizzBee** | 独自の非決定論的モデルチェッカー | Pythonライク。アクターモデルや手続き型に対応。 | 導入障壁が極めて低い。暗黙的フォールトインジェクション（ネットワーク分断やスレッドクラッシュ）、SLA評価のための確率的性能モデリング機能が充実8。 |
| **Alloy 6** | Kodkod (SATソルバベースのモデルファインダー) | 宣言的・関係論理（一階述語論理）に基づく。 | LTL（線形時相論理）のネイティブサポートとvarキーワードの導入により並行処理モデリングの弱点を克服。複雑なデータ構造の検証に最適18。 |
| **TLA+** | TLC, TLAPS (インタラクティブ定理証明) | 数学的（集合論・論理学に基づく厳密な記法）。 | 厳密な分散システム検証のデファクトスタンダード。学習コストの高さが課題だが、近年はLLMを用いた定理証明支援（AutoReal-Prover等）の研究が進展中23。 |

## **3\. 大規模言語モデル（LLM）を活用した形式検証の自動化と効率化**

AIによる自動化の波は、形式手法の最大の課題であった「仕様記述と証明構築にかかる膨大な人的コスト」を劇的に削減しつつある。LLMの高度なコード理解能力と論理推論能力を、定理証明器やモデルチェッカーからの決定論的なフィードバックループと結合させることで、自動化された形式検証の新時代が到来している。

### **3.1. PropertyGPT：検索拡張生成（RAG）によるスマートコントラクトのプロパティ自動生成**

数十億ドルの暗号資産を扱うスマートコントラクトの領域では、論理的な脆弱性が直接的な致命傷（資金の流出）となるため、形式検証に対する需要が極めて高い3。スマートコントラクトの静的検証ツール（Prover）自体は高度に発展しているものの、「検証すべき仕様（Invariants, Pre/Post-conditions, 状態推移ルール）」をセキュリティ専門家が手動で記述しなければならない点がスケーラビリティの障害であった3。Certoraのような業界をリードする監査機関であっても、これまでは契約ごとに専門家がケースバイケースで仕様を記述する人海戦術に頼らざるを得なかった3。

NDSS 2025で発表された「PropertyGPT」は、検索拡張生成（RAG: Retrieval-Augmented Generation）とGPT-4クラスの最先端LLMを組み合わせることで、未知のコードに対する包括的な検証プロパティを自動生成する画期的なフレームワークである3。 このシステムのアーキテクチャは、まず過去の監査レポート等から得られた人間が記述した高品質な検証プロパティをベクトルデータベースに埋め込むことから始まる3。新たなスマートコントラクトのソースコードが入力されると、PropertyGPTは複数の類似性次元を考慮した重み付けアルゴリズムを用いてコンテキストの近いプロパティを検索し、上位K個（Top-K）のプロパティを抽出する3。これらをLLMに対するIn-context learningの参照データとして提供することで、対象コードに特化した新しいプロパティのドラフトを生成させる3。

LLMが生成したプロパティが構文的に正しくコンパイル可能であり、かつ論理的に適切であることを保証するため、PropertyGPTはコンパイラや静的解析ツールからのフィードバックを「外部オラクル」として利用し、LLMに反復的な修正（Iterative Revision）を行わせるフィードバックループを構築している3。 実証実験において、PropertyGPTはグラウンドトゥルース（専門家が記述したプロパティ）と比較して80%の再現率（Recall）を達成した3。特筆すべきは、既知のCVEや過去の攻撃インシデント37件中26件を自動的に検出しただけでなく、未発見であった**12件のゼロデイ脆弱性**を発見し、8,256ドルのバグバウンティ報酬を獲得するという、実社会での直接的なセキュリティインパクトを示した点である3。

このLLMによる仕様生成のアプローチは、Ethereum系のSolidityに限らず、CosmosエコシステムにおけるCosmWasmスマートコントラクトに対しても適用されている27。CosmWasm Capture the Flag (CTF) ベンチマークを用いた2025年の研究では、CTF-02からCTF-09に含まれる23のターゲット関数に対して、LLMを用いてQuintの形式モデルを生成し、Quintのモデルベーステストによって論理バグを特定する手法が評価されている28。ここでも、LLMの流暢なコード生成能力と、Quintシミュレータ/チェッカーによる決定論的な正確性検証が互いを補完し合っている。同様に、C言語プログラムに対しても、Frama-CのWPプラグインで検証可能なACSL（ANSI/ISO C Specification Language）仕様をDeepSeek-V3.2やOLMo 3.1 32Bなどの言語モデルを用いて自動生成・検証する試みが進展している30。

### **3.2. AutoReal-ProverとseL4：定理証明の自律化とCoT推論**

形式仕様に基づく有界モデル検査に対し、システムが無限の状態空間を持つ場合や、パラメータのサイズに依存しない普遍的な正確性を保証するためには、インタラクティブ定理証明（Interactive Theorem Proving: ITP）が必要となる。しかし、定理証明の最大のボトルネックは、証明ステップ（タクティック）を人間が手動で記述するための膨大な専門知識と労力である。例えば、世界初の形式的に証明されたマイクロカーネルである「seL4」の検証には、Isabelle/HOLを用いて約20人年（Person-years）の労力が費やされたことが知られている2。

2026年の最新研究において、この問題を劇的に緩和するLLM主導の定理証明フレームワーク「AutoReal」およびその専用モデル「AutoReal-Prover」が発表された2。従来のLLMによる証明生成アプローチ（GPT-4などを利用したSelene等の先行研究）は、汎用モデルにIsabelleの構文を直接出力させようとするものであり、APIコストの高さや、証明コンテキストの欠如による低い成功率（一部の定理セットで27.06%程度）が課題であった2。

「AutoReal-Prover」は、7Bパラメータのオープンソースモデル（Qwen2.5-Coder-7B）をベースとし、産業インフラでのローカルデプロイを前提としたコスト効率の高い設計となっている2。このモデルは以下の独自技術を用いてファインチューニングされた。

1. **Chain-of-Thought (CoT) ベースの証明学習**：seL4の証明トレースから構築された約20万件のステップレベルのインスタンスを使用。LLMに単一の証明スクリプトを出力させるのではなく、証明状態の遷移前と遷移後の変化を自然言語で説明させるCoT推論を行わせる。これにより、モデルは推論の過程でIsabelleのチェッカーへ高コストな問い合わせを繰り返すことなく、モデル内部で証明状態の推移を自律的にシミュレートする能力を獲得した2。
2. **コンテキスト拡張（Context Augmentation）**：産業規模のプロジェクトでは、定理は孤立して存在せず、多数の補題や定義に複雑に依存している。seL4の広範な証明コンテキストをLLMのプロンプトに動的に組み込むことで、推論の精度を大幅に向上させた2。

評価の結果、AutoReal-ProverはseL4公式リポジトリの「重要な理論」に指定されている全10カテゴリ・660の定理において、**51.67%の全体証明成功率**（341/660）を達成し、既存のベースラインを大きく凌駕した2。

| seL4 定理カテゴリ | テスト定理数 | AutoReal-Prover 成功率 | 検証内容の概要 |
| :---- | :---- | :---- | :---- |
| asmrefine | 1 | 100% (1/1) | アセンブリレベルの詳細化証明 |
| capDL-api | 123 | 72.36% (89/123) | ケーパビリティ分散言語のAPI仕様に関する証明 |
| drefine | 3 | 66.67% (2/3) | データ構造の詳細化に関する証明 |
| access-control | 84 | 55.95% (47/84) | アクセス制御モデルとセキュリティポリシーの証明 |
| invariant-abstract | 105 | 54.29% (57/105) | 抽象仕様レベルにおけるシステム不変条件の証明 |
| refine | 55 | 47.27% (26/55) | 抽象仕様から実行可能なCコード仕様への詳細化証明 |
| infoflow | 233 | 43.35% (101/233) | 情報フロー制御（非干渉性）と機密性に関する証明 |

また、Archive of Formal Proofs (AFP) の他の暗号・セキュリティプロジェクト（CRYSTALS-Kyber、RSAPSS、楕円曲線暗号など）の451定理においても53.88%の成功率を示しており、限られた計算リソースでのローカルデプロイが可能な7Bクラスのモデルが、汎用の巨大モデルを凌駕する専門的推論能力を持つことを証明した2。

### **3.3. Lean 4とAWS Cedar：クラウドインフラにおける完全検証と差分テスト**

自動化による効率化と並行して、定理証明言語自体の進化も産業界での採用を後押ししている。純粋関数型プログラミング言語でありながら強力な定理証明器でもある「Lean 4」は、旧バージョンのLean 3における制限を克服し、C++で書かれたランタイムをLean自身で実装し直すことで、完全な汎用プログラミング言語としての地位を確立した31。

アマゾン・ウェブ・サービス（AWS）は、形式手法をクラウドインフラストラクチャの基盤に組み込む世界最大の推進者の一つである。その最新の成果が、アクセス制御ポリシーを定義するオープンソース言語「Cedar」の開発と検証におけるLean 4の採用である34。Cedarの認可エンジン（Amazon Verified Permissions等で利用）は、何十億ものリクエストをミリ秒単位で処理しつつ、セキュリティの決定を一切の誤りなく行わなければならない。AWSは、この決定が数学的に正しいことを保証するため、「検証主導型開発（Verification-guided development）」という厳格なプロセスを構築した35。

AWSの研究チームは、Cedarのセマンティクスと評価エンジンの挙動をLean 4で定式化し、以下のような重要な特性を数学的に証明した37。

* **Forbid trumps permit**：いかなる「許可（permit）」ポリシーが条件を満たしていても、「禁止（forbid）」ポリシーが一つでも該当すれば、リクエストは必ず拒否される。
* **Default deny**：合致する許可ポリシーが存在しない場合、リクエストはデフォルトで拒否される。
* **Order independence**：ポリシーの評価順序や重複の有無に関わらず、認可エンジンは常に完全に同じ決定を出力する。
* **Termination**：Cedarの関数の評価は、無限ループに陥ることなく必ず終了する。

さらに、数学的証明が行われたLean 4のモデルと、本番環境で稼働する実際のRust実装の挙動が完全に一致することを確認するため、「差分テスト（Differential Testing）」が導入されている38。数百万のランダムな入力が生成され、LeanモデルとRust実装の両方に投入される。Lean 4の実行速度はテストケースあたりわずか5マイクロ秒（Rust実装は7マイクロ秒）と極めて高速であり、この網羅的なテストを実用的な時間内で完了させることを可能にしている38。AWSでは、証明と差分テストが全て通過しない限り、Cedarの新しいバージョンはリリースされない体制が敷かれており、形式手法がプロダクションのCI/CDパイプラインに完全に統合された成功事例となっている38。

## **4\. 生成AIおよび自律エージェントの安全性を担保する形式手法**

形式手法がAIを支援しコード検証を効率化する一方で、「AI（LLM）の出力の安全性と信頼性をいかに形式手法で保証するか」という逆方向のアプローチも、2024年以降のAI安全性（AI Safety）研究の最重要テーマとなっている6。ブラックボックスであり、確率的かつ非決定論的なLLMの挙動に対して、従来の統計的なベンチマークテストやプロンプトベースのRed-teamingは不十分であり、真の信頼性検証が求められている5。

### **4.1. 機械学習の安全性に関する形式検証の8つのカテゴリ**

2025年に発表された「安全クリティカルな機械学習のための形式手法に関する体系的文献レビュー」によれば、過去数年間の研究におけるMLシステムに対する形式手法の適用は、論理的アプローチと対象領域に基づいて以下の8つのカテゴリに分類されている39。

1. **到達可能性と過剰近似手法（Reachability and Over-Approximation Techniques）**：ニューラルネットワークの出力空間を幾何学的に過剰近似し、いかなる入力に対しても出力が事前に定義された危険な境界（安全違反状態）を超えないことを計算・証明する。
2. **SMTベースの検証と抽象化/詳細化（SMT-based Verification and Abstraction/Refinement）**：ネットワークのアーキテクチャや振る舞いを論理式に変換し、Z3などのSMTソルバを用いて安全特性の充足可能性を解く。
3. **混合整数線形計画法/整数線形計画法（MILP/ILP Approaches）**：ReLUなどの非線形な活性化関数を線形制約および整数変数の組み合わせとしてエンコードし、最適化ソルバを用いて最悪ケースの挙動を特定する。
4. **モデル検査アプローチ（Model Checking Approaches）**：システム（またはエージェント）の取り得る全ての状態遷移を状態空間としてモデル化し、特定の時相論理プロパティ（常に安全状態を維持するか等）を検証する。
5. **実行時検証手法（Runtime Verification Approaches）**：稼働中のシステムの入力および出力をリアルタイムで監視し、事前に形式定義された仕様からの逸脱を検知・記録する。
6. **シールディング技術（Shielding Techniques）**：実行時検証をさらに発展させ、AIエージェントの行動を安全なアクション空間内に強制的に制限し、危険な行動が選択された場合は安全な代替行動に置き換えるか、実行を遮断する。
7. **制御バリア関数法（Control Barrier Function Methods）**：動的システムの制御理論に基づき、強化学習エージェントなどが安全集合（Safe Set）の内部に留まり続けることを数学的に保証する。
8. **リスク検証手法（Risk Verification Methods）**：不確実性を伴う環境下において、システムが危険な状態に陥る確率が許容可能な閾値未満であることを形式的・確率的に保証する。

これらの中で、近年急速に普及している巨大なLLMおよび自律エージェントに対して特に有効とされ、実践的な成果を挙げているのが**実行時検証**と\*\*シールディング（Shielding）\*\*技術である6。

### **4.2. ShieldAgent：論理推論に基づくLLMエージェントの動的防御（Shielding）**

自律的に動作するLLMエージェントは、環境（Webブラウザや外部API）からの観測結果に基づいて行動を決定するが、悪意のあるプロンプトインジェクションやツール（MCP等）の悪用によって、機密情報の漏洩や不正なトランザクションを引き起こす重大なリスクを抱えている42。従来のテキストベースのガードレール（Prompt Sandwichingなど）では、コンテキスト長の制限や動的に変化する実行環境のメタデータに対応できず、容易にバイパスされてしまう44。

ICML 2025で発表された「ShieldAgent」は、自律的に動作するLLMエージェントの行動軌跡（Action trajectory）に対し、明示的な安全ポリシーの遵守を決定論的に強制する画期的なガードレールエージェントである45。このシステムは、ポリシーを厳密な論理ルールとして処理することで、LLMエージェントの動作に「証明可能な安全性」を与えている45。

ShieldAgentのアーキテクチャは以下のプロセスで構成される42。

1. **ASPM（Action-based Safety Policy Model）の構築**：長大で非構造化された政府の規制文書やプラットフォームのポリシー文書（利用規約など）から、LLMを用いて個々の実行可能なルールを抽出し、それらを検証可能な「確率的ルール回路（Probabilistic Rule Circuits）」へと構造化・変換する。
2. **実行時形式検証とシールディング**：保護対象のエージェントが具体的な行動（ツールの実行やデータの送信）を決定した際、ShieldAgentはハイブリッドメモリから関連するルール回路を瞬時に検索する。そして、統合された検証ツールライブラリと実行可能なコードを用いて、その行動が安全ポリシーに違反していないかを論理推論に基づいて検証する。違反が検出された場合、ShieldAgentは代替のシールド計画を生成してエージェントの行動を安全な領域に引き戻すか、実行を完全に遮断する。

評価のために構築されたデータセット（ShieldAgent-Bench：7つのリスクカテゴリと6つのWeb環境における2,000件の命令と攻撃シナリオ）を用いた実証実験において、ShieldAgentは極めて優れた性能を示した45。違反ルールの再現率（Recall）で90.1%という高い数値を記録し、システムの安全性を確実に担保しつつ、正常な操作を誤って遮断する誤検知率（False Positive Rate）をわずか4.8%に抑え込んだ45。さらに、論理回路に基づく効率的な局所化（Localization）により、外部の閉鎖的APIに対するクエ​​リ数を64.7%、検証に要する推論時間を58.2%削減し、従来のガードレール手法を平均11.3%上回る最高水準（SOTA）の性能を達成している45。

### **4.3. Amazon Bedrock Guardrails：自動推論（Automated Reasoning）によるエンタープライズAIの数学的コンプライアンス検証**

よりエンタープライズ向けの直接的な応用として、AWSは2024年末から2025年にかけて、「Amazon Bedrock Guardrails」に「Automated Reasoning（自動推論）」によるチェック機能を一般提供（GA）した4。これは、生成AIの出力が企業のポリシーやドメイン知識に準拠していることを、確率論ではなく「数学的な確実性」をもって検証する機能である4。

金融機関での投資アドバイスや、製薬会社のFDA（食品医薬品局）承認データに基づくマーケティングなど、厳しく規制される業界では、AIの出力に対して統計的なサンプリングテストを行うだけでは法的・倫理的なリスクを排除できない4。Bedrockの自動推論機能は、形式手法を用いてこの課題に決定論的な解答を出している。

検証プロセスは以下のメカニズムで機能する4。

1. **ポリシーの論理的構造化**：最大12万トークン（約100ページ）の自然言語で書かれたポリシー文書を、自動推論エンジンが内部的に「変数のスキーマ」と「論理ルール」の集合に変換・エンコードする。
2. **前提と主張の推論**：ユーザーの入力とAIの生成出力から、基礎となる「前提（Premises）」と、そこから導き出された「主張（Claims）」を特定・抽出する。そして、抽出された論理ルールに照らし合わせて、主張が前提から数学的に証明可能であるか、あるいは矛盾していないかを評価する。
3. **精緻な結果の分類**：検証結果は、単純な「パス/フェイル」ではなく、以下の7つの明確なカテゴリ（Finding Types）に分類されて出力される。これにより、システム管理者はAIの挙動を極めて細かく制御できる。

| 判定カテゴリ | 説明（AI出力とポリシーの論理的関係性） |
| :---- | :---- |
| **VALID** | 入力と出力がポリシーに完全に整合しており、主張が前提から演繹的に証明され、矛盾する代替回答が存在しない。 |
| **SATISFIABLE** | 特定の条件下や仮定においてのみ真となり得る状態。エッジケースや境界条件の特定に有用。 |
| **INVALID** | ポリシーに対する不正確さや事実誤認が含まれる。検証が失敗した理由を示す反例（Counter-example）が提示され、フィードバックとして利用可能。 |
| **IMPOSSIBLE** | 前提がポリシーと完全に矛盾している、あるいはポリシー自体に内部的な論理矛盾が存在する。 |
| **NO\_TRANSLATIONS** | コンテンツが対象となるポリシードメインと無関係であるため、評価の対象外。 |
| **TRANSLATION\_AMBIGUOUS** | テキストに言語的な曖昧さがあり、決定論的な論理構造に変換できない。 |
| **TOO\_COMPLEX** | 情報量が過剰であり、許容される低レイテンシ内で処理するには構造が複雑すぎる。 |

さらに、このシステムには「シナリオ生成機能（Scenario Generation）」が組み込まれており、ポリシー作成者は自身の定義したルールがどのように適用されるかを示す具体的なテストサンプルを自動生成させることができる4。これにより、AIモデルをデプロイする前に、ポリシーカバレッジのギャップやルールの衝突を特定・修正するための反復的なアノテーション（変数の記述更新や言語的曖昧さの解消）が可能となっている4。BedrockのAPI（Converse等）に直接統合されたこの機能により、組織はLLMの幻覚をプロンプトエンジニアリングの試行錯誤ではなく、形式論理の枠組みで決定論的に制御・遮断することができるようになった4。

## **5\. 形式手法がソフトウェア開発ライフサイクルに与える非自明な影響**

LLMと形式手法の統合がもたらす影響は、単なるバグの削減や安全性の向上にとどまらず、ソフトウェアアーキテクチャのパフォーマンスや開発のライフサイクルそのものに非自明な変革をもたらしている。

AWSが国防高等研究計画局（DARPA）と共有した10年間にわたる知見によれば、「形式的に検証されたコードは、未検証のコードよりもパフォーマンスが高く、保守が容易になる」という予想外の発見が報告されている48。この直感に反する事象の背景には、システム設計に対する深い理解と無駄の排除がある。複雑な分散システムにおいて、開発者はしばしば未知のエッジケースを恐れ、冗長なロック機構、不要な状態確認、過剰なエラーハンドリングといった「防御的プログラミング（Defensive Programming）」を行ってしまう48。しかし、Alloy、Quint、FizzBeeなどの形式仕様によって全状態空間が網羅的に探索され、特定のバグ（デッドロックや競合状態）が存在しないことが数学的に保証されると、開発者は不要なオーバーヘッドや防壁を安全に削ぎ落とすことができるようになる48。検証プロセス中に発見された設計の無駄を修正することで、結果的にクリティカルパスの実行時間が短縮され、本番環境での深夜のデバッグ作業やログ解析の工数が激減する48。

さらに、「FizzBee」や「Quint」が実証したように、モデルから実際のプログラムコードへのマッピング（Model-Based Testing）をLLMが担い、そのブリッジングコードを自動生成・保守するワークフローが確立されつつある8。LLMは流暢なコードを生成する反面、構造的な欠陥や微細な競合状態を含有しやすいという根本的な弱点を持つため、AI単独への過信（Over-reliance）は重大なリスクとなる12。これに対し、形式手法は揺るぎない「真実の源（Source of Truth）」として機能する。 つまり、人間のエンジニアが自然言語の仕様を考え、LLMを「翻訳者」として形式言語（QuintやFizzBee）の仕様を記述させる。その形式仕様をモデルチェッカーで堅牢に検証した後、再度LLMを用いて本番実装（RustやGoなど）を生成し、決定論的な差分テストで同期させるというハイブリッドな開発ライフサイクルである12。「Verification-first（検証ファースト）」のパラダイムの下、AIを強力なアシスタントとして活用しつつ、常に形式的証明に責任を持たせる「Expert in the loop」の思想は、今後のソフトウェア工学における標準プラクティスとなっていくと推察される49。

## **6\. 総括と今後の展望**

2023年から2026年までの膨大なデータと産業適用事例が示す最も重要な知見は、「AI技術（LLM）の発展と形式手法の普及は、決して独立したトレンドではなく、互いが互いの最大のボトルネックを解消する強力な共生関係（Symbiosis）にある」ということである。

1. **AIによる形式手法の民主化とスケーリング**： かつて高度な訓練を受けた専門家や学術研究者にしか扱えなかったTLA+やIsabelle/HOLによる仕様記述と定理証明は、PropertyGPTによるRAGベースの仕様生成や、AutoReal-Proverのような自律的推論AIによって、その導入ハードルと人的労力が劇的に削減された2。また、QuintやFizzBeeといったプログラマフレンドリーな新世代言語と、LLMによる翻訳・テスト生成ツールキットの登場により、スタートアップや小規模な開発チームであっても、数日単位で形式検証を設計サイクルに組み込める環境が整った8。
2. **形式手法によるAIの決定論的制御と信頼性保証**： 生成AIや自律エージェントの出力が確率的であり、ハルシネーションやセキュリティバイパスのリスクを完全にゼロにできないという課題に対し、形式手法が究極の防波堤として機能している。Amazon BedrockにおけるAutomated Reasoningの適用や、ShieldAgentによるポリシーのルール回路化に基づく動的シールディングは、「もっと賢いAI」を用いてAIを監視・採点するアプローチの限界を示し、「証明可能な論理機構」をガードレールとして据えることの絶対的な優位性を実証した4。

結論として、クラウド規模の大規模分散インフラ（AWS Cedar、ZKsync ChonkyBFT、Informal Systems Malachite等）から、LLMを活用した次世代の自律ソフトウェア開発に至るまで、ミッションクリティカルなシステムの信頼性はもはや「テストカバレッジによる欠陥の不在証明の試み」ではなく、「形式仕様による正当性の数学的証明」へと移行している。AIによるコード生成の爆発的な増加が「検証の危機（Validation Crisis）」を招く中、形式手法はその危機を救う唯一の決定論的解法であり、これら二つの技術領域の深い統合こそが、今後10年のソフトウェアおよびコンピューティングにおける最も重要な技術革新の基盤となる。

#### **Works cited**

1. Introducing FizzBee: Simplifying Formal Methods for All \- The New Stack, accessed April 4, 2026, [https://thenewstack.io/introducing-fizzbee-simplifying-formal-methods-for-all/](https://thenewstack.io/introducing-fizzbee-simplifying-formal-methods-for-all/)
2. Towards Real-World Industrial-Scale Verification: LLM ... \- arXiv, accessed April 4, 2026, [https://www.arxiv.org/pdf/2602.08384](https://www.arxiv.org/pdf/2602.08384)
3. PropertyGPT: LLM-driven Formal Verification of Smart Contracts ..., accessed April 4, 2026, [https://www.ndss-symposium.org/ndss-paper/propertygpt-llm-driven-formal-verification-of-smart-contracts-through-retrieval-augmented-property-generation/](https://www.ndss-symposium.org/ndss-paper/propertygpt-llm-driven-formal-verification-of-smart-contracts-through-retrieval-augmented-property-generation/)
4. Build reliable AI systems with Automated Reasoning on Amazon ..., accessed April 4, 2026, [https://aws.amazon.com/blogs/machine-learning/build-reliable-ai-systems-with-automated-reasoning-on-amazon-bedrock-part-1/](https://aws.amazon.com/blogs/machine-learning/build-reliable-ai-systems-with-automated-reasoning-on-amazon-bedrock-part-1/)
5. Domain Specific Benchmarks for Evaluating Multimodal Large Language Models \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2506.12958v2](https://arxiv.org/html/2506.12958v2)
6. Position: Formal Methods are the Principled ... \- OpenReview, accessed April 4, 2026, [https://openreview.net/pdf?id=7V5CDSsjB7](https://openreview.net/pdf?id=7V5CDSsjB7)
7. Quint: An executable specification language with delightful tooling based on the temporal logic of actions (TLA) : r/programming \- Reddit, accessed April 4, 2026, [https://www.reddit.com/r/programming/comments/18m05el/quint\_an\_executable\_specification\_language\_with/](https://www.reddit.com/r/programming/comments/18m05el/quint_an_executable_specification_language_with/)
8. FizzBee, accessed April 4, 2026, [https://fizzbee.io/](https://fizzbee.io/)
9. PwC and AWS Build Responsible AI with Automated Reasoning on Amazon Bedrock, accessed April 4, 2026, [https://aws.amazon.com/blogs/machine-learning/pwc-and-aws-build-responsible-ai-with-automated-reasoning-on-amazon-bedrock/](https://aws.amazon.com/blogs/machine-learning/pwc-and-aws-build-responsible-ai-with-automated-reasoning-on-amazon-bedrock/)
10. Why I use TLA+ and not(TLA+): Episode 1 \- Protocols Made Fun, accessed April 4, 2026, [https://protocols-made-fun.com/specification/modelchecking/tlaplus/quint/2024/10/05/tla-and-not-tla.html](https://protocols-made-fun.com/specification/modelchecking/tlaplus/quint/2024/10/05/tla-and-not-tla.html)
11. Formal specs as sets of behaviors \- Surfing Complexity, accessed April 4, 2026, [https://surfingcomplexity.blog/2025/07/26/formal-specs-as-sets-of-behaviors/](https://surfingcomplexity.blog/2025/07/26/formal-specs-as-sets-of-behaviors/)
12. Reliable Software in the LLM Era \- Quint, accessed April 4, 2026, [https://quint-lang.org/posts/llm\_era](https://quint-lang.org/posts/llm_era)
13. Talks and Lectures \- Igor Konnov, accessed April 4, 2026, [https://konnov.phd/talks/](https://konnov.phd/talks/)
14. Specification and model checking of BFT consensus by Matter Labs ..., accessed April 4, 2026, [https://protocols-made-fun.com/consensus/matterlabs/quint/specification/modelchecking/2024/07/29/chonkybft.html](https://protocols-made-fun.com/consensus/matterlabs/quint/specification/modelchecking/2024/07/29/chonkybft.html)
15. ChonkyBFT: Consensus Protocol of ZKsync \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2503.15380v1](https://arxiv.org/html/2503.15380v1)
16. (PDF) ChonkyBFT: Consensus Protocol of ZKsync \- ResearchGate, accessed April 4, 2026, [https://www.researchgate.net/publication/390020520\_ChonkyBFT\_Consensus\_Protocol\_of\_ZKsync](https://www.researchgate.net/publication/390020520_ChonkyBFT_Consensus_Protocol_of_ZKsync)
17. quint/docs/content/posts/quint\_connect.mdx at main \- GitHub, accessed April 4, 2026, [https://github.com/informalsystems/quint/blob/main/docs/content/posts/quint\_connect.mdx](https://github.com/informalsystems/quint/blob/main/docs/content/posts/quint_connect.mdx)
18. Alloy Analyzer, accessed April 4, 2026, [https://alloytools.org/](https://alloytools.org/)
19. How does Alloy compare to TLA+? \- Hacker News, accessed April 4, 2026, [https://news.ycombinator.com/item?id=35513617](https://news.ycombinator.com/item?id=35513617)
20. Alloy 6: it's about Time \- Hillel Wayne, accessed April 4, 2026, [https://www.hillelwayne.com/post/alloy6/](https://www.hillelwayne.com/post/alloy6/)
21. Alloy meets TLA : An exploratory study \- ALFA \- Universidade do Minho, accessed April 4, 2026, [https://alfa.di.uminho.pt/\~nfmmacedo/publications/tlalloy15.pdf](https://alfa.di.uminho.pt/~nfmmacedo/publications/tlalloy15.pdf)
22. Alloy 6 vs. TLA+, accessed April 4, 2026, [https://alloytools.discourse.group/t/alloy-6-vs-tla/329](https://alloytools.discourse.group/t/alloy-6-vs-tla/329)
23. Towards Language Model Guided "TLA"⁺ Proof Automation \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2512.09758v1](https://arxiv.org/html/2512.09758v1)
24. Retrieval-Augmented TLAPS Proof Generation with Large Language Models \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2501.03073v1](https://arxiv.org/html/2501.03073v1)
25. PropertyGPT: LLM-driven Formal Verification of Smart Contracts through Retrieval-Augmented Property Generation | Request PDF \- ResearchGate, accessed April 4, 2026, [https://www.researchgate.net/publication/389737068\_PropertyGPT\_LLM-driven\_Formal\_Verification\_of\_Smart\_Contracts\_through\_Retrieval-Augmented\_Property\_Generation](https://www.researchgate.net/publication/389737068_PropertyGPT_LLM-driven_Formal_Verification_of_Smart_Contracts_through_Retrieval-Augmented_Property_Generation)
26. PropertyGPT: LLM-driven Formal Verification of Smart Contracts through Retrieval-Augmented Property Generation \- Yi Li | Associate Professor, accessed April 4, 2026, [https://liyiweb.com/files/Liu2025PLD.pdf](https://liyiweb.com/files/Liu2025PLD.pdf)
27. Accessible Smart Contracts Verification: Synthesizing Formal Models with Tamed LLMs, accessed April 4, 2026, [https://arxiv.org/html/2501.12972v1](https://arxiv.org/html/2501.12972v1)
28. Accessible Smart Contracts Verification: Synthesizing Formal Models with Tamed LLMs, accessed April 4, 2026, [https://www.computer.org/csdl/proceedings-article/icst/2025/10989026/26S4MPqVnG0](https://www.computer.org/csdl/proceedings-article/icst/2025/10989026/26S4MPqVnG0)
29. accessed January 1, 1970, [https://arxiv.org/pdf/2501.12972](https://arxiv.org/pdf/2501.12972)
30. Evaluating LLM-Generated ACSL Annotations for Formal Verification \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2602.13851v2](https://arxiv.org/html/2602.13851v2)
31. Lean4Lean: Mechanizing the Metatheory of Lean (WITS 2026), accessed April 4, 2026, [https://popl26.sigplan.org/details/wits-2026-papers/11/-Lean4Lean-Mechanizing-the-Metatheory-of-Lean](https://popl26.sigplan.org/details/wits-2026-papers/11/-Lean4Lean-Mechanizing-the-Metatheory-of-Lean)
32. Cedar: A New Language for Expressive, Fast, Safe, and Analyzable Authorization, accessed April 4, 2026, [https://www.researchgate.net/publication/380201016\_Cedar\_A\_New\_Language\_for\_Expressive\_Fast\_Safe\_and\_Analyzable\_Authorization](https://www.researchgate.net/publication/380201016_Cedar_A_New_Language_for_Expressive_Fast_Safe_and_Analyzable_Authorization)
33. How the Lean language brings math to coding and coding to math \- Amazon Science, accessed April 4, 2026, [https://www.amazon.science/blog/how-the-lean-language-brings-math-to-coding-and-coding-to-math](https://www.amazon.science/blog/how-the-lean-language-brings-math-to-coding-and-coding-to-math)
34. Lean Into Verified Software Development | AWS Open Source Blog, accessed April 4, 2026, [https://aws.amazon.com/blogs/opensource/lean-into-verified-software-development/](https://aws.amazon.com/blogs/opensource/lean-into-verified-software-development/)
35. How we built Cedar with automated reasoning and differential testing \- Amazon Science, accessed April 4, 2026, [https://www.amazon.science/blog/how-we-built-cedar-with-automated-reasoning-and-differential-testing](https://www.amazon.science/blog/how-we-built-cedar-with-automated-reasoning-and-differential-testing)
36. Introducing Cedar Analysis: Open Source Tools for Verifying Authorization Policies \- AWS, accessed April 4, 2026, [https://aws.amazon.com/blogs/opensource/introducing-cedar-analysis-open-source-tools-for-verifying-authorization-policies/](https://aws.amazon.com/blogs/opensource/introducing-cedar-analysis-open-source-tools-for-verifying-authorization-policies/)
37. How We Built Cedar: A Verification-Guided Approach \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2407.01688v1](https://arxiv.org/html/2407.01688v1)
38. Lean Powers Secure Software at AWS: Cedar's Journey with Verified Development, accessed April 4, 2026, [https://lean-lang.org/use-cases/cedar/](https://lean-lang.org/use-cases/cedar/)
39. Formal methods for safety-critical machine learning: a systematic ..., accessed April 4, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12956799/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12956799/)
40. Formal methods for safety-critical machine learning: a systematic literature review \- Frontiers, accessed April 4, 2026, [https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2026.1749956/full](https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2026.1749956/full)
41. Formal methods for safety-critical machine learning: a systematic literature review, accessed April 4, 2026, [https://www.researchgate.net/publication/400910874\_Formal\_methods\_for\_safety-critical\_machine\_learning\_a\_systematic\_literature\_review](https://www.researchgate.net/publication/400910874_Formal_methods_for_safety-critical_machine_learning_a_systematic_literature_review)
42. ShieldAgent: Shielding Agents via Verifiable Safety Policy Reasoning \- arXiv, accessed April 4, 2026, [https://arxiv.org/html/2503.22738v1](https://arxiv.org/html/2503.22738v1)
43. Safeguarding large language models: a survey \- PMC, accessed April 4, 2026, [https://pmc.ncbi.nlm.nih.gov/articles/PMC12532640/](https://pmc.ncbi.nlm.nih.gov/articles/PMC12532640/)
44. Log-To-Leak: Prompt Injection Attacks on Tool-Using LLM Agents via Model Context Protocol | OpenReview, accessed April 4, 2026, [https://openreview.net/forum?id=UVgbFuXPaO](https://openreview.net/forum?id=UVgbFuXPaO)
45. ICML Poster ShieldAgent: Shielding Agents via Verifiable Safety Policy Reasoning, accessed April 4, 2026, [https://icml.cc/virtual/2025/poster/45989](https://icml.cc/virtual/2025/poster/45989)
46. ShieldAgent: Shielding Agents via Verifiable Safety Policy Reasoning, accessed April 4, 2026, [https://shieldagent-aiguard.github.io/](https://shieldagent-aiguard.github.io/)
47. SHIELDAGENT: Shielding Agents via Verifiable Safety Policy Reasoning \- Illinois Experts, accessed April 4, 2026, [https://experts.illinois.edu/en/publications/shieldagent-shielding-agents-via-verifiable-safety-policy-reasoni/](https://experts.illinois.edu/en/publications/shieldagent-shielding-agents-via-verifiable-safety-policy-reasoni/)
48. An unexpected discovery: Automated reasoning often makes systems more efficient and easier to maintain | AWS Security Blog, accessed April 4, 2026, [https://aws.amazon.com/blogs/security/an-unexpected-discovery-automated-reasoning-often-makes-systems-more-efficient-and-easier-to-maintain/](https://aws.amazon.com/blogs/security/an-unexpected-discovery-automated-reasoning-often-makes-systems-more-efficient-and-easier-to-maintain/)
49. Formal Verification First: How AI Supports But Cannot Replace It, accessed April 4, 2026, [https://semiengineering.com/formal-verification-first-how-ai-supports-but-cannot-replace-it/](https://semiengineering.com/formal-verification-first-how-ai-supports-but-cannot-replace-it/)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFwAAAAYCAYAAAB3JpoiAAAEnUlEQVR4AeyYZ6hURxiGN70X03shgSSkB5KQBiG9EQIJERH8YQULKmJBfyj6Q6zoL7FjwYqKiqIoNuyKKCqigqLYe8euz7Pes+5dd++ec+5x7wX38j73mzNnZs6c78x8M7N3p8p/JfVA2eEldXcqVXZ42eGJeeBTWhoB30CtUZIj/H3e6kFIUmNprBv8B39DGxgFxfQHBabBYVgC9g1TUn3C0yZBJSXp8C9peQa0gOcgCf1CI11hMkyHjrAIiqkzBTbCd7ATdDwmtOx/HN/U4QmjYS4sBAcK5qbiNHqzduWU01cHHSN7DXSCZ6A6OkHlvmDbjbFvwkioSi9y0zDih/ma9NtwCKKoNYUfgag6TYX28CvMhluUpMODxseTeAsWwHIYAw9AHJ2iki/QCDsczkMx/VBRwOdXJCObeyLXuFHhMuYgFFTgcEfBFEoFU+Al0sZOnWc85DKSfPBqanwAQ8GQMBP7BsSRDrBPd1VR+SPuGeMbYq/CT9AKHoeoCvwStV7R8jb8LKVcnHpix0E/6A7GIB1u7PyN6zi6SCUXrX+wttsLa4z7AhtGLsKDKGgdB8AK0oYtzC0yft5PrmFnD9aP48y6RjqqrBu1TqjyOvxnSurwTVgf5IrelPRicBE8iXX0YGLLEbeU2kNAhwQzicsqdYS7zrz6WPvkYjSR9NOQK/vbm8wL4Owybfw3rpJVI9KflR6sw/eToyP+x94LHUAHYVJOxzok9kJcOcq+pfJ2qAuGKJ9Bsqi+p8R8CGRcfpKLQgunL/gq97dAGD1FIfuWyyvkfwW5+S7GhjduxZMON3Q49dvSxFnYDIHakbCMU5lkZDWgxlaw8+5Lm5GOMuLcnlElI3dAXnzOv3wv/jH57i7WY8PoPgo5qHIxNOXmef0E5aPKQZCpozO9eIx/H8JUuALKkdmShFN1B9Z4iimqhyjRBZaBHTde9yFtaIoSTwdQZx/8DoF0kGkHSL62/vImrIMwckfh9i0X39fwlZvvdeCfMO1bJq/DHUk6P/tkZJ5fdCC1ngcXT0xBWd4DhzHX2Ov2bBilo+6BqZKWH9x1JXu0vp6+k0oZx4OwV5GVNn4cn7crfVU7/uV1uKPbG9mxz92L09a85vTdwwemoAwXjgxj9GBKuXhhYssjvPvwYEQ5C5vQmv3JtwY4+t12ujjnG/1Uve3SX+/wlPcgOPR5AjfPkJT5tdD98m4KCSYtY+82UoaGA1hHFaagenBnAiSllTTkNtKPuIG04eVh7GeQT4avR7mRvchyWVI5KAzBnjmcjfrQBX4OvfgTMg53D+7h55KZFbiA+qVe5tq9MKbkmsUTXwDPAa9hf4RCp01fVoevpUxNyZ8i7K++fJdOiKPbrbBnmozDnbbZzqZsWsbJQi+YLpD1T2d40guDv/xlVa0yeYa7bl2PY+0nppLmceXvJv9ijd3OBpLVUn9qn4PE5UKZVKN+GHciYUjqZVxY3Rsf5SWM6/Ww7mAw1ZIfON/HrVajVk7S4cZ641UYkoqzLswu0oY/D1WrfKnaTJIOr6n3NJx4wHKRrak+hH5ucg4P/cg7u2DZ4SX+/tcBAAD//yvpCg8AAAAGSURBVAMAzH3gMdlwMgUAAAAASUVORK5CYII=>
