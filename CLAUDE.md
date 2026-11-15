# routine-checker（ルーティンチェッカー）— 作業の決まり

朝・帰りなどのチェックリストを、時刻か「家にいる間」をきっかけに通知する iPhone アプリ。
仕様は README.md。ここには **作業の進め方** だけを書く。

## いちばん大事なこと：この Mac（jinnoMac-mini）の上で作業する

- 作業は **Mac mini 上のローカルの会話** で行う。クラウドの会話では iPhone に入れられない
  （Xcode も iPhone も届かない）。最初はクラウドで始めてしまい、ここで詰まった（2026-11-15）。
- **変更したら毎回、iPhone Air に Wi-Fi 経由で入れるところまでやる。** 本人はすぐ実機で試す。
  入れる方法：リポジトリの直下で `./install-device.sh`。
  USB でつながっていなければ、ペアリング済み（`available (paired)`）の iPhone に Wi-Fi で入れる。
  iPhone Air は同じ Wi-Fi・ロック解除の状態で待っている前提。入らない時は `mochimono/install-device.sh`
  （Wi-Fi で動いている実績あり）と比べて直す。
- 入れ終わったら「入れました」と、何を試せばよいかを短く伝える。

## 入れる前に回すもの

```sh
cd RoutineCore && swift test          # ロジックのテスト
cd .. && xcodebuild -project RoutineChecker/RoutineChecker.xcodeproj -scheme RoutineChecker \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

GitHub Actions（`.github/workflows/build.yml`）でも同じものが回る。

## 構成の要点

- `RoutineCore/`：UI に依存しないロジック。通知をいつ予約するかは `Planner` が決める。ここを変えたらテストを足す。
- `RoutineChecker/`：Xcode プロジェクト（iOS 18 以上、フォルダ同期のグループなのでファイルを置けばビルドに入る）。
  署名はチーム `A7WA598R44`、バンドルID `com.zzzjjj080.RoutineChecker`、表示名「ルーティン」。
- 家の出入りは `CLMonitor`（位置情報「常に許可」が必要）。通知は毎回全部予約し直す（「30分後にもう一度」の分は残す）。

## 書き方

- 本人とのやり取り・コミットメッセージ・README は日本語。説明は短く、専門用語を避ける。
- ブランチ `claude/brave-archimedes-mooik3`、PR #1（下書き）で進めている。
