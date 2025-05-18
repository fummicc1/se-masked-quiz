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
import { validateAuthorization } from './middlewares/authorization';
import { TokenService } from '../services/token';

export const authRouter = new Hono<{ Bindings: Bindings, Variables: Variables }>();

authRouter.post(
  '/apple/sign-in',
  validateAuthorization('api_key'),
  zValidator('json', AppleSignInRequestSchema),
  async (c) => {
    try {
      const { idToken, displayName } = c.req.valid('json');
      const supabase = c.get('supabase');
      const prisma = c.get('prisma');
      const tokenService = new TokenService(prisma, c.env.REFRESH_TOKEN_ENCRYPTION_KEY);

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
            apple_user_id: appleSub,
            display_name: displayName,
          },
        });
        if (updateUserError) {
          console.warn('Failed to update Supabase user_metadata:', updateUserError.message);
        }
      }
      
      // Step 5: Store the refresh token with encryption
      await tokenService.storeRefreshToken(prismaUser.id, supabaseSession.refresh_token);
      
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

authRouter.post('/reissue-access-token', validateAuthorization('refresh_token'), async (c) => {
  // Update access token
  const supabase = c.get('supabase');
  const prisma = c.get('prisma');
  const user = c.get('user');
  const tokenService = new TokenService(prisma, c.env.REFRESH_TOKEN_ENCRYPTION_KEY);
  
  if (!user?.refreshToken) {
    return c.json({ error: 'No refresh token found', message: 'リフレッシュトークンが見つかりません' }, 401);
  }
  
  if (!user.rawRefreshToken) {
    return c.json({ error: 'No raw refresh token found', message: 'リフレッシュトークンの取得に失敗しました' }, 401);
  }
  
  const { data: { session }, error: refreshError } = await supabase.auth.refreshSession({
    refresh_token: user.rawRefreshToken,
  });
  
  if (refreshError) {
    console.error('Supabase refreshSession error:', refreshError.message);
    return c.json({ error: 'Failed to refresh session', message: 'セッションの更新に失敗しました' }, 500);
  }
  
  if (!session) {
    return c.json({ error: 'No session found', message: 'セッションが見つかりません' }, 500);
  }
  
  // Update the stored refresh token with the new one
  if (session.refresh_token) {
    await tokenService.storeRefreshToken(user.id, session.refresh_token);
  }
  
  return c.json({ 
    accessToken: session.access_token,
    refreshToken: session.refresh_token
  });
})

// /me route to get user profile using Supabase token
authRouter.get('/me', validateAuthorization('supabase_token'), async (c) => {
  try {
    const user = c.get('user');

    if (!user) {
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
      const prisma = c.get('prisma');
      
      // Sign out from Supabase
      const { error: signOutError } = await supabase.auth.signOut(); 
      if (signOutError) {
        console.warn('Supabase signOut error (non-critical):', signOutError.message);
      }
      
      // Try to get user info to delete refresh token
      try {
        const { data: { user: supabaseUser } } = await supabase.auth.getUser(token);
        if (supabaseUser?.user_metadata?.prisma_user_id) {
          const prismaUserId = supabaseUser.user_metadata.prisma_user_id as string;
          const tokenService = new TokenService(prisma, c.env.REFRESH_TOKEN_ENCRYPTION_KEY);
          await tokenService.deleteRefreshToken(prismaUserId);
        }
      } catch (error) {
        console.warn('Failed to delete refresh token during logout:', error);
      }
    }
    
    return c.json({ success: true, message: 'Logged out successfully. Please discard your token.' });

  } catch (error) {
    console.error('Logout error:', error);
    return c.json({ error: 'Logout failed', message: 'ログアウト処理中にエラーが発生しました' }, 500);
  }
});