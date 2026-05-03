import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

// التحقق من صحة الرابط لمنع الانهيار في حال كانت القيم فارغة
const isValidUrl = supabaseUrl.startsWith('http');

export const supabase = isValidUrl 
  ? createClient(supabaseUrl, supabaseAnonKey) 
  : null;
