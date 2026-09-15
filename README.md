# MyActionHub

US配列キーボード向けのIME切替と、BetterTouchTool風のトラックパッドジェスチャー/ショートカットによるアクション実行を1つのメニューバー常駐アプリで提供する。

設計の背景は [CONTEXT.md](CONTEXT.md) と [docs/adr/](docs/adr/) を参照。

## ビルド方法

### 必要環境
- macOS 13 Ventura 以上(Apple Silicon)
- Xcode 15 以上
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)(`brew install xcodegen`)

### 手順

```bash
cd /Users/atsu666/Develop/app/kana
xcodegen generate
open MyActionHub.xcodeproj
```

Xcode で ⌘R で実行。初回ビルド後、システム設定で**アクセシビリティ**と**入力監視**の権限を付与する必要があります(アプリのオンボーディング画面でも案内されます)。

## 構成

```
MyActionHub/
├── App/                   AppDelegate, MenuBar
├── IMESwitcher/           機能A: 左右⌘ → IME 切替
├── Bindings/
│   ├── Models/            Binding, Trigger, Action データ型
│   ├── Triggers/          Hotkey / Gesture 検出
│   └── Actions/           Window / AppToggle / Finder / InputSource
├── Storage/               JSON 永続化
├── Settings/              設定 UI (SwiftUI)
│   └── Tabs/              General / IMESwitcher / Bindings / Permissions
├── Onboarding/            初回起動ウィザード
└── Services/              権限チェック / 自動起動
```

設定ファイルは `~/Library/Application Support/MyActionHub/config.json` に保存される。

## トラブルシューティング

### OS アップデート後に一部機能だけ動かなくなった

macOS のアップデートで TCC の付与が片方だけ失効することがある(実例: macOS 26.7 で
**入力監視は残ったままアクセシビリティだけ Denied** になった)。症状は機能ごとに分かれる。

| 失効した権限 | 動かなくなる機能 |
| --- | --- |
| アクセシビリティ | ウィンドウ最大化 / 左右寄せ、Finder トグル |
| 入力監視 | IME Switcher、トラックパッドジェスチャー |

まず起動時ログで現在の付与状態を確認する。

```bash
log show --predicate 'subsystem == "com.appleple.myactionhub"' --last 1h --info --style compact
```

`権限: アクセシビリティ=false` のように出る。OS 側の判定そのものを見たい場合は tccd のログを読む。

```bash
log show --predicate 'process == "tccd" AND eventMessage CONTAINS "myactionhub"' --last 1h --info --style compact | grep "Handling access request"
```

`Auth Right: Denied (System Set)` なら失効。システム設定 →
プライバシーとセキュリティ → アクセシビリティ で MyActionHub を ON に戻す。
チェックを入れ直しても復活しない場合は、いったん一覧から削除(−)してから
アプリを再起動して追加し直す。それでも駄目なら付与情報をリセットしてから再起動する。

```bash
tccutil reset Accessibility com.appleple.myactionhub
```

### リビルドのたびに権限を付け直すことになる

`CODE_SIGN_IDENTITY` が ad-hoc(`-`)に戻っていないか確認する。詳細は
[project.yml](project.yml) の署名まわりのコメントを参照。
