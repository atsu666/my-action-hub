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
