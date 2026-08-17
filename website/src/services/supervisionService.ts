import { supabase } from "@/lib/supabase";

export type SupervisorRole = "owner" | "admin" | "analyst";


export type SupervisionCenterDetail = {
  center: {
    id: string;
    name: string;
    type: "men" | "women" | "mixed";
    address?: string | null;
  };
  period: { start_date: string; end_date: string };
  halaqat: Array<{
    id: string;
    name: string;
    teacher_name?: string | null;
    active_students: number;
    attendance_rate: number;
    new_ayahs: number;
    review_ayahs: number;
  }>;
  students: Array<{
    id: string;
    name: string;
    status: string;
    halaqa_id?: string | null;
    halaqa_name?: string | null;
    total_memorized: number;
    attendance_rate: number;
    new_ayahs: number;
    review_ayahs: number;
    points_balance: number;
  }>;
};

export type SupervisionHealth = {
  contract_version?: string;
  authenticated: boolean;
  profile_role?: string | null;
  owned_organizations: number;
  active_memberships: number;
  can_create_centers?: boolean;
  direct_center_creation?: boolean;
  sync_tombstones?: boolean;
  center_detail?: boolean;
  delete_student_sync?: boolean;
  mushaf_tombstones?: boolean;
  ready: boolean;
};

type ErrorShape = {
  code?: unknown;
  message?: unknown;
  details?: unknown;
  hint?: unknown;
};

function errorShape(error: unknown): ErrorShape {
  return error && typeof error === "object" ? error as ErrorShape : {};
}

export function supervisionErrorCode(error: unknown): string {
  const shape = errorShape(error);
  const code = typeof shape.code === "string" ? shape.code : "";
  const message = typeof shape.message === "string" ? shape.message : String(error ?? "");

  if (message.includes("supervisor_manager_required")) return "manager_required";
  if (message.includes("supervisor_access_required")) return "access_required";
  if (message.includes("center_already_linked")) return "center_already_linked";
  if (message.includes("center_owner_required")) return "center_owner_required";
  if (message.includes("invalid_or_expired")) return "invalid_invitation";
  if (message.includes("owner_membership_is_immutable")) return "owner_immutable";
  if (message.includes("invalid_dashboard_period")) return "invalid_period";
  if (message.includes("center_not_linked_to_supervisor")) return "center_not_linked";
  if (message.includes("invalid_center_name")) return "invalid_center_name";
  if (message.includes("invalid_center_type")) return "invalid_center_type";
  if (message.includes("invalid_center_address")) return "invalid_center_address";
  if (message.includes("invalid_halaqah_name")) return "invalid_halaqah_name";
  if (message.includes("invalid_teacher_name")) return "invalid_teacher_name";
  if (message.includes("invalid_supervisor_name")) return "invalid_supervisor_name";
  if (message.includes("supervisor_already_exists")) return "supervisor_already_exists";
  if (message.includes("supervisor_not_found")) return "supervisor_not_found";
  if (message.includes("supervised_center_not_found")) return "supervised_center_not_found";
  if (code === "42501") return "permission_denied";
  if (code === "PGRST202" || code === "42883" || message.toLowerCase().includes("function")) {
    return "rpc_missing";
  }
  if (code === "42P01" || code === "PGRST205") return "table_missing";
  return "unknown";
}

export function supervisionErrorMessage(
  error: unknown,
  health?: SupervisionHealth | null,
): string {
  switch (supervisionErrorCode(error)) {
    case "manager_required":
      return "هذه العملية متاحة لمالك الجهة أو المدير الإشرافي فقط.";
    case "access_required":
    case "permission_denied":
      return "الحساب الحالي غير مخول للوصول إلى هذه الجهة الإشرافية.";
    case "center_already_linked":
      return "المركز مرتبط بجهة إشرافية أخرى. افصل الربط القديم أولًا.";
    case "center_owner_required":
      return "لا يستطيع ربط المركز إلا مالكه.";
    case "invalid_invitation":
      return "الدعوة غير صحيحة أو انتهت صلاحيتها أو استُخدمت من قبل.";
    case "owner_immutable":
      return "عضوية مالك الجهة ثابتة ولا يمكن تعطيلها من شاشة الفريق.";
    case "invalid_period":
      return "الفترة غير صحيحة. اختر فترة لا تتجاوز 366 يومًا.";
    case "center_not_linked":
      return "لا يمكن تسجيل الزيارة لأن المركز غير مرتبط بهذه الجهة.";
    case "invalid_center_name":
      return "اسم المركز يجب أن يكون بين 2 و160 حرفًا.";
    case "invalid_center_type":
      return "نوع المركز غير صحيح.";
    case "invalid_center_address":
      return "عنوان المركز أطول من الحد المسموح.";
    case "invalid_halaqah_name":
      return "اسم الحلقة الأولى أطول من الحد المسموح.";
    case "invalid_teacher_name":
      return "اسم المعلم أطول من الحد المسموح.";
    case "invalid_supervisor_name":
      return "اسم الجهة الإشرافية يجب أن يكون بين 3 و160 حرفًا.";
    case "supervisor_already_exists":
      return "للحساب جهة إشرافية موجودة بالفعل؛ أعد تحميل الصفحة وسيتم استئنافها تلقائيًا.";
    case "supervisor_not_found":
      return "الجهة الإشرافية لم تعد موجودة أو لا يمكن الوصول إليها.";
    case "supervised_center_not_found":
      return "المركز غير تابع لهذه الجهة الإشرافية أو تم فصل ارتباطه.";
    case "rpc_missing":
      return "واجهة الإشراف موجودة في المشروع لكن PostgREST لا يرى دالة الإنشاء. نفّذ SQL Build 84 لإصلاح create_supervisor_organization وإعادة تحميل schema cache ثم أعد المحاولة.";
    case "table_missing":
      return "أحد جداول الإشراف غير موجود في قاعدة البيانات. شغّل فحص Build 84 قبل أي ترحيل قديم.";
    default:
      if (health && !health.ready) {
        return "عقود الإشراف موجودة، لكن الحساب ليس مالكًا أو عضوًا نشطًا في جهة إشرافية. راجع العضوية أو اقبل دعوة الفريق.";
      }
      if (health && health.direct_center_creation === false) {
        return "إنشاء المراكز المباشر غير متاح في عقد القاعدة الحالي. لا تعاود P7.3 القديمة؛ أكمل Build 75/76 ثم تحقق من الجاهزية.";
      }
      const shape = errorShape(error);
      const reference = typeof shape.code === "string" && shape.code ? shape.code : "UNKNOWN";
      return `تعذر إتمام عملية الإشراف. الرمز: SUPERVISION_${reference}. لا تعاود P7.3 القديمة؛ شغّل فحص Build 82 للبوابة والإشراف.`;
  }
}

