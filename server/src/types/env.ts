export interface Env {
  DB: D1Database;
  CACHE: KVNamespace;
  APPLE_SERVICE_ID: string;
  JWT_SECRET: string;
  JWT_EXPIRES_IN: string;
}