# 3/4本指ジェスチャー検出に非公開 MultitouchSupport.framework を使う

BTT 風の「指だけで完結する」3/4本指スワイプ/Force Click を Trigger として提供するため、公開 `NSEvent` の Swipe / Gesture イベントではなく、Karabiner-Elements / BetterTouchTool が同様に依存している非公開 `MultitouchSupport.framework`(`IORegisterForSystemPower` 経由で接触点の生データを取得する系統)を使う。

公開 API では macOS 標準ジェスチャーとの共存に修飾キー併用が必須となり、依頼の「BTT の一部機能をシンプルに実装」の体験が出せないため。

## Considered Options

- **公開 API のみ**: `NSEvent` のスワイプ系イベントで処理。修飾キー併用必須となり体験劣化
- **公開 + 非公開ハイブリッド**: 非公開で接触を観測しつつ標準イベントを `event.tap` で握りつぶす。理想的だがタイミング制御が極めてデリケートで初版スコープから外す
- **非公開 API のみ(採用)**: ユーザー側で衝突する OS ジェスチャーを手動 OFF にして使う

## Consequences

- macOS のアップデートでフレームワークの挙動が変わる/廃止されるリスクを抱える(BTT・Karabiner と同等のリスク)
- App Store 配布は不可(個人利用のためここでは問題にならない)
- 公式に文書化された権限ダイアログがないため、初回オンボーディングでは別途案内が必要
