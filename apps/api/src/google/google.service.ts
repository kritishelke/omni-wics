import {
  BadRequestException,
  Injectable,
  NotFoundException,
  UnauthorizedException
} from "@nestjs/common";
import { createTaskRequestSchema, TaskDTO } from "@omni/shared";
import { randomUUID } from "crypto";
import { OAuth2Client } from "google-auth-library";
import { calendar_v3, google, tasks_v1 } from "googleapis";
import { z } from "zod";
import { getEnv } from "../common/env";
import { TokenCryptoService } from "../common/token-crypto.service";
import { SupabaseService } from "../supabase/supabase.service";

const oauthStateSchema = z.object({
  u: z.string().uuid(),
  n: z.string(),
  ts: z.number(),
  cb: z.string().optional()
});

const startOAuthBodySchema = z.object({
  callbackScheme: z.string().optional()
});

@Injectable()
export class GoogleService {
  private readonly env = getEnv();
  private readonly scopes = this.env.GOOGLE_OAUTH_SCOPES.split(/\s+/).filter(Boolean);

  constructor(
    private readonly supabaseService: SupabaseService,
    private readonly tokenCryptoService: TokenCryptoService
  ) {}

  parseStartBody(payload: unknown) {
    return startOAuthBodySchema.parse(payload ?? {});
  }

  getOAuthStartUrl(userId: string, callbackScheme?: string): string {
    const state = this.buildState(userId, callbackScheme);
    const client = this.buildOAuthClient();

    return client.generateAuthUrl({
      access_type: "offline",
      prompt: "consent",
      include_granted_scopes: true,
      scope: this.scopes,
      state
    });
  }

  async handleOAuthCallback(code: string, state: string): Promise<string> {
    const parsedState = this.verifyState(state);
    const callbackScheme = parsedState.cb ?? this.env.IOS_OAUTH_CALLBACK_SCHEME;

    const client = this.buildOAuthClient();
    const { tokens } = await client.getToken(code);

    if (!tokens.access_token) {
      throw new UnauthorizedException("Google OAuth did not return an access token");
    }

    const googleSub = this.getGoogleSubFromIdToken(tokens.id_token ?? undefined);

    const { error } = await this.supabaseService.admin.from("google_connections").upsert(
      {
        user_id: parsedState.u,
        google_sub: googleSub,
        scopes: tokens.scope ?? this.scopes.join(" "),
        access_token_enc: this.tokenCryptoService.encrypt(tokens.access_token),
        refresh_token_enc: tokens.refresh_token
          ? this.tokenCryptoService.encrypt(tokens.refresh_token)
          : null,
        expiry_ts: tokens.expiry_date ? new Date(tokens.expiry_date).toISOString() : null,
        updated_at: new Date().toISOString()
      },
      {
        onConflict: "user_id",
        ignoreDuplicates: false
      }
    );

    if (error) {
      throw new Error(`Failed to persist Google connection: ${error.message}`);
    }

    return this.buildCallbackUrl(callbackScheme, true);
  }

  buildCallbackUrl(base: string, success: boolean, message?: string): string {
    if (base.startsWith("http://") || base.startsWith("https://")) {
      const url = new URL(base);
      url.searchParams.set("success", success ? "1" : "0");
      if (message) {
        url.searchParams.set("message", message);
      }
      return url.toString();
    }

    const callbackBase = `${base}://oauth/google`;
    const query = new URLSearchParams({ success: success ? "1" : "0" });
    if (message) {
      query.set("message", message);
    }
    return `${callbackBase}?${query.toString()}`;
  }

  oauthCallbackHtml(redirectUrl: string): string {
    return `<!doctype html>
<html>
  <head><meta charset="utf-8"><title>Omni Google Connect</title></head>
  <body>
    <p>Returning to Omni...</p>
    <script>window.location.href = ${JSON.stringify(redirectUrl)};</script>
    <a href="${redirectUrl}">Continue</a>
  </body>
</html>`;
  }

