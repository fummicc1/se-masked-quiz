import { Hono } from 'hono';
import { z } from 'zod';
import { AppleAuthService } from '../services/apple-auth-d1';
import { createJWT } from '../utils/jwt-cf';
import { authMiddleware } from '../middleware/auth-cf';
import { createDb } from '../db';
import type { Env } from '../types/env';

const authRouter = new Hono<{ Bindings: Env }>();

// Request validation schemas
const appleSignInSchema = z.object({
  identityToken: z.string(),
  authorizationCode: z.string().optional(),
  user: z.object({
    email: z.string().email().optional(),
    name: z.object({
      firstName: z.string().optional(),
      lastName: z.string().optional(),
    }).optional(),
  }).optional(),
});

// POST /auth/apple - Sign in with Apple
authRouter.post('/apple', async (c) => {
  try {
    const body = await c.req.json();
    const validatedData = appleSignInSchema.parse(body);
    
    // Initialize services
    const db = createDb(c.env.DB);
    const appleAuthService = new AppleAuthService(
      db,
      c.env.CACHE,
      c.env.APPLE_SERVICE_ID
    );
    
    // Verify the identity token
    const tokenPayload = await appleAuthService.verifyIdentityToken(
      validatedData.identityToken
    );
    
    // Create or update user
    const user = await appleAuthService.createOrUpdateUser(tokenPayload);
    
    // Generate JWT
    const jwt = await createJWT(
      {
        sub: user.id,
        email: user.email || undefined,
      },
      c.env.JWT_SECRET,
      c.env.JWT_EXPIRES_IN
    );
    
    return c.json({
      success: true,
      token: jwt,
      user: {
        id: user.id,
        email: user.email,
        emailVerified: user.emailVerified,
        isPrivateEmail: user.isPrivateEmail,
      },
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return c.json({ error: 'Invalid request data', details: error.errors }, 400);
    }
    
    console.error('Apple sign in error:', error);
    return c.json({ error: 'Authentication failed' }, 401);
  }
});

// GET /auth/me - Get current user info
authRouter.get('/me', authMiddleware, async (c) => {
  const userId = c.get('userId');
  
  const db = createDb(c.env.DB);
  const appleAuthService = new AppleAuthService(
    db,
    c.env.CACHE,
    c.env.APPLE_SERVICE_ID
  );
  
  const user = await appleAuthService.getUserById(userId);
  
  if (!user) {
    return c.json({ error: 'User not found' }, 404);
  }
  
  return c.json({
    id: user.id,
    email: user.email,
    emailVerified: user.emailVerified,
    isPrivateEmail: user.isPrivateEmail,
  });
});

// POST /auth/verify - Verify JWT token
authRouter.post('/verify', authMiddleware, async (c) => {
  return c.json({ 
    success: true,
    userId: c.get('userId'),
    email: c.get('userEmail'),
  });
});

export { authRouter };