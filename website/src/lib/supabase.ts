import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

function isSafeSupabaseUrl(value: string): boolean {
  try {
    const url = new URL(value);
    const isLocal = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
    return url.protocol === 'https:' || (isLocal && url.protocol === 'http:');
  } catch {
    return false;
  }
}

const isConfigured = isSafeSupabaseUrl(supabaseUrl) && supabaseAnonKey.trim().length > 0;

export const supabaseConfiguration = Object.freeze({
  isConfigured,
  urlOrigin: isConfigured ? new URL(supabaseUrl).origin : null,
});

export const supabase = isConfigured
  ? createClient(supabaseUrl, supabaseAnonKey, {
      auth: {
        persistSession: true,
        autoRefreshToken: true,
        detectSessionInUrl: true,
      },
    })
  : null;
