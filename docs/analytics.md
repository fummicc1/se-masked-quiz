# アナリティクス（軽量計測基盤）

Issue #6 のディスカバリで定義した **実験1: 計測基盤** の運用ドキュメント。
iOS アプリから匿名イベントを自前サーバ（Payload + Cloudflare D1）へ送信し、WAU と学習記録タブ閲覧率を計測する。

## 目的と成功基準

- 実験1の問い: 「実績を見る」欲求は実在するか
- **成功基準: 学習記録タブ閲覧ユニークユーザーが WAU の 30% 以上**（30日間観測）
- 成功した場合のみ実験2（ShareLink 共有シート MVP）へ進む。詳細は `.tmp/discovery.md` と Issue #6 のコメントを参照

## イベント一覧（9種）

| name | パラメータ | 発火箇所 |
|---|---|---|
| `app_open` | なし | `se_masked_quizApp.swift`（起動・前面復帰） |
| `quiz_started` | `proposalId` | `QuizViewModel.swift` |
| `quiz_answered` | `isCorrect` | `QuizViewModel.swift` |
| `daily_challenge_completed` | `streak` | （定義のみ、現在発火箇所なし） |
| `streak_incremented` | `days` | `QuizViewModel.swift` |
| `notification_permission` | `granted` | `SettingScreen.swift` |
| `notification_opened` | なし | `AppNotificationDelegate.swift` |
| `reminder_time_set` | `hour`, `minute` | `SettingScreen.swift` |
| `stats_screen_viewed` | なし | `StreakStatsScreen.swift`（学習記録タブ表示） |

イベント定義は `ios/se-masked-quiz/Services/AnalyticsService.swift`、送信実装は同 `RemoteAnalyticsService.swift`、サーバ側の受け口とバリデーションは `server/src/collections/AnalyticsEvents.ts`。

## データモデル

D1 テーブル `analytics_events`（`server/migrations/0004_analytics_events.sql`）:

| カラム | 内容 |
|---|---|
| `name` | イベント名（サーバ側でホワイトリスト検証） |
| `anon_id` | 匿名インストールID。初回送信時に端末で遅延生成される UUID。**オプトアウト中は生成すらされない** |
| `params` | イベントパラメータ（JSON文字列、≤8エントリ・短い文字列のみ） |
| `app_version` | アプリの `CFBundleShortVersionString` |
| `created_at` | サーバ側で付与される UTC 時刻（ISO8601 text）。クライアント時刻は送信しない |

## 集計クエリ

すべて `cd server` で実行する。

### 判定用ワンショット（直近7日の WAU と閲覧率）

```bash
pnpm exec wrangler d1 execute se-masked-quiz-db --remote --command "
SELECT wau.n AS wau, stats.n AS stats_viewers,
       ROUND(100.0 * stats.n / wau.n, 1) AS stats_view_rate_pct
FROM
  (SELECT COUNT(DISTINCT anon_id) AS n FROM analytics_events
   WHERE created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-7 days')) AS wau,
  (SELECT COUNT(DISTINCT anon_id) AS n FROM analytics_events
   WHERE name = 'stats_screen_viewed'
     AND created_at >= strftime('%Y-%m-%dT%H:%M:%fZ','now','-7 days')) AS stats"
```

### 週次トレンド

```bash
pnpm exec wrangler d1 execute se-masked-quiz-db --remote --command "
SELECT strftime('%Y-%W', created_at) AS week,
       COUNT(DISTINCT anon_id) AS wau,
       COUNT(DISTINCT CASE WHEN name='stats_screen_viewed' THEN anon_id END) AS stats_viewers,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN name='stats_screen_viewed' THEN anon_id END)
             / COUNT(DISTINCT anon_id), 1) AS stats_view_rate_pct
FROM analytics_events
GROUP BY week ORDER BY week DESC LIMIT 8"
```

`created_at` は ISO8601 text のため辞書順比較＝時系列比較が成立し、`analytics_events_name_created_at_idx` が効く。

## 判定手順

1. 計測を含むバージョンの App Store 公開日から観測開始（それ以前のデータは母数が偏るため使わない）
2. 週1回、判定用ワンショットを実行して `stats_view_rate_pct` を記録する
3. 30日経過時点で `stats_view_rate_pct >= 30.0` なら実験2へ、未満なら Issue #6 は No-Go を維持

## 注意点

- **fire-and-forget**: リトライ・バッチングなし。ネットワーク断で欠損するが、率（分母/分子）比較なので影響は相殺方向
- **重複発火**: 学習記録タブは表示のたびに `stats_screen_viewed` を送るが、集計が distinct カウントのため影響なし
- **オプトアウト**: 設定画面の「利用状況の計測を許可」を OFF にすると送信されず、匿名IDも生成されない
- **レート制限**: `/api/*` は 60req/10s per IP（`server/src/middleware.ts`）。通常利用では到達しない
- **読み取り保護**: `analytics-events` の read は Payload 管理者のみ。create は匿名可だがイベント名ホワイトリスト・UUID形式・サイズ上限で厳格に検証される
