import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";
export const runtime = "nodejs";

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || "";
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "";

function json(body: Record<string, unknown>, status: number) {
  return NextResponse.json(body, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}

async function forwardToPortal(
  request: NextRequest,
  payload: Record<string, unknown>,
) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return json({ ok: false, error: "portal_not_configured" }, 503);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15_000);
  try {
    const forwardedFor = request.headers.get("x-forwarded-for") || "";
    const userAgent = request.headers.get("user-agent") || "halaqah-web";
    const response = await fetch(`${supabaseUrl}/functions/v1/student-portal`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: supabaseAnonKey,
        Authorization: `Bearer ${supabaseAnonKey}`,
        "User-Agent": userAgent,
        ...(forwardedFor ? { "X-Forwarded-For": forwardedFor } : {}),
      },
      body: JSON.stringify(payload),
      cache: "no-store",
      signal: controller.signal,
    });

    const result = await response.json().catch(() => ({
      ok: false,
      error: response.status === 404 ? "portal_not_deployed" : "portal_unavailable",
    }));

    return json(
      typeof result === "object" && result !== null
        ? result as Record<string, unknown>
        : { ok: false, error: "portal_unavailable" },
      response.status,
    );
  } catch (error) {
    const timedOut = error instanceof Error && error.name === "AbortError";
    return json(
      { ok: false, error: timedOut ? "portal_timeout" : "portal_unavailable" },
      timedOut ? 504 : 503,
    );
  } finally {
    clearTimeout(timeout);
  }
}

export async function POST(request: NextRequest) {
  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
  } catch {
    return json({ ok: false, error: "invalid_request" }, 400);
  }
  return forwardToPortal(request, payload);
}

// Public, read-only readiness probe. The Edge Function returns only contract
// booleans; no student data, session token, key, or secret is exposed.
export async function GET(request: NextRequest) {
  return forwardToPortal(request, { action: "health" });
}
