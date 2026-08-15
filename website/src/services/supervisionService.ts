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
    case "supervisor_not_found":
      return "الجهة الإشرافية لم تعد موجودة أو لا يمكن الوصول إليها.";
    case "supervised_center_not_found":
      return "المركز غير تابع لهذه الجهة الإشرافية أو تم فصل ارتباطه.";
    case "rpc_missing":
    case "table_missing":
      return "عقد قاعدة بيانات الإشراف غير مكتمل. نفّذ ترحيل Build 76 ثم شغّل فحص الجاهزية المرفق.";
    default:
      if (health && !health.ready) {
        return "عقود الإشراف موجودة، لكن الحساب ليس مالكًا أو عضوًا نشطًا في جهة إشرافية. راجع العضوية أو اقبل دعوة الفريق.";
      }
      return "تعذر إتمام عملية الإشراف. شغّل فحص جاهزية Build 76؛ لن تحتاج إلى إعادة إنشاء البيانات أو الجهة.";
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
  return supabase.rpc("create_supervisor_organization", { p_name: name.trim() });
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
