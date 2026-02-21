import { Module } from "@nestjs/common";
import { TokenCryptoService } from "../common/token-crypto.service";
import { GoogleController } from "./google.controller";
import { GoogleService } from "./google.service";

@Module({
  controllers: [GoogleController],
  providers: [GoogleService, TokenCryptoService],
  exports: [GoogleService]
})
export class GoogleModule {}
