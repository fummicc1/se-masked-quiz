declare namespace Cloudflare {
  interface Env {
    QUIZ_BUCKET: R2Bucket
    DB: D1Database
    ASSETS: Fetcher
    PAYLOAD_SECRET: string
    ADMIN_GATE_USER: string
    ADMIN_GATE_PASSWORD: string
  }
}

interface CloudflareEnv extends Cloudflare.Env {}
