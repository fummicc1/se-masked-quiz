import { SignJWT, jwtVerify } from 'jose';
import type { JWTPayload } from '../types';

export async function createJWT(
  payload: Omit<JWTPayload, 'iat' | 'exp'>,
  secret: string,
  expiresIn: string = '1d'
): Promise<string> {
  const encoder = new TextEncoder();
  const key = encoder.encode(secret);
  
  const jwt = await new SignJWT(payload)
    .setProtectedHeader({ alg: 'HS256' })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(key);
  
  return jwt;
}

export async function verifyJWT(token: string, secret: string): Promise<JWTPayload> {
  const encoder = new TextEncoder();
  const key = encoder.encode(secret);
  
  const { payload } = await jwtVerify(token, key);
  return payload as JWTPayload;
}