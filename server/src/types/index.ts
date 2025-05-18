import { PrismaClient, User, UserRefreshToken } from '@prisma/client';
import { SupabaseClient } from '@supabase/supabase-js';

// 環境変数の型定義 (ここに追加)
export type Bindings = {
  DATABASE_URL: string;
  DIRECT_URL: string;
  SUPABASE_URL: string;
  SUPABASE_KEY: string;
  SERVER_API_KEY_SECRET: string;
}

// グローバル型定義
declare global {
  interface Variables {
    prisma: PrismaClient;
    supabase: SupabaseClient;
    user?: User & { refreshToken: UserRefreshToken | null };
  }
  // Cloudflare Workers の ExecutionContext を Hono で利用可能にするための型定義
  interface ExecutionContext {
    waitUntil(promise: Promise<any>): void;
    passThroughOnException(): void;
  }
}

declare module 'hono' {
  interface ContextVariableMap {
    prisma: PrismaClient;
    supabase: SupabaseClient;
    user?: User & { refreshToken: UserRefreshToken | null };
  }
}

// DTOのエクスポート
export * from './dto';