import { Injectable } from "@nestjs/common";
import { createCipheriv, createDecipheriv, createHmac, randomBytes } from "crypto";
import { getEnv } from "./env";

@Injectable()
export class TokenCryptoService {
  private readonly env = getEnv();
  private readonly key: Buffer = this.parseKey(this.env.TOKEN_ENCRYPTION_KEY);

  encrypt(plaintext: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, iv);
    const encrypted = Buffer.concat([cipher.update(plaintext, "utf8"), cipher.final()]);
    const tag = cipher.getAuthTag();

    return `${iv.toString("base64")}.${tag.toString("base64")}.${encrypted.toString("base64")}`;
  }

  decrypt(ciphertext: string): string {
    const [ivB64, tagB64, payloadB64] = ciphertext.split(".");
    if (!ivB64 || !tagB64 || !payloadB64) {
      throw new Error("Invalid encrypted token format");
    }

    const iv = Buffer.from(ivB64, "base64");
    const tag = Buffer.from(tagB64, "base64");
    const encrypted = Buffer.from(payloadB64, "base64");

    const decipher = createDecipheriv("aes-256-gcm", this.key, iv);
    decipher.setAuthTag(tag);

    const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()]);
    return decrypted.toString("utf8");
  }

  signStatePayload(payload: string): string {
    return createHmac("sha256", this.key).update(payload).digest("base64url");
  }

  private parseKey(raw: string): Buffer {
    if (/^[0-9a-fA-F]{64}$/.test(raw)) {
      return Buffer.from(raw, "hex");
    }

    const base64Buffer = Buffer.from(raw, "base64");
    if (base64Buffer.length === 32) {
      return base64Buffer;
    }

    const utf8Buffer = Buffer.from(raw, "utf8");
    if (utf8Buffer.length === 32) {
      return utf8Buffer;
    }

    throw new Error("TOKEN_ENCRYPTION_KEY must be 32 bytes (hex/base64/raw)");
  }
}