export async function fetchSupervisionHealth(): Promise<SupervisionHealth | null> {
  if (!supabase) return null;
  const { data, error } = await supabase.rpc("get_supervision_health");
  if (error || !data || typeof data !== "object") return null;
  return data as SupervisionHealth;
}

export async function createSupervisorOrganization(name: string) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  const response = await supabase.rpc("create_supervisor_organization", {
    p_name: name.trim(),
  });
  if (!response.error || supervisionErrorCode(response.error) !== "supervisor_already_exists") {
    return response;
  }

  // A previous onboarding attempt may have created the organization before the
  // browser navigated away. Treat that as resumable, not as a fatal duplicate.
  const existing = await supabase.rpc("get_my_supervisors");
  const organizations = Array.isArray(existing.data) ? existing.data : [];
  if (!existing.error && organizations.length > 0) {
    return { data: organizations[0], error: null };
  }
  return response;
}


export async function createSupervisedCenter(input: {
  supervisorId: string;
  name: string;
  type: "men" | "women" | "mixed";
  address?: string;
  halaqahName?: string;
  teacherName?: string;
}) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  return supabase.rpc("create_supervised_center", {
    p_supervisor_id: input.supervisorId,
    p_name: input.name.trim(),
    p_type: input.type,
    p_address: input.address?.trim() || null,
    p_halaqah_name: input.halaqahName?.trim() || null,
    p_teacher_name: input.teacherName?.trim() || null,
  });
}

export async function acceptSupervisorCenterInvitation(centerId: string, code: string) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  return supabase.rpc("accept_supervisor_center_invitation", {
    p_center_id: centerId,
    p_code: code.trim().toUpperCase(),
  });
}

export async function acceptSupervisorTeamInvitation(code: string) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  return supabase.rpc("accept_supervisor_member_invitation", {
    p_code: code.trim().toUpperCase(),
  });
}


export async function fetchSupervisionCenterDetail(input: {
  supervisorId: string;
  centerId: string;
  startDate: string;
  endDate: string;
}) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  return supabase.rpc("get_supervision_center_detail", {
    p_supervisor_id: input.supervisorId,
    p_center_id: input.centerId,
    p_start_date: input.startDate,
    p_end_date: input.endDate,
  });
}

export type SupervisorCompetition = {
  id: string;
  supervisor_id: string;
  title: string;
  season_year: number;
  description?: string | null;
  starts_on?: string | null;
  ends_on?: string | null;
  status: "draft" | "open" | "judging" | "published" | "closed";
  created_at: string;
};

export type SupervisorCompetitionCategory = {
  id: string;
  competition_id: string;
  name: string;
  from_surah?: number | null;
  to_surah?: number | null;
  maximum_score: number;
  sort_order: number;
};

export type SupervisorCompetitionEntry = {
  id: string;
  competition_id: string;
  category_id: string;
  center_id: string;
  student_id: string;
  student_name_snapshot: string;
  status: "submitted" | "accepted" | "rejected" | "withdrawn";
  submitted_at: string;
  center?: { name?: string | null } | null;
  category?: { name?: string | null; maximum_score?: number | null } | null;
  score?: Array<{
    score: number;
    obvious_errors: number;
    subtle_errors: number;
    prompt_count: number;
    stop_count: number;
    tajweed_errors: number;
    notes?: string | null;
  }> | null;
};

export async function submitSupervisorCompetitionEntry(input: {
  competitionId: string;
  categoryId: string;
  studentId: string;
}) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  return supabase.rpc("submit_supervisor_competition_entry", {
    p_competition_id: input.competitionId,
    p_category_id: input.categoryId,
    p_student_id: input.studentId,
  });
}

export async function withdrawSupervisorCompetitionEntry(entryId: string) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  return supabase.rpc("withdraw_supervisor_competition_entry", { p_entry_id: entryId });
}

export async function scoreSupervisorCompetitionEntry(input: {
  entryId: string;
  score: number;
  obviousErrors?: number;
  subtleErrors?: number;
  promptCount?: number;
  stopCount?: number;
  tajweedErrors?: number;
  notes?: string;
}) {
  if (!supabase) return { data: null, error: new Error("supabase_not_configured") };
  return supabase.rpc("score_supervisor_competition_entry", {
    p_entry_id: input.entryId,
    p_score: input.score,
    p_obvious_errors: input.obviousErrors ?? 0,
    p_subtle_errors: input.subtleErrors ?? 0,
    p_prompt_count: input.promptCount ?? 0,
    p_stop_count: input.stopCount ?? 0,
    p_tajweed_errors: input.tajweedErrors ?? 0,
    p_notes: input.notes?.trim() || null,
  });
}
