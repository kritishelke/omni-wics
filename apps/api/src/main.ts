import "dotenv/config";
import "reflect-metadata";
import { Logger } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import { getEnv } from "./common/env";
import { GlobalHttpExceptionFilter } from "./common/http-exception.filter";
import { ZodValidationPipe } from "./common/zod-validation.pipe";
import { AppModule } from "./app.module";

async function bootstrap() {
  const env = getEnv();
  const app = await NestFactory.create(AppModule, { cors: true });

  app.setGlobalPrefix("v1");
  app.useGlobalPipes(new ZodValidationPipe());
  app.useGlobalFilters(new GlobalHttpExceptionFilter());

  await app.listen(env.PORT);
  Logger.log(`API listening on http://localhost:${env.PORT}/v1`);
}

void bootstrap();
