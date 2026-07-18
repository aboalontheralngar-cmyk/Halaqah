const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || '';
const supabaseAnonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || '';

export interface PortalMemorizationEntry {
  date: string;
  surah: string;
  from_ayah: number;
  to_ayah: number;
  degree: number | null;
  session_type: 'new' | 'review';
}

export interface PortalAttendanceEntry {
  date: string;
  status: 'present' | 'late' | 'absent' | 'excused';
  notes?: string | null;
}

export interface StudentPortalDashboard {
  session_expires_at: string;
  period_days: number;
  student: {
    name: string;
    student_code: string;
    level?: string | null;
    join_date: string;
    plan_type: 'ayahs' | 'pages' | 'lines';
    plan_amount: number;
    review_plan_amount: number;
    total_memorized: number;
  };
  organization: {
    center_name: string;
    halaqa_name: string;
    teacher_name?: string | null;
  };
  summary: {
    points_balance: number;
    attendance: {
      present: number;
      late: number;
      absent: number;
      excused: number;
    };
  };
  active_plan?: {
    period: 'weekly' | 'monthly';
    start_date: string;
    end_date: string;
    unit: 'ayahs' | 'pages' | 'lines';
    new_amount: number;
    review_amount: number;
    status: string;
    test_status: string;
    notes?: string | null;
  } | null;
  recent_memorization: PortalMemorizationEntry[];
  recent_attendance: PortalAttendanceEntry[];
}

export interface FamilyPortalDashboard {
  session_expires_at: string;
  period_days: number;
  family: {
    name: string;
    family_code: string;
    primary_guardian_name?: string | null;
    primary_guardian_relationship?: string | null;
  };
  students: Array<{
    id: string;
    name: string;
    student_code: string;
    level?: string | null;
    status: 'active';
  }>;
  selected_student_id: string;
  student_dashboard: StudentPortalDashboard;
}

export class StudentPortalError extends Error {
  constructor(public readonly code: string) {
    super(code);
  }
}

async function portalRequest<T>(payload: Record<string, unknown>): Promise<T> {
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new StudentPortalError('portal_not_configured');
  }
  const response = await fetch(`${supabaseUrl}/functions/v1/student-portal`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: supabaseAnonKey,
      Authorization: `Bearer ${supabaseAnonKey}`,
    },
    body: JSON.stringify(payload),
    cache: 'no-store',
  });
  const result = await response.json().catch(() => ({ ok: false, error: 'portal_unavailable' }));
  if (!response.ok || !result.ok) {
    throw new StudentPortalError(result.error || 'portal_unavailable');
  }
  return result as T;
}

export async function loginToStudentPortal(studentCode: string, pin: string) {
  return portalRequest<{ ok: true; sessionToken: string; expiresAt: string }>({
    action: 'login',
    studentCode,
    pin,
  });
}

export async function loadStudentPortalDashboard(sessionToken: string, days = 30) {
  const result = await portalRequest<{ ok: true; dashboard: StudentPortalDashboard }>({
    action: 'dashboard',
    sessionToken,
    days,
  });
  return result.dashboard;
}

export async function logoutStudentPortal(sessionToken: string) {
  await portalRequest<{ ok: true }>({ action: 'logout', sessionToken });
}

export async function loginToFamilyPortal(familyCode: string, pin: string) {
  return portalRequest<{ ok: true; sessionToken: string; expiresAt: string }>({
    action: 'familyLogin',
    familyCode,
    pin,
  });
}

export async function loadFamilyPortalDashboard(
  sessionToken: string,
  days = 30,
  studentId?: string,
) {
  const result = await portalRequest<{ ok: true; dashboard: FamilyPortalDashboard }>({
    action: 'familyDashboard',
    sessionToken,
    days,
    studentId,
  });
  return result.dashboard;
}

export async function logoutFamilyPortal(sessionToken: string) {
  await portalRequest<{ ok: true }>({ action: 'familyLogout', sessionToken });
}
