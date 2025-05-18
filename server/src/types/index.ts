import { PrismaClient, User, UserRefreshToken } from '@prisma/client';
import { SupabaseClient } from '@supabase/supabase-js';

// 環境変数の型定義 (ここに追加)
export interface Bindings {
  DATABASE_URL: string;
  DIRECT_URL: string;
  SUPABASE_URL: string;
  SUPABASE_KEY: string;
  SERVER_API_KEY_SECRET: string;
  REFRESH_TOKEN_ENCRYPTION_KEY: string;
}

// 認証済みユーザーの拡張型
export interface AuthenticatedUser extends User {
  refreshToken: UserRefreshToken | null;
  rawRefreshToken?: string; // 復号化されたリフレッシュトークン
}

// グローバル型定義
declare global {
  interface Variables {
    prisma: PrismaClient;
    supabase: SupabaseClient;
    user?: AuthenticatedUser;
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
    user?: AuthenticatedUser;
  }
}

// DTOのエクスポート
export * from './dto';