  async getCalendarEventsForDate(userId: string, date: string) {
    const dayStart = new Date(`${date}T00:00:00.000Z`);
    const dayEnd = new Date(`${date}T23:59:59.999Z`);

    if (Number.isNaN(dayStart.valueOf()) || Number.isNaN(dayEnd.valueOf())) {
      throw new BadRequestException("date must be YYYY-MM-DD");
    }

    const client = await this.getAuthorizedClient(userId);
    const calendarApi = google.calendar({ version: "v3", auth: client });

    const { data } = await calendarApi.events.list({
      calendarId: "primary",
      timeMin: dayStart.toISOString(),
      timeMax: dayEnd.toISOString(),
      singleEvents: true,
      orderBy: "startTime"
    });

    const items = data.items ?? [];
    const normalized = items
      .filter((event) => event.id && (event.start?.dateTime || event.start?.date))
      .map((event) => this.normalizeCalendarEvent(event));

    if (normalized.length > 0) {
      const { error } = await this.supabaseService.admin.from("calendar_events_cache").upsert(
        normalized.map((event) => ({
          user_id: userId,
          source_id: event.sourceId,
          start_at: event.startAt,
          end_at: event.endAt,
          title: event.title,
          location: event.location ?? null,
          raw: event
        })),
        { onConflict: "user_id,source_id" }
      );

      if (error) {
        throw new Error(`Failed to cache calendar events: ${error.message}`);
      }
    }

    await this.persistLatestCredentials(userId, client);
    return normalized;
  }

  async getTaskLists(userId: string) {
    const client = await this.getAuthorizedClient(userId);
    const tasksApi = google.tasks({ version: "v1", auth: client });

    const { data } = await tasksApi.tasklists.list({ maxResults: 100 });
    const items = data.items ?? [];

    const normalized = items
      .filter((list) => list.id && list.title)
      .map((list) => ({
        id: list.id as string,
        title: list.title as string,
        raw: list
      }));

    if (normalized.length > 0) {
      const { error } = await this.supabaseService.admin.from("task_lists").upsert(
        normalized.map((list) => ({
          user_id: userId,
          google_tasklist_id: list.id,
          title: list.title,
          raw: list.raw
        })),
        { onConflict: "user_id,google_tasklist_id" }
      );

      if (error) {
        throw new Error(`Failed to cache task lists: ${error.message}`);
      }
    }

    await this.persistLatestCredentials(userId, client);
    return normalized;
  }

  async getTasks(userId: string, taskListId?: string, includeCompleted = false): Promise<TaskDTO[]> {
    const client = await this.getAuthorizedClient(userId);
    const tasksApi = google.tasks({ version: "v1", auth: client });

    const resolvedTaskListId = taskListId ?? "@default";
    const { data } = await tasksApi.tasks.list({
      tasklist: resolvedTaskListId,
      showCompleted: includeCompleted,
      showHidden: true,
      maxResults: 100
    });

    const items = data.items ?? [];
    const normalized = items
      .filter((task) => task.id && task.title)
      .map((task) => this.normalizeTask(task, resolvedTaskListId));

    if (normalized.length > 0) {
      const { error } = await this.supabaseService.admin.from("tasks_cache").upsert(
        normalized.map((task) => ({
          user_id: userId,
          google_task_id: task.id,
          google_tasklist_id: task.taskListId,
          title: task.title,
          notes: task.notes ?? null,
          due_at: task.dueAt ?? null,
          status: task.status,
          parent_task_id: task.parentTaskId ?? null,
          updated_at: task.updatedAt,
          raw: task
        })),
        { onConflict: "user_id,google_task_id" }
      );

      if (error) {
        throw new Error(`Failed to cache tasks: ${error.message}`);
      }
    }

    await this.persistLatestCredentials(userId, client);
    return normalized;
  }

