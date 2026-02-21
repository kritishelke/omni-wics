import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  Req,
  Res,
  UseGuards
} from "@nestjs/common";
import { createTaskRequestSchema } from "@omni/shared";
import { Response } from "express";
import { CurrentUser } from "../auth/current-user.decorator";
import { SupabaseAuthGuard } from "../auth/supabase-auth.guard";
import { createZodDto } from "../common/zod.dto";
import { GoogleService } from "./google.service";

class CreateTaskBody extends createZodDto(createTaskRequestSchema) {}

@Controller("google")
export class GoogleController {
  constructor(private readonly googleService: GoogleService) {}

  @Post("oauth/start")
  @UseGuards(SupabaseAuthGuard)
  async startOauth(
    @CurrentUser() user: { id: string },
    @Body() body: { callbackScheme?: string }
  ) {
    const parsed = this.googleService.parseStartBody(body);
    const url = this.googleService.getOAuthStartUrl(user.id, parsed.callbackScheme);
    return { url };
  }

  @Get("oauth/callback")
  async oauthCallback(
    @Query("code") code: string,
    @Query("state") state: string,
    @Query("error") error: string | undefined,
    @Res() res: Response
  ) {
    try {
      if (error) {
        const redirect = this.googleService.buildCallbackUrl("omni", false, error);
        return res.status(400).send(this.googleService.oauthCallbackHtml(redirect));
      }

      if (!code || !state) {
        const redirect = this.googleService.buildCallbackUrl("omni", false, "missing_code_or_state");
        return res.status(400).send(this.googleService.oauthCallbackHtml(redirect));
      }

      const redirectUrl = await this.googleService.handleOAuthCallback(code, state);
      return res.status(200).send(this.googleService.oauthCallbackHtml(redirectUrl));
    } catch (e) {
      const message = e instanceof Error ? e.message : "oauth_failed";
      const redirect = this.googleService.buildCallbackUrl("omni", false, message);
      return res.status(400).send(this.googleService.oauthCallbackHtml(redirect));
    }
  }

  @Get("calendar/events")
  @UseGuards(SupabaseAuthGuard)
  async getCalendarEvents(@CurrentUser() user: { id: string }, @Query("date") date: string) {
    return this.googleService.getCalendarEventsForDate(user.id, date);
  }

  @Get("tasks/lists")
  @UseGuards(SupabaseAuthGuard)
  async getTaskLists(@CurrentUser() user: { id: string }) {
    return this.googleService.getTaskLists(user.id);
  }

  @Get("tasks")
  @UseGuards(SupabaseAuthGuard)
  async getTasks(
    @CurrentUser() user: { id: string },
    @Query("taskListId") taskListId?: string,
    @Query("includeCompleted") includeCompleted?: string
  ) {
    return this.googleService.getTasks(
      user.id,
      taskListId,
      includeCompleted === "1" || includeCompleted === "true"
    );
  }

  @Post("tasks/:taskId/complete")
  @UseGuards(SupabaseAuthGuard)
  async completeTask(@CurrentUser() user: { id: string }, @Param("taskId") taskId: string) {
    const task = await this.googleService.completeTask(user.id, taskId);
    return {
      ok: true as const,
      task
    };
  }

  @Post("tasks/create")
  @UseGuards(SupabaseAuthGuard)
  async createTask(@CurrentUser() user: { id: string }, @Body() body: CreateTaskBody) {
    return this.googleService.createTask(user.id, body);
  }
}
