const configuredAppUrl = process.env.NEXT_PUBLIC_APP_URL?.trim() || "";

function parseOrigin(value: string): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    const isLocal = url.hostname === "localhost" || url.hostname === "127.0.0.1";
    if (url.protocol !== "https:" && !(isLocal && url.protocol === "http:")) {
      return null;
    }
    return url.origin;
  } catch {
    return null;
  }
}

export function publicAppOrigin(): string {
  const runtimeOrigin = typeof window !== "undefined" ? window.location.origin : "";
  const runtime = parseOrigin(runtimeOrigin);
  const configured = parseOrigin(configuredAppUrl);

  // Never send a production browser back to localhost because a stale build
  // variable was left behind. The active HTTPS origin is safer and is also
  // what Supabase Redirect URLs should allow.
  if (runtime) {
    const runtimeHost = new URL(runtime).hostname;
    const runtimeIsLocal = runtimeHost === "localhost" || runtimeHost === "127.0.0.1";
    if (!runtimeIsLocal) return runtime;
  }

  return configured || runtime || "";
}

export function oauthCallbackUrl(): string {
  const origin = publicAppOrigin();
  if (!origin) {
    throw new Error(
      "تعذر تحديد عنوان الموقع العام. عرّف NEXT_PUBLIC_APP_URL بعنوان HTTPS المنشور.",
    );
  }
  return `${origin}/auth/callback`;
}