  async completeTask(userId: string, taskId: string): Promise<TaskDTO> {
    const { data: cachedTask } = await this.supabaseService.admin
      .from("tasks_cache")
      .select("google_tasklist_id")
      .eq("user_id", userId)
      .eq("google_task_id", taskId)
      .maybeSingle();

    const taskListId = cachedTask?.google_tasklist_id ?? "@default";

    const client = await this.getAuthorizedClient(userId);
    const tasksApi = google.tasks({ version: "v1", auth: client });

    const getResponse = await tasksApi.tasks.get({ tasklist: taskListId, task: taskId });
    const existingTask = getResponse.data;

    const updateResponse = await tasksApi.tasks.update({
      tasklist: taskListId,
      task: taskId,
      requestBody: {
        ...existingTask,
        status: "completed",
        completed: new Date().toISOString()
      }
    });

    const normalized = this.normalizeTask(updateResponse.data, taskListId);

    const { error } = await this.supabaseService.admin.from("tasks_cache").upsert(
      {
        user_id: userId,
        google_task_id: normalized.id,
        google_tasklist_id: normalized.taskListId,
        title: normalized.title,
        notes: normalized.notes ?? null,
        due_at: normalized.dueAt ?? null,
        status: normalized.status,
        parent_task_id: normalized.parentTaskId ?? null,
        updated_at: normalized.updatedAt,
        raw: normalized
      },
      { onConflict: "user_id,google_task_id" }
    );

    if (error) {
      throw new Error(`Failed to cache completed task: ${error.message}`);
    }

    await this.persistLatestCredentials(userId, client);
    return normalized;
  }

  async createTask(
    userId: string,
    payload: z.infer<typeof createTaskRequestSchema>
  ): Promise<TaskDTO> {
    const input = createTaskRequestSchema.parse(payload);
    const taskListId = input.taskListId ?? "@default";

    const client = await this.getAuthorizedClient(userId);
    const tasksApi = google.tasks({ version: "v1", auth: client });

    const response = await tasksApi.tasks.insert({
      tasklist: taskListId,
      requestBody: {
        title: input.title,
        notes: input.notes,
        due: input.dueAt
      }
    });

    const normalized = this.normalizeTask(response.data, taskListId);

    const { error } = await this.supabaseService.admin.from("tasks_cache").upsert(
      {
        user_id: userId,
        google_task_id: normalized.id,
        google_tasklist_id: normalized.taskListId,
        title: normalized.title,
        notes: normalized.notes ?? null,
        due_at: normalized.dueAt ?? null,
        status: normalized.status,
        parent_task_id: normalized.parentTaskId ?? null,
        updated_at: normalized.updatedAt,
        raw: normalized
      },
      { onConflict: "user_id,google_task_id" }
    );

    if (error) {
      throw new Error(`Failed to cache created task: ${error.message}`);
    }

    await this.persistLatestCredentials(userId, client);
    return normalized;
  }

  async deleteConnection(userId: string): Promise<void> {
    const { error } = await this.supabaseService.admin
      .from("google_connections")
      .delete()
      .eq("user_id", userId);

    if (error) {
      throw new Error(`Failed to delete Google connection: ${error.message}`);
    }
  }

  private normalizeCalendarEvent(event: calendar_v3.Schema$Event) {
    const startRaw = event.start?.dateTime ?? `${event.start?.date}T00:00:00.000Z`;
    const endRaw = event.end?.dateTime ?? `${event.end?.date}T00:00:00.000Z`;

    return {
      sourceId: event.id ?? randomUUID(),
      startAt: new Date(startRaw).toISOString(),
      endAt: new Date(endRaw).toISOString(),
      title: event.summary ?? "Untitled Event",
      location: event.location ?? null,
      isHardConstraint: true as const
    };
  }

