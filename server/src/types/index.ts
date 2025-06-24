export interface AppleTokenPayload {
  iss: string;
  aud: string;
  exp: number;
  iat: number;
  sub: string;
  nonce?: string;
  nonce_supported?: boolean;
  email?: string;
  email_verified?: boolean | string;
  is_private_email?: boolean | string;
  real_user_status?: number;
  transfer_sub?: string;
  at_hash?: string;
  auth_time?: number;
}

export interface AppleUser {
  id: string;
  email?: string;
  emailVerified?: boolean;
  isPrivateEmail?: boolean;
  realUserStatus?: number;
  createdAt: Date;
  updatedAt: Date;
}

export interface JWTPayload {
  sub: string;
  email?: string;
  iat: number;
  exp: number;
}

export interface ApplePublicKey {
  kty: string;
  kid: string;
  use: string;
  alg: string;
  n: string;
  e: string;
}