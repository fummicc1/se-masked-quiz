import { Hono, MiddlewareHandler } from "hono";
import * as jose from 'jose';
import { Bindings, AuthenticatedUser } from "../../types";
import { EncryptionService } from "../../services/encryption";

export type AuthStrategy = 'api_key' | 'supabase_token' | 'refresh_token';

export const validateAuthorization = (strategy: AuthStrategy): MiddlewareHandler<{ Bindings: Bindings }> => {
    if (strategy === 'api_key') {
        return validateAuthorizationWithApiKey;
    } else if (strategy === 'supabase_token') {
        return validateAuthorizationWithSupabaseToken;
    } else if (strategy === 'refresh_token') {
        return validateAuthorizationWithRefreshToken;
    }
    throw new Error(`Invalid strategy: ${strategy}`);
}

export const validateAuthorizationWithRefreshToken: MiddlewareHandler<{ Bindings: Bindings }> = async (c, next) => {
    const authorizationHeader = c.req.header('Authorization');
    if (!authorizationHeader) {
        return c.json({ error: 'Unauthorized' }, 401);
    }
    const token = authorizationHeader.split(' ')[1];
    if (!token) {
        return c.json({ error: 'Unauthorized' }, 401);
    }
    const prisma = c.get('prisma');
    
    try {
        // Find all refresh tokens and decrypt them to find a match
        const refreshTokens = await prisma.userRefreshToken.findMany();
        const encryptionService = new EncryptionService(c.env.REFRESH_TOKEN_ENCRYPTION_KEY);
        
        // Find the token by decrypting each stored token and comparing
        const matchingToken = refreshTokens.find(rt => {
            try {
                const decryptedToken = encryptionService.decrypt(rt.token);
                return decryptedToken === token;
            } catch (e) {
                console.error('Error decrypting token:', e);
                return false;
            }
        });
        
        if (!matchingToken) {
            return c.json({ error: 'Unauthorized' }, 401);
        }
        
        const user = await prisma.user.findUnique({
            where: {
                id: matchingToken.userId,
            },
            include: {
                refreshToken: true,
            }
        });
        
        if (!user) {
            return c.json({ error: 'Unauthorized' }, 401);
        }
        
        // Don't modify the original token from database
        // Instead, add the decrypted token as a separate property
        const authenticatedUser: AuthenticatedUser = {
            ...user,
            rawRefreshToken: token // This is the decoded token from Authorization header
        };
        
        c.set('user', authenticatedUser);
        await next();
    } catch (error) {
        console.error('Error validating refresh token:', error);
        return c.json({ error: 'Unauthorized' }, 401);
    }
}

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

export const validateAuthorizationWithSupabaseToken: MiddlewareHandler<{ Bindings: Bindings }> = async (c, next) => {
    const authorizationHeader = c.req.header('Authorization');
    if (!authorizationHeader) {
        return c.json({ error: 'Unauthorized' }, 401);
    }
    const token = authorizationHeader.split(' ')[1];
    if (!token) {
        return c.json({ error: 'Unauthorized' }, 401);
    }
    const supabase = c.get('supabase');
    const prisma = c.get('prisma');
    const { data, error: claimsError } = await supabase.auth.getClaims(token);
    if (claimsError) {
        return c.json({ error: 'Unauthorized' }, 401);
    }
    if (!data?.claims?.email) {
        return c.json({ error: 'Unauthorized' }, 401);
    }
    const user = await prisma.user.findUnique({
        where: {
            email: data?.claims?.email,
        },
        include: {
            refreshToken: true,
        }
    });
    if (!user) {
        return c.json({ error: 'Unauthorized' }, 401);
    }
    c.set('user', user);
    await next();
}