  private normalizeTask(task: tasks_v1.Schema$Task, taskListId: string): TaskDTO {
    if (!task.id || !task.title) {
      throw new BadRequestException("Task missing id or title");
    }

    return {
      id: task.id,
      taskListId,
      title: task.title,
      notes: task.notes ?? null,
      dueAt: task.due ? new Date(task.due).toISOString() : null,
      status: task.status === "completed" ? "completed" : "needsAction",
      parentTaskId: task.parent ?? null,
      updatedAt: task.updated ? new Date(task.updated).toISOString() : new Date().toISOString(),
      source: "google"
    };
  }

  private async getAuthorizedClient(userId: string): Promise<OAuth2Client> {
    const { data, error } = await this.supabaseService.admin
      .from("google_connections")
      .select("access_token_enc, refresh_token_enc, expiry_ts")
      .eq("user_id", userId)
      .maybeSingle();

    if (error) {
      throw new Error(`Failed to load Google connection: ${error.message}`);
    }

    if (!data?.access_token_enc) {
      throw new NotFoundException("Google account is not connected");
    }

    const accessToken = this.tokenCryptoService.decrypt(data.access_token_enc);
    const refreshToken = data.refresh_token_enc
      ? this.tokenCryptoService.decrypt(data.refresh_token_enc)
      : undefined;

    const client = this.buildOAuthClient();
    client.setCredentials({
      access_token: accessToken,
      refresh_token: refreshToken,
      expiry_date: data.expiry_ts ? new Date(data.expiry_ts).getTime() : undefined
    });

    return client;
  }

  private async persistLatestCredentials(userId: string, client: OAuth2Client): Promise<void> {
    const credentials = client.credentials;

    if (!credentials.access_token) {
      return;
    }

    const payload: Record<string, unknown> = {
      access_token_enc: this.tokenCryptoService.encrypt(credentials.access_token),
      updated_at: new Date().toISOString()
    };

    if (credentials.refresh_token) {
      payload.refresh_token_enc = this.tokenCryptoService.encrypt(credentials.refresh_token);
    }

    if (credentials.expiry_date) {
      payload.expiry_ts = new Date(credentials.expiry_date).toISOString();
    }

    const { error } = await this.supabaseService.admin
      .from("google_connections")
      .update(payload)
      .eq("user_id", userId);

    if (error) {
      throw new Error(`Failed to persist refreshed Google credentials: ${error.message}`);
    }
  }

  private buildOAuthClient(): OAuth2Client {
    return new google.auth.OAuth2(
      this.env.GOOGLE_CLIENT_ID,
      this.env.GOOGLE_CLIENT_SECRET,
      this.env.GOOGLE_OAUTH_REDIRECT_URL
    );
  }

  private buildState(userId: string, callbackScheme?: string): string {
    const payload = oauthStateSchema.parse({
      u: userId,
      n: randomUUID(),
      ts: Date.now(),
      cb: callbackScheme
    });

    const encodedPayload = Buffer.from(JSON.stringify(payload), "utf8").toString("base64url");
    const signature = this.tokenCryptoService.signStatePayload(encodedPayload);

    return `${encodedPayload}.${signature}`;
  }

  private verifyState(state: string) {
    const [encodedPayload, signature] = state.split(".");

    if (!encodedPayload || !signature) {
      throw new BadRequestException("Invalid OAuth state");
    }

    const expected = this.tokenCryptoService.signStatePayload(encodedPayload);
    if (signature !== expected) {
      throw new BadRequestException("Invalid OAuth state signature");
    }

    const payloadText = Buffer.from(encodedPayload, "base64url").toString("utf8");
    const payload = oauthStateSchema.parse(JSON.parse(payloadText));

    const ageMs = Date.now() - payload.ts;
    if (ageMs > 15 * 60 * 1000) {
      throw new BadRequestException("OAuth state expired");
    }

    return payload;
  }

  private getGoogleSubFromIdToken(idToken?: string): string | null {
    if (!idToken) {
      return null;
    }

    const parts = idToken.split(".");
    if (parts.length < 2) {
      return null;
    }

    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as {
      sub?: string;
    };

    return payload.sub ?? null;
  }
}
