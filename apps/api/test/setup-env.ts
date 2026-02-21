process.env.PORT = process.env.PORT ?? "3001";
process.env.API_BASE_URL = process.env.API_BASE_URL ?? "http://localhost:3001";
process.env.PUBLIC_WEB_BASE_URL = process.env.PUBLIC_WEB_BASE_URL ?? "http://localhost:3001";
process.env.SUPABASE_URL = process.env.SUPABASE_URL ?? "https://example.supabase.co";
process.env.SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY ?? "anon-key";
process.env.SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "service-role-key";
process.env.GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID ?? "google-client-id";
process.env.GOOGLE_CLIENT_SECRET = process.env.GOOGLE_CLIENT_SECRET ?? "google-client-secret";
process.env.GOOGLE_OAUTH_REDIRECT_URL =
  process.env.GOOGLE_OAUTH_REDIRECT_URL ?? "http://localhost:3001/v1/google/oauth/callback";
process.env.GOOGLE_OAUTH_SCOPES =
  process.env.GOOGLE_OAUTH_SCOPES ??
  "https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/tasks";
process.env.TOKEN_ENCRYPTION_KEY =
  process.env.TOKEN_ENCRYPTION_KEY ?? "01234567890123456789012345678901";
process.env.IOS_OAUTH_CALLBACK_SCHEME = process.env.IOS_OAUTH_CALLBACK_SCHEME ?? "omni";
process.env.GEMINI_MODEL = process.env.GEMINI_MODEL ?? "gemini-2.0-flash";
delete process.env.GEMINI_API_KEY;
