import * as crypto from 'crypto';

/**
 * Service for encrypting and decrypting sensitive data
 */
export class EncryptionService {
  private algorithm = 'aes-256-cbc';
  private secretKey: Buffer;
  private ivLength = 16; // For AES, this is always 16 bytes

  constructor(secretKey: string) {
    // Hash the secret key to ensure it's the right length for AES-256
    this.secretKey = crypto.createHash('sha256').update(secretKey).digest();
  }

  /**
   * Encrypts a string value
   */
  encrypt(text: string): string {
    // Generate a random initialization vector
    const iv = crypto.randomBytes(this.ivLength);
    
    // Create cipher with key and iv
    const cipher = crypto.createCipheriv(this.algorithm, this.secretKey, iv);
    
    // Encrypt the text
    let encrypted = cipher.update(text, 'utf8', 'hex');
    encrypted += cipher.final('hex');
    
    // Return iv + encrypted (iv prepended to ciphertext)
    return iv.toString('hex') + ':' + encrypted;
  }

  /**
   * Decrypts an encrypted string value
   */
  decrypt(encryptedText: string): string {
    // Split iv and encrypted text
    const parts = encryptedText.split(':');
    if (parts.length !== 2) {
      throw new Error('Invalid encrypted format');
    }
    
    const iv = Buffer.from(parts[0], 'hex');
    const encrypted = parts[1];
    
    // Create decipher
    const decipher = crypto.createDecipheriv(this.algorithm, this.secretKey, iv);
    
    // Decrypt
    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');
    
    return decrypted;
  }
} 