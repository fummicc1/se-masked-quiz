import { z } from 'zod';

// JWTトークン型定義
export interface JwtPayload {
  sub: string; // Apple ID
  email: string;
  email_verified: boolean;
  is_private_email: boolean;
  aud: string; // クライアントID
  iat: number; // 発行時間
  exp: number; // 有効期限
  iss: string; // 発行者
}

// Define the schema for the /apple/sign-in request body
export const AppleSignInRequestSchema = z.object({
  idToken: z.string(),
  displayName: z.string().optional(),
});

// ユーザー情報レスポンス
export const UserResponseSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email().optional(),
  displayName: z.string().optional(),
  avatarUrl: z.string().url().optional(),
});

export type UserResponse = z.infer<typeof UserResponseSchema>;

// 認証エラーレスポンス
export const AuthErrorResponseSchema = z.object({
  error: z.string(),
  message: z.string().optional(),
});

export type AuthErrorResponse = z.infer<typeof AuthErrorResponseSchema>;

// ログアウトレスポンス
export const LogoutResponseSchema = z.object({
  success: z.boolean(),
});

export type LogoutResponse = z.infer<typeof LogoutResponseSchema>;