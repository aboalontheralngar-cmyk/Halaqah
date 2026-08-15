type SafeErrorShape = { code?: unknown; name?: unknown; digest?: unknown };

/**
 * Privacy-safe browser diagnostic. Never writes error.message/details/hint,
 * record payloads, emails, invitation tokens, or Supabase responses.
 */
export function logOperationalError(source: string, error: unknown): void {
  if (process.env.NODE_ENV === "production") return;
  const shape = error && typeof error === "object" ? error as SafeErrorShape : {};
  const code = [shape.code, shape.name, shape.digest]
    .find((value) => typeof value === "string" && value.length > 0);
  console.error(`[${source}] ${String(code ?? "unknown_error")}`);
}
