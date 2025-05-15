import { Hono, MiddlewareHandler } from "hono";
import * as jose from 'jose';
import { Bindings } from "../../types";

export const validateAuthorizationWithApiKey: MiddlewareHandler<{ Bindings: Bindings }> = async (c, next) => {
        const authorizationHeader = c.req.header('Authorization');
        if (!authorizationHeader) {
            return c.json({ error: 'Unauthorized' }, 401);
        }
        const token = authorizationHeader.split(' ')[1];
        if (!token) {
            return c.json({ error: 'Unauthorized' }, 401);
        }
        const secretKey = new TextEncoder().encode(c.env.SERVER_API_KEY_SECRET);
        const { payload, protectedHeader } = await jose.jwtVerify(token, secretKey, {
            algorithms: ['HS256'],
        });
        if (!payload) {
            return c.json({ error: 'Unauthorized' }, 401);
        }
        await next();
}