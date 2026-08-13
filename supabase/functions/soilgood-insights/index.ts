// SoilGood insights API. Groq key stays in Dashboard secrets — never in the APK.
// No npm imports (those 500 on this Edge runtime). JWT via Auth REST. CORS on every response.
// insights.json is imported so the deploy bundle includes it (readTextFile 500s on Edge).

import insightsJson from "./insights.json" with { type: "json" };

const insights = insightsJson as Record<string, unknown>;

const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const model = "llama-3.3-70b-versatile";
const jobs = new Set(["home", "analytics", "crops.care"]);

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });
}

function promptAt(prompts: Record<string, unknown>, job: string): unknown {
  let cur: unknown = prompts;
  for (const part of job.split(".")) {
    if (cur === null || typeof cur !== "object") return null;
    cur = (cur as Record<string, unknown>)[part];
  }
  return cur;
}

/** Page slice only — never meta, sensor_valid, regen, or other pages. */
function slice(
  insights: Record<string, unknown>,
  job: string,
): Record<string, unknown> {
  const prompts = (insights.prompts ?? {}) as Record<string, unknown>;
  const out: Record<string, unknown> = {
    voice: insights.voice,
    output: insights.output,
    bands: insights.bands,
    prompt: promptAt(prompts, job),
  };
  if (job === "home" || job === "crops.care") {
    out.irrigation = insights.irrigation;
  }
  return out;
}

function hasLiveInput(
  job: string,
  payload: Record<string, unknown>,
): boolean {
  if (job === "analytics") {
    const history = payload.history as { days?: unknown } | undefined;
    return Array.isArray(history?.days) && history.days.length > 0;
  }
  const facts = payload.facts as { soil_reading_id?: unknown } | undefined;
  return typeof facts?.soil_reading_id === "string" &&
    facts.soil_reading_id.length > 0;
}

async function requireUser(
  auth: string,
  supabaseUrl: string,
  anon: string,
): Promise<boolean> {
  const res = await fetch(`${supabaseUrl}/auth/v1/user`, {
    headers: {
      Authorization: auth,
      apikey: anon,
    },
  });
  if (!res.ok) return false;
  const json = await res.json() as { id?: unknown };
  return typeof json.id === "string" && json.id.length > 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: cors });
  }

  try {
    return await handlePost(req);
  } catch (err) {
    return jsonResponse({ error: "internal", message: String(err) }, 500);
  }
});

async function handlePost(req: Request): Promise<Response> {
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }

  const auth = req.headers.get("Authorization") ?? "";
  if (!auth.startsWith("Bearer ")) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  const url = Deno.env.get("SUPABASE_URL") ?? "";
  const anon = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
  if (!url || !anon) {
    return jsonResponse({ error: "missing_supabase_env" }, 500);
  }

  if (!await requireUser(auth, url, anon)) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let body: { job?: string; payload?: Record<string, unknown> };
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const job = (body.job ?? "").trim();
  if (!jobs.has(job)) {
    return jsonResponse({ error: "unknown_job", jobs: [...jobs] }, 400);
  }

  const payload = body.payload ?? {};
  if (!hasLiveInput(job, payload)) {
    return jsonResponse({
      error: "no_reading",
      message: "No soil data yet — Groq was not called.",
    }, 400);
  }

  const groqKey = Deno.env.get("GROQ_API_KEY")?.trim() ?? "";
  if (!groqKey) {
    return jsonResponse({
      error: "missing_groq_key",
      message: "Set GROQ_API_KEY in Edge Function secrets.",
    }, 503);
  }

  const configSlice = slice(insights, job);

  const systemPrompt =
    "You are SoilGood for Philippine smallholder farmers. Follow config JSON. " +
    "Reply with JSON only: overview (2-4 sentences), soil_health_score (0-100), " +
    "recommendations[{type,title,description,recommended_action,priority}]. " +
    "No markdown. Do not invent numbers.";

  const ac = new AbortController();
  const timer = setTimeout(() => ac.abort(), 20_000);
  let groqRes: Response;
  try {
    groqRes = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${groqKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model,
        temperature: 0.3,
        response_format: { type: "json_object" },
        messages: [
          {
            role: "system",
            content: `${systemPrompt}\n${JSON.stringify(configSlice)}`,
          },
          { role: "user", content: JSON.stringify(payload) },
        ],
      }),
      signal: ac.signal,
    });
  } catch (err) {
    return jsonResponse({
      error: "groq_timeout",
      message: String(err),
    }, 504);
  } finally {
    clearTimeout(timer);
  }

  if (!groqRes.ok) {
    const errText = await groqRes.text();
    return jsonResponse({
      error: "groq_failed",
      status: groqRes.status,
      detail: errText.slice(0, 500),
    }, 502);
  }

  const groqJson = await groqRes.json() as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = groqJson.choices?.[0]?.message?.content;
  if (typeof content !== "string" || !content.trim()) {
    return jsonResponse({ error: "empty_groq" }, 502);
  }

  try {
    const parsed = JSON.parse(content) as unknown;
    if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) {
      return jsonResponse({ error: "invalid_groq_json" }, 502);
    }
    return jsonResponse(parsed);
  } catch {
    return jsonResponse({ error: "invalid_groq_json" }, 502);
  }
}
