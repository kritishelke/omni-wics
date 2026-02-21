import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException
} from "@nestjs/common";
import { RequestWithUser } from "../common/request-user";
import { ProfileService } from "../profile/profile.service";
import { SupabaseService } from "../supabase/supabase.service";

@Injectable()
export class SupabaseAuthGuard implements CanActivate {
  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly profileService: ProfileService
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<RequestWithUser>();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      throw new UnauthorizedException("Missing bearer token");
    }

    const token = authHeader.replace("Bearer ", "").trim();
    if (!token) {
      throw new UnauthorizedException("Missing bearer token");
    }

    const user = await this.supabaseService.verifyUserFromJwt(token);
    request.user = user;
    await this.profileService.ensureProfile(user.id);

    return true;
  }
}
