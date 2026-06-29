# IME Switcher を Binding 機構から分離する(ハイブリッド構成)

左右⌘の単独タップで Input Source を切り替える IME Switcher を、汎用の Binding テーブル(Trigger + Action のユーザー定義集合)に統合せず、独立した固定機能モジュールとして実装する。設定UIも Bindings タブとは別の IME Switcher タブで露出する。

Modifier Tap の検出ロジック(他キーが伴ったら発火しない・閾値時間内の押下のみ等)は他 Trigger と性質が大きく異なり、混ぜると挙動の予期しなさが増す。また IME 切替はユーザーが日常的に依存する「絶対動いてほしい」機能で、Binding 一覧から誤って削除される事故を避けたい。

## Considered Options

- **完全分離**: Action レイヤーも別実装。シンプルだが「Input Source 選択」処理が重複する
- **完全統合**: Modifier Tap を Trigger 種別の1つとして Binding に組み込む。アーキテクチャは一枚岩になるが、安定性リスクと検出ロジックの混在が問題
- **ハイブリッド(採用)**: モジュール・設定UI・Trigger 検出は分離、Action レイヤー(`InputSourceAction`)のみ共有

## Consequences

- 設定UI が「IME Switcher」「Bindings」の 2 タブに分かれ、ユーザーは2箇所を覚える必要がある
- 「⌘単独タップに IME 切替以外の動作を割り当てたい」要望が出た場合、Modifier Tap Trigger を後付けで Binding に追加する必要があるが、その時点で本ADRを supersede すればよい
