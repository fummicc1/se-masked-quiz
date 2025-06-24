import { Context, Next } from 'hono';
import { verifyJWT } from '../utils/jwt-cf';
import type { Env } from '../types/env';

export async function authMiddleware(c: Context<{ Bindings: Env }>, next: Next) {
  const authHeader = c.req.header('Authorization');
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return c.json({ error: 'Unauthorized' }, 401);
  }
  
  const token = authHeader.substring(7);
  
  try {
    const payload = await verifyJWT(token, c.env.JWT_SECRET);
    c.set('userId', payload.sub);
    c.set('userEmail', payload.email);
    await next();
  } catch (error) {
    return c.json({ error: 'Invalid token' }, 401);
  }
}