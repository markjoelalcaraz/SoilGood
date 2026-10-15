# SoilGood — Security

## Principles (fit for now)
Practical measures for Flutter + Supabase + ESP32. Avoid over-engineering; do the basics correctly.

## Checklist

### Secrets
- Never hardcode API keys or secrets in source or git.
- Use env / secure config (e.g. `.env` + gitignore).
- App may use Supabase **anon** key only — never ship **service_role** in the Flutter client.
- Groq `GROQ_API_KEY` is an Edge Function secret only — never in Flutter `.env` or the APK.

### Row Level Security (RLS)
- Enable **RLS** on all Supabase tables.
- Policies: users only access their own farm/device data.
- Without RLS, anyone with the anon key can abuse data.

### Authentication
- Prefer Supabase Auth when multi-user is required.
- Decide early: multi-farmer accounts vs single-user prototype — RLS depends on this.
- **Signup password:** at least 8 characters, plus a letter, a number, and a symbol. Enforced in the app (`AppValidators`) before `signUp` and before saving a reset password. Login does **not** re-check strength (existing accounts may predate the rule).
- **Forgot password:** `resetPasswordForEmail` sends a link. The redirect origin (for local Chrome, `http://localhost:<port>`) must be listed under Supabase Auth → URL Configuration → Redirect URLs. The app does not reveal whether the email has an account.
- **Signup email:** must look like `name@domain.tld` (not merely contain `@` and `.`).

### Device (ESP32)
- Device must not use **service_role** (that key bypasses RLS and can drop data).
- ESP32 uses **anon** key + `ingest_token` and calls RPC `ingest_soil_reading` only.
- Do not commit `firmware/**/secrets.h` (anon key, WiFi, token).
- **Claim:** lab/admin pre-provisions `devices` via Flutter web Admin (`admin_provision_device`) or SQL. Farmers call RPC `claim_device(claim_code)` only — they never see or copy `ingest_token`. App clients cannot INSERT into `devices` (policy dropped). See [`supabase_device_claim.sql`](supabase_device_claim.sql), [`supabase_admin.sql`](supabase_admin.sql).
- Unclaimed rows have `farm_id` null and are invisible under normal RLS; only the claim RPC (security definer) can attach them.
- **Admin:** `profiles.role = admin` unlocks AdminShell on web. Admin RPCs check `is_admin()` — never put **service_role** in Flutter web. Promote a user only after signup (commented SQL in `supabase_admin.sql`).

### Validation
- Validate sensor ranges (e.g. pH 0–14, moisture 0–100%, salinity 0–50 ppt). Out-of-range = visible sensor error (no silent accept).

### Transport & tokens
- HTTPS only (Supabase default).
- Store auth tokens with secure storage when Auth is enabled.

## Out of scope for early development
Complex RBAC, full audit trails, custom crypto, formal pen-tests — revisit for production hardening.
