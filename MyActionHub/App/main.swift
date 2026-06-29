//
//  main.swift
//  MyActionHub
//
//  明示的なエントリポイント。`@main` + NSApplicationDelegate プロトコル拡張による
//  暗黙の main() に依存せず、NSApplication.shared.delegate を明示的にセットする。
//
//  Swift 6 strict concurrency と `@main` の組み合わせで delegate が正しく
//  セットされないケースの対策。
//

import AppKit

NSLog("[MyActionHub] main.swift: 起動シーケンス開始")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

NSLog("[MyActionHub] main.swift: delegate セット完了 → NSApp.run()")

app.run()
