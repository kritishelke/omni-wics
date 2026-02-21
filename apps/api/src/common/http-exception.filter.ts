import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger
} from "@nestjs/common";
import { Response } from "express";

@Catch()
export class GlobalHttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(GlobalHttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const payload = exception.getResponse();
      this.logger.warn(`${status} ${JSON.stringify(payload)}`);
      response.status(status).json(payload);
      return;
    }

    const message = exception instanceof Error ? exception.message : "Internal server error";
    this.logger.error(message);

    response.status(HttpStatus.INTERNAL_SERVER_ERROR).json({
      message
    });
  }
}
