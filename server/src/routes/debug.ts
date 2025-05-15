import { Hono } from 'hono';
import { Bindings } from '../types/index';
import { SignJWT } from 'jose';

export const debugRouter = new Hono<{ Bindings: Bindings, Variables: Variables }>();

debugRouter.get('/issue-token', async (c) => {
    // Use the predefined string secret, encoded to Uint8Array for 'jose'
    const secretKey = new TextEncoder().encode(c.env.SERVER_API_KEY_SECRET);
    const token = await new SignJWT({ sub: 'server-api-key' })
        .setProtectedHeader({ alg: 'HS256' })
        .setIssuedAt()
        .sign(secretKey);
    // Return the original string secret for easy storage/reuse during debugging
    return c.json({ token, secret: c.env.SERVER_API_KEY_SECRET });
});
