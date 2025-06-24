import { importSPKI, jwtVerify } from 'jose';
import { eq } from 'drizzle-orm';
import type { AppleTokenPayload, ApplePublicKey } from '../types';
import type { Database } from '../db';
import { users, type User, type NewUser } from '../db/schema';
import type { Env } from '../types/env';

export class AppleAuthService {
  private static APPLE_ISSUER = 'https://appleid.apple.com';
  private static APPLE_PUBLIC_KEY_URL = 'https://appleid.apple.com/auth/keys';
  private static CACHE_KEY = 'apple-public-keys';
  private static CACHE_TTL = 86400; // 24 hours

  constructor(
    private db: Database,
    private cache: KVNamespace,
    private serviceId: string
  ) {}

  async fetchApplePublicKeys(): Promise<Map<string, CryptoKey>> {
    // Try to get from cache first
    const cached = await this.cache.get(AppleAuthService.CACHE_KEY, 'json');
    if (cached) {
      const keys = new Map<string, CryptoKey>();
      for (const [kid, keyData] of Object.entries(cached as Record<string, any>)) {
        const key = await crypto.subtle.importKey(
          'jwk',
          keyData,
          { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
          false,
          ['verify']
        );
        keys.set(kid, key);
      }
      return keys;
    }

    // Fetch from Apple
    const response = await fetch(AppleAuthService.APPLE_PUBLIC_KEY_URL);
    const data = await response.json();
    
    const keys = new Map<string, CryptoKey>();
    const cacheData: Record<string, any> = {};
    
    for (const key of data.keys as ApplePublicKey[]) {
      const jwk = {
        kty: key.kty,
        n: key.n,
        e: key.e,
        alg: key.alg,
        use: key.use
      };
      
      const cryptoKey = await crypto.subtle.importKey(
        'jwk',
        jwk,
        { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
        false,
        ['verify']
      );
      
      keys.set(key.kid, cryptoKey);
      cacheData[key.kid] = jwk;
    }
    
    // Cache the keys
    await this.cache.put(
      AppleAuthService.CACHE_KEY,
      JSON.stringify(cacheData),
      { expirationTtl: AppleAuthService.CACHE_TTL }
    );
    
    return keys;
  }

  async verifyIdentityToken(identityToken: string): Promise<AppleTokenPayload> {
    // Decode token header to get kid
    const [headerB64] = identityToken.split('.');
    const header = JSON.parse(atob(headerB64));
    
    const publicKeys = await this.fetchApplePublicKeys();
    const publicKey = publicKeys.get(header.kid);
    
    if (!publicKey) {
      throw new Error('Public key not found');
    }

    try {
      const { payload } = await jwtVerify(identityToken, publicKey, {
        issuer: AppleAuthService.APPLE_ISSUER,
        audience: this.serviceId,
      });
      
      return payload as AppleTokenPayload;
    } catch (error) {
      console.error('Token verification failed:', error);
      throw new Error('Invalid identity token');
    }
  }

  async createOrUpdateUser(tokenPayload: AppleTokenPayload): Promise<User> {
    const existingUsers = await this.db
      .select()
      .from(users)
      .where(eq(users.id, tokenPayload.sub))
      .limit(1);
    
    if (existingUsers.length > 0) {
      // Update existing user
      const updates: Partial<User> = {
        updatedAt: new Date(),
      };
      
      if (tokenPayload.email) {
        updates.email = tokenPayload.email;
        updates.emailVerified = tokenPayload.email_verified === true || tokenPayload.email_verified === 'true';
        updates.isPrivateEmail = tokenPayload.is_private_email === true || tokenPayload.is_private_email === 'true';
      }
      
      await this.db
        .update(users)
        .set(updates)
        .where(eq(users.id, tokenPayload.sub));
      
      return { ...existingUsers[0], ...updates };
    }
    
    // Create new user
    const newUser: NewUser = {
      id: tokenPayload.sub,
      email: tokenPayload.email,
      emailVerified: tokenPayload.email_verified === true || tokenPayload.email_verified === 'true',
      isPrivateEmail: tokenPayload.is_private_email === true || tokenPayload.is_private_email === 'true',
      realUserStatus: tokenPayload.real_user_status,
    };
    
    await this.db.insert(users).values(newUser);
    
    const [createdUser] = await this.db
      .select()
      .from(users)
      .where(eq(users.id, tokenPayload.sub))
      .limit(1);
    
    return createdUser;
  }

  async getUserById(userId: string): Promise<User | undefined> {
    const [user] = await this.db
      .select()
      .from(users)
      .where(eq(users.id, userId))
      .limit(1);
    
    return user;
  }
}