import { PrismaClient } from '@prisma/client';
import { EncryptionService } from './encryption';

export class TokenService {
  private prisma: PrismaClient;
  private encryptionService: EncryptionService;

  constructor(prisma: PrismaClient, encryptionKey: string) {
    this.prisma = prisma;
    this.encryptionService = new EncryptionService(encryptionKey);
  }

  /**
   * Store a user refresh token with encryption
   */
  async storeRefreshToken(userId: string, token: string) {
    // Encrypt the token before storing
    const encryptedToken = this.encryptionService.encrypt(token);

    // First check if user already has a refresh token
    const existingToken = await this.prisma.userRefreshToken.findFirst({
      where: { userId },
    });

    if (existingToken) {
      // Update the existing token
      return this.prisma.userRefreshToken.update({
        where: { id: existingToken.id },
        data: {
          token: encryptedToken,
          updatedAt: new Date(),
        },
      });
    } else {
      return this.prisma.userRefreshToken.create({
        data: {
          userId,
          token: encryptedToken,
          user: {
            connect: { id: userId }
          }
        },
      });
    }
  }

  /**
   * Find a token by its encrypted value
   */
  async findTokenByValue(tokenValue: string) {
    const allTokens = await this.prisma.userRefreshToken.findMany();
    
    // We need to decrypt each token to find a match
    for (const storedToken of allTokens) {
      try {
        const decryptedToken = this.encryptionService.decrypt(storedToken.token);
        if (decryptedToken === tokenValue) {
          return {
            ...storedToken,
            decryptedToken,
          };
        }
      } catch (error) {
        console.error('Error decrypting token:', error);
        // Continue checking other tokens
      }
    }
    
    return null;
  }

  /**
   * Delete a user's refresh token
   */
  async deleteRefreshToken(userId: string) {
    const token = await this.prisma.userRefreshToken.findFirst({
      where: { userId },
    });

    if (token) {
      // Delete token - this should automatically set the user's refreshTokenId to null
      return this.prisma.userRefreshToken.delete({
        where: { id: token.id },
      });
    }

    return null;
  }
} 