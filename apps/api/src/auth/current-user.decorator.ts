import { createParamDecorator, ExecutionContext } from "@nestjs/common";
import { AuthenticatedUser, RequestWithUser } from "../common/request-user";

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthenticatedUser => {
    const req = ctx.switchToHttp().getRequest<RequestWithUser>();
    return req.user;
  }
);
