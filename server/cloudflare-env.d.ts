declare namespace Cloudflare {
  interface Env {
    QUIZ_BUCKET: R2Bucket
    DB: D1Database
    ASSETS: Fetcher
    PAYLOAD_SECRET: string
  }
}

interface CloudflareEnv extends Cloudflare.Env {}
