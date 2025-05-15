import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import * as jose from 'jose';
import { 
  AppleSignInRequestSchema,
  Bindings, 
  JwtPayload, 
  UserResponseSchema 
} from '../types/index'; // AppleAuthCallbackRequestSchema, AuthErrorResponseSchema, LogoutResponseSchema は直接使わないので削除も検討
import { z } from 'zod'; // ZodErrorのためにインポート
import { validateAuthorizationWithApiKey } from './middlewares/authorization';

export const authRouter = new Hono<{ Bindings: Bindings, Variables: Variables }>();

authRouter.post(
  '/apple/sign-in',
  validateAuthorizationWithApiKey,
  zValidator('json', AppleSignInRequestSchema),
  async (c) => {
    try {
      const { idToken, displayName } = c.req.valid('json');
      const supabase = c.get('supabase');
      const prisma = c.get('prisma');

      // Step 1: Sign in with Supabase using the Apple ID token
      const { data: supabaseAuthData, error: supabaseSignInError } = 
        await supabase.auth.signInWithIdToken({
          provider: 'apple',
          token: idToken,
        });

      if (supabaseSignInError || !supabaseAuthData?.session || !supabaseAuthData?.user) {
        console.error('Supabase signInWithIdToken error:', supabaseSignInError?.message);
        return c.json({ 
          error: 'Supabase authentication failed', 
          message: supabaseSignInError?.message || 'SupabaseでのAppleトークン認証に失敗しました' 
        }, 401);
      }

      const supabaseUser = supabaseAuthData.user;
      const supabaseSession = supabaseAuthData.session;

      // Step 2: Extract Apple User ID (sub) for Prisma.
      let appleSub: string | undefined;
      try {
        const decodedAppleToken = jose.decodeJwt(idToken) as JwtPayload; 
        appleSub = decodedAppleToken.sub;
      } catch (decodeError) {
        console.error('Failed to decode Apple ID token (for sub extraction):', decodeError);
        return c.json({ error: 'Invalid Apple ID token format', message: 'Apple IDトークンの形式が無効です。' }, 400);
      }

      if (!appleSub) {
        return c.json({ error: 'Could not extract Apple User ID', message: 'AppleユーザーIDをトークンから抽出できませんでした。'}, 400);
      }
      
      const userEmail = supabaseUser.email; 
      if (!userEmail) {
           return c.json({ error: 'Email not available from Supabase user', message: 'Supabaseユーザーからメールアドレスが取得できませんでした。'}, 400);
      }

      // Step 3: Find or create user in Prisma
      let prismaUser = await prisma.user.findUnique({
        where: { appleId: appleSub },
      });

      let isNewPrismaUser = false;
      if (!prismaUser) {
        isNewPrismaUser = true;

        prismaUser = await prisma.user.create({
          data: {
            appleId: appleSub,
            email: userEmail, 
            displayName: displayName,
          },
        });
      }

      // Step 4: Ensure Supabase user_metadata contains prisma_user_id
      if (supabaseUser.user_metadata?.prisma_user_id !== prismaUser.id || isNewPrismaUser) {
        const { error: updateUserError } = await supabase.auth.updateUser({
          data: { 
            prisma_user_id: prismaUser.id,
            apple_user_id: appleSub 
          },
        });
        if (updateUserError) {
          console.warn('Failed to update Supabase user_metadata:', updateUserError.message);
        }
      }
      
      const responsePayload = {
        id: prismaUser.id,
        email: prismaUser.email,
        displayName: prismaUser.displayName,
        avatarUrl: prismaUser.avatarUrl,
        accessToken: supabaseSession.access_token,
        refreshToken: supabaseSession.refresh_token,
        isNewUser: isNewPrismaUser 
      };
      
      return c.json(responsePayload);

    } catch (error) {
      console.error('Apple ID token verification and user processing error:', error);
      if (error instanceof z.ZodError) { 
        return c.json({ error: 'Request validation failed', details: error.issues }, 400);
      }
      return c.json({ error: 'Internal server error', message: 'Apple認証処理中にサーバーエラーが発生しました。' }, 500);
    }
  }
);

// /me route to get user profile using Supabase token
authRouter.get('/me', async (c) => {
  try {
    const authHeader = c.req.header('Authorization');
    const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7) : null;

    if (!token) {
      return c.json({ error: 'Unauthorized', message: '認証トークンが必要です' }, 401);
    }

    const supabase = c.get('supabase');
    const { data: { user: supabaseUser }, error: userError } = await supabase.auth.getUser(token);

    if (userError || !supabaseUser) {
      console.error('Supabase getUser error for /me:', userError?.message);
      return c.json({ error: 'Invalid token or user not found', message: userError?.message || '無効なトークン、またはSupabaseユーザーが見つかりません' }, 401);
    }

    const prismaUserId = supabaseUser.user_metadata?.prisma_user_id as string | undefined;
    if (!prismaUserId) {
      console.error(`Prisma user ID not found in Supabase user_metadata. Supabase User ID: ${supabaseUser.id}`);
      return c.json({ error: 'User metadata incomplete', message: 'ユーザー情報が不完全です (Prisma ID連携なし)' }, 404);
    }

    const prisma = c.get('prisma');
    const user = await prisma.user.findUnique({ where: { id: prismaUserId } });

    if (!user) {
      console.error(`Prisma user not found for prisma_user_id: ${prismaUserId}. Supabase User ID: ${supabaseUser.id}`);
      return c.json({ error: 'User not found in DB', message: 'データベースにユーザーが見つかりません (Prisma連携不整合)' }, 404);
    }

    // Parse with UserResponseSchema which should ideally not include tokens.
    const validatedResponse = UserResponseSchema.parse({
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl
    });
    return c.json(validatedResponse);

  } catch (error) {
    console.error('Get /me error:', error);
    if (error instanceof z.ZodError) {
      return c.json({ error: 'Response validation failed for /me', details: error.issues }, 500);
    }
    return c.json({ error: 'Failed to get user information for /me', message: 'ユーザー情報の取得に失敗しました' }, 500);
  }
});

// /logout route
authRouter.post('/logout', async (c) => {
  try {
    const authHeader = c.req.header('Authorization');
    const token = authHeader?.startsWith('Bearer ') ? authHeader.substring(7) : null;

    if (token) {
      const supabase = c.get('supabase');
      const { error: signOutError } = await supabase.auth.signOut(); 
      if (signOutError) {
        console.warn('Supabase signOut error (non-critical):', signOutError.message);
      }
    }
    return c.json({ success: true, message: 'Logged out successfully. Please discard your token.' });

  } catch (error) {
    console.error('Logout error:', error);
    return c.json({ error: 'Logout failed', message: 'ログアウト処理中にエラーが発生しました' }, 500);
  }
});