import { TokenCryptoService } from "../src/common/token-crypto.service";

describe("TokenCryptoService", () => {
  it("encrypts and decrypts a token", () => {
    const service = new TokenCryptoService();
    const raw = "ya29.sample.token";

    const encrypted = service.encrypt(raw);
    expect(encrypted).not.toEqual(raw);

    const decrypted = service.decrypt(encrypted);
    expect(decrypted).toEqual(raw);
  });
});
