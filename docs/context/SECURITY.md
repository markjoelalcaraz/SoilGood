# SoilGood — Security

## Principles (fit for now)
Practical measures for Flutter + Supabase + ESP32. Avoid over-engineering; do the basics correctly.

## Checklist

### Secrets
- Never hardcode API keys or secrets in source or git.
- Use env / secure config (e.g. `.env` + gitignore).
- App may use Supabase **anon** key only — never ship **service_role** in the Flutter client.

### Row Level Security (RLS)
- Enable **RLS** on all Supabase tables.
- Policies: users only access their own farm/device data.
- Without RLS, anyone with the anon key can abuse data.

### Authentication
- Prefer Supabase Auth when multi-user is required.
- Decide early: multi-farmer accounts vs single-user prototype — RLS depends on this.

### Device (ESP32)
- Device must not use service_role.
- Prefer INSERT-only / constrained credentials, or write through a validated Edge Function.

### Validation
- Validate sensor ranges (e.g. pH 0–14, moisture 0–100%). Out-of-range = visible sensor error (no silent accept).

### Transport & tokens
- HTTPS only (Supabase default).
- Store auth tokens with secure storage when Auth is enabled.

## Out of scope for early development
Complex RBAC, full audit trails, custom crypto, formal pen-tests — revisit for production hardening.
