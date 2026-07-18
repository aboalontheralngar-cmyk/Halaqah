import { createClient } from 'npm:@supabase/supabase-js@2';

type PortalAction =
  | 'login'
  | 'dashboard'
  | 'logout'
  | 'familyLogin'
  | 'familyDashboard'
  | 'familyLogout';

const portalOrigins = (Deno.env.get('PORTAL_ALLOWED_ORIGINS') || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

function corsHeaders(request: Request): HeadersInit | null {
  const requestOrigin = request.headers.get('origin');
  if (portalOrigins.length > 0 && requestOrigin && !portalOrigins.includes(requestOrigin)) {
    return null;
  }
  return {
    'Access-Control-Allow-Origin': requestOrigin || portalOrigins[0] || '*',
    'Access-Control-Allow-Headers': 'authorization, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Max-Age': '86400',
    'Cache-Control': 'no-store',
    Vary: 'Origin',
  };
}

function jsonResponse(
  body: Record<string, unknown>,
  status: number,
  headers: HeadersInit,
): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json; charset=utf-8' },
  });
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function readClientIp(request: Request): string {
  return (
    request.headers.get('cf-connecting-ip') ||
    request.headers.get('x-real-ip') ||
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ||
    'unknown'
  );
}

function readSupabaseSecretKey(): string | undefined {
  const namedKeys = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (namedKeys) {
    try {
      const parsed = JSON.parse(namedKeys) as Record<string, string>;
      return parsed.default || Object.values(parsed)[0];
    } catch {
      return undefined;
    }
  }
  return (
    Deno.env.get('SUPABASE_SECRET_KEY') ||
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ||
    undefined
  );
}

Deno.serve(async (request) => {
  const cors = corsHeaders(request);
  if (!cors) return new Response(null, { status: 403 });
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: cors });
  if (request.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'method_not_allowed' }, 405, cors);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const secretKey = readSupabaseSecretKey();
  if (!supabaseUrl || !secretKey) {
    return jsonResponse({ ok: false, error: 'portal_not_configured' }, 503, cors);
  }

  let body: Record<string, unknown>;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ ok: false, error: 'invalid_request' }, 400, cors);
  }

  const action = body.action as PortalAction;
  const admin = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (action === 'login' || action === 'familyLogin') {
    const accessCode = action === 'familyLogin'
      ? (typeof body.familyCode === 'string' ? body.familyCode.trim() : '')
      : (typeof body.studentCode === 'string' ? body.studentCode.trim() : '');
    const pin = typeof body.pin === 'string' ? body.pin.trim() : '';
    const pepper = Deno.env.get('PORTAL_RATE_LIMIT_PEPPER');
    if (!pepper) {
      return jsonResponse({ ok: false, error: 'portal_not_configured' }, 503, cors);
    }
    if (accessCode.length > 40 || !/^\d{6}$/.test(pin)) {
      return jsonResponse({ ok: false, error: 'invalid_credentials' }, 401, cors);
    }

    const fingerprint = await sha256([
      pepper,
      readClientIp(request),
      request.headers.get('user-agent') || 'unknown',
    ].join('|'));
    const { data, error } = action === 'familyLogin'
      ? await admin.rpc('family_portal_authenticate', {
        p_family_code: accessCode,
        p_pin: pin,
        p_client_fingerprint: fingerprint,
      })
      : await admin.rpc('student_portal_authenticate', {
        p_student_code: accessCode,
        p_pin: pin,
        p_client_fingerprint: fingerprint,
      });

    if (error) {
      return jsonResponse({ ok: false, error: 'portal_unavailable' }, 503, cors);
    }
    if (!data?.ok) {
      const rateLimited = data?.error === 'rate_limited';
      return jsonResponse(
        { ok: false, error: rateLimited ? 'rate_limited' : 'invalid_credentials' },
        rateLimited ? 429 : 401,
        cors,
      );
    }
    return jsonResponse({
      ok: true,
      sessionToken: data.session_token,
      expiresAt: data.expires_at,
    }, 200, cors);
  }

  const sessionToken = typeof body.sessionToken === 'string'
    ? body.sessionToken.trim().toLowerCase()
    : '';
  if (!/^[a-f0-9]{64}$/.test(sessionToken)) {
    return jsonResponse({ ok: false, error: 'invalid_session' }, 401, cors);
  }

  if (action === 'dashboard' || action === 'familyDashboard') {
    const requestedDays = typeof body.days === 'number' ? Math.trunc(body.days) : 30;
    const days = Math.max(7, Math.min(requestedDays, 366));
    const studentId = typeof body.studentId === 'string' &&
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(body.studentId)
      ? body.studentId
      : null;
    const { data, error } = action === 'familyDashboard'
      ? await admin.rpc('family_portal_get_dashboard', {
        p_session_token: sessionToken,
        p_days: days,
        p_student_id: studentId,
      })
      : await admin.rpc('student_portal_get_dashboard', {
        p_session_token: sessionToken,
        p_days: days,
      });
    if (error || !data) {
      return jsonResponse({ ok: false, error: 'invalid_session' }, 401, cors);
    }
    return jsonResponse({ ok: true, dashboard: data }, 200, cors);
  }

  if (action === 'logout' || action === 'familyLogout') {
    await admin.rpc(
      action === 'familyLogout'
        ? 'family_portal_revoke_session'
        : 'student_portal_revoke_session',
      {
        p_session_token: sessionToken,
      },
    );
    return jsonResponse({ ok: true }, 200, cors);
  }

  return jsonResponse({ ok: false, error: 'invalid_action' }, 400, cors);
});
