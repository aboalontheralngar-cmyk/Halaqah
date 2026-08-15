import { createClient } from 'npm:@supabase/supabase-js@2';

type GuardianReportDelivery = {
  id: string;
  family_id: string;
  period_start: string;
  period_end: string;
  frequency: 'weekly' | 'monthly';
  report_payload: Record<string, unknown>;
  attempt_count: number;
};

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

async function sha256(value: string): Promise<Uint8Array> {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  );
  return new Uint8Array(digest);
}

async function secretsMatch(left: string, right: string): Promise<boolean> {
  const [leftHash, rightHash] = await Promise.all([
    sha256(left),
    sha256(right),
  ]);
  if (leftHash.length !== rightHash.length) return false;
  let difference = 0;
  for (let index = 0; index < leftHash.length; index += 1) {
    difference |= leftHash[index] ^ rightHash[index];
  }
  return difference === 0;
}

async function hmacHex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'HMAC',
    key,
    new TextEncoder().encode(body),
  );
  return Array.from(new Uint8Array(signature))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return jsonResponse({ ok: false, error: 'method_not_allowed' }, 405);
  }

  const workerSecret = Deno.env.get('GUARDIAN_REPORT_WORKER_SECRET');
  const presentedSecret = request.headers.get('x-halaqah-report-secret') || '';
  if (
    !workerSecret ||
    !presentedSecret ||
    !(await secretsMatch(workerSecret, presentedSecret))
  ) {
    return jsonResponse({ ok: false, error: 'unauthorized' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const supabaseSecretKey = readSupabaseSecretKey();
  if (!supabaseUrl || !supabaseSecretKey) {
    return jsonResponse({ ok: false, error: 'worker_not_configured' }, 503);
  }

  const admin = createClient(supabaseUrl, supabaseSecretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: publishedCount, error: publishError } = await admin.rpc(
    'publish_due_guardian_reports',
    { p_limit: 100 },
  );
  if (publishError) {
    return jsonResponse({ ok: false, error: 'report_publish_failed' }, 503);
  }

  const webhookUrl = Deno.env.get('GUARDIAN_REPORT_WEBHOOK_URL');
  const webhookSecret = Deno.env.get('GUARDIAN_REPORT_WEBHOOK_SECRET');
  if (!webhookUrl || !webhookSecret) {
    return jsonResponse({
      ok: true,
      publishedCount: Number(publishedCount || 0),
      externalDelivery: 'not_configured',
      deliveredCount: 0,
      failedCount: 0,
    });
  }

  let parsedWebhookUrl: URL;
  try {
    parsedWebhookUrl = new URL(webhookUrl);
    if (parsedWebhookUrl.protocol !== 'https:') {
      throw new Error('webhook_must_use_https');
    }
  } catch {
    return jsonResponse({ ok: false, error: 'invalid_webhook_url' }, 503);
  }

  const { data: claimed, error: claimError } = await admin.rpc(
    'claim_guardian_report_deliveries',
    { p_limit: 25 },
  );
  if (claimError) {
    return jsonResponse({ ok: false, error: 'report_claim_failed' }, 503);
  }

  let deliveredCount = 0;
  let failedCount = 0;
  for (const delivery of (claimed || []) as GuardianReportDelivery[]) {
    const outgoing = JSON.stringify({
      event: 'guardian_report.ready',
      deliveryId: delivery.id,
      familyId: delivery.family_id,
      periodStart: delivery.period_start,
      periodEnd: delivery.period_end,
      frequency: delivery.frequency,
      attempt: delivery.attempt_count,
      report: delivery.report_payload,
    });
    let succeeded = false;
    let providerReference = '';
    let failureReason = '';
    try {
      const signature = await hmacHex(webhookSecret, outgoing);
      const response = await fetch(parsedWebhookUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'x-halaqah-signature': `sha256=${signature}`,
          'x-halaqah-event': 'guardian_report.ready',
        },
        body: outgoing,
        signal: AbortSignal.timeout(15_000),
      });
      const responseBody = await response.json().catch(() => ({})) as {
        id?: unknown;
        reference?: unknown;
        error?: unknown;
      };
      succeeded = response.ok;
      providerReference = String(
        response.headers.get('x-provider-reference') ||
        responseBody.reference ||
        responseBody.id ||
        '',
      ).slice(0, 200);
      if (!response.ok) {
        failureReason = String(
          responseBody.error || `provider_http_${response.status}`,
        ).slice(0, 500);
      }
    } catch (error) {
      failureReason = error instanceof Error
        ? error.message.slice(0, 500)
        : 'provider_request_failed';
    }

    await admin.rpc('complete_guardian_report_delivery', {
      p_delivery_id: delivery.id,
      p_succeeded: succeeded,
      p_provider_reference: providerReference || null,
      p_failure_reason: failureReason || null,
    });
    if (succeeded) deliveredCount += 1;
    else failedCount += 1;
  }

  return jsonResponse({
    ok: true,
    publishedCount: Number(publishedCount || 0),
    externalDelivery: 'processed',
    claimedCount: (claimed || []).length,
    deliveredCount,
    failedCount,
  });
});
