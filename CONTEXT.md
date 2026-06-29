# MyActionHub

US配列キーボード向けのIME切替と、BetterTouchTool風のトラックパッドジェスチャー/ショートカットからのアクション実行を1つのメニューバー常駐アプリで提供するための文脈。

- **アプリ名**: MyActionHub
- **Bundle ID**: `com.appleple.myactionhub`

## Language

### 機能A: IMEスイッチャー関連

**IME Switcher**:
左右の⌘キーを単独タップした際に、macOSの入力ソースを切り替える独立した固定機能モジュール。Bindingテーブルには載らず、専用設定タブから ON/OFF と左右役割の入れ替えのみ可能。
_Avoid_: IME切替機能、Modifier IME、左右コマンド機能

**Modifier Tap**:
修飾キー(⌘など)を、他のキーを一切伴わずに押して離す動作。押下から離鍵までが閾値時間(デフォルト0.5秒)以内である必要がある。
_Avoid_: Cmdタップ、修飾キー単押し

**Input Source**:
macOSが管理する入力ソース(`TISInputSource`)。ABC(英数)とHiragana(かな)など。IME Switcherは `TISSelectInputSource()` で直接選択する。
_Avoid_: IME、変換モード、言語

### 機能B: ジェスチャー/ショートカット関連

**Binding**:
1つの**Trigger**と1つの**Action**を結びつけたユーザー定義のペア。機能Bの中核データ構造。1 Trigger は同時に1つの Binding にしか割り当てられない(重複禁止)。
_Avoid_: マッピング、ルール、ショートカット定義

**Trigger**:
Bindingの発火条件となる入力イベント。種類は以下に限定:
- 3本指/4本指のスワイプ(上下左右)
- 3本指/4本指のForce Click(2段階目の強押し込み)
- キーボードショートカット
_Avoid_: 入力、イベント、フック

**Action**:
Bindingが発火した時に実行される操作。**自身のパラメータをBindingに内包する**(Bindingごとに固有の値を持つ。グローバル設定は使わない)。種類は以下に限定:
- ウィンドウを最大化(Visible Frame に合わせる。macOSのフルスクリーンスペースには入らない)
- ウィンドウを左に寄せる(Visible Frame 幅に対する % を指定。高さはフル)
- ウィンドウを右に寄せる(同上)
- Finderを開く(ホームディレクトリを `NSWorkspace.open` で開く)
- 指定アプリの表示/非表示トグル(対象アプリの bundle ID。Dockアイコンクリック同等の挙動: 未起動なら起動 / 背面なら前面化 / 前面なら hide)

ウィンドウ系Actionの対象は常に**フロントアプリのフロントウィンドウ**、対象スクリーンは**そのウィンドウの中心が乗っているスクリーン**。

同じ種類のActionを異なるパラメータで複数のBindingに登録可能(例: 「左に50%」と「左に70%」を別Bindingで持てる)。IME Switcherが内部的に呼ぶ「Input Source選択」もActionレイヤーで共有する(ただしBindingテーブルには露出しない)。
_Avoid_: コマンド、処理、ハンドラー

## Example dialogue

> 開発者: 「左⌘を単独タップしたときの動作って、Binding で書ける?」
>
> 設計者: 「いや、IME Switcher は Binding テーブルの外。固定機能なので、設定タブからは ON/OFF と左右の役割入れ替えだけ。Binding で『Modifier Tap』を Trigger に使えるようにはしない」
>
> 開発者: 「じゃあ Action は共有してないってこと?」
>
> 設計者: 「Action レイヤーは共有してる。『Input Source を ABC にする』という Action は IME Switcher も呼ぶし、もし将来 Binding 経由でも呼びたくなったら同じ実装を再利用できる。露出しているかどうかが違うだけ」

## Flagged ambiguities

(現在なし)
