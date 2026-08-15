import type {
  AttendanceRecord,
  HomeworkGrade,
  MemorizationRecord,
  Student,
  StudentHold,
  Vacation,
} from "@/store/useStore";

export type DailyClosingState =
  | "completed"
  | "absent"
  | "no_recitation"
  | "unrecorded"
  | "excused"
  | "held"
  | "activity"
  | "talaqqin"
  | "holiday";

export interface DailyClosingItem {
  student: Student;
  attendance?: AttendanceRecord;
  state: DailyClosingState;
  detail: string;
}

export interface DailyClosingSummary {
  items: DailyClosingItem[];
  completed: number;
  absent: number;
  noRecitation: number;
  unrecorded: number;
  excused: number;
  actionRequired: number;
}

export interface DailyClosingReceipt {
  closingId: string;
  date: string;
  alreadyClosed: boolean;
  recordsCreated: number;
  recordsExcused: number;
  absencePointsAdded: number;
  noRecitationPointsAdded: number;
  completedStudents: number;
  exemptStudents: number;
  closedAt: string;
}

export interface DailyClosingStatus {
  date: string;
  isClosed: boolean;
  isSuspended: boolean;
  isWeeklyHoliday: boolean;
  suspensionReason?: string;
  canClose: boolean;
  blocker?: "halaqa_required" | "future_date" | "before_end_time" | "study_suspended" | "already_closed";
  sessionEndTime: string;
  timezoneName: string;
  closedAt?: string;
  closedBy?: string;
}

export function isWeeklyHoliday(date: string, weeklyHolidayDays: number[]): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return false;
  const [year, month, day] = date.split("-").map(Number);
  const weekday = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
  return weeklyHolidayDays.includes(weekday);
}

export function normalizePointsConfig(
  config: Record<string, number>,
): Record<string, number> {
  const normalized = { ...config };
  const negative = (key: string, fallback: number) => {
    const value = Number(normalized[key]);
    return Number.isFinite(value) && value < 0 ? Math.max(-100, Math.trunc(value)) : fallback;
  };
  normalized.late_penalty = negative("late_penalty", -2);
  normalized.incomplete_penalty = negative("incomplete_penalty", -3);
  normalized.no_thobe = negative("no_thobe", -3);
  normalized.appearance_violation = negative("appearance_violation", -3);

  const commonPenalty =
    Math.abs(normalized.late_penalty) +
    Math.abs(normalized.incomplete_penalty) +
    Math.abs(normalized.no_thobe);
  const requestedAbsence = negative("unexcused_absence", -10);
  normalized.unexcused_absence =
    Math.abs(requestedAbsence) > commonPenalty
      ? requestedAbsence
      : -Math.min(100, commonPenalty + 1);
  return normalized;
}

export function evaluateDailyClosing({
  students,
  attendance,
  memorization,
  homeworkGrades = [],
  vacations,
  studentHolds = [],
  date,
  isHoliday,
}: {
  students: Student[];
  attendance: AttendanceRecord[];
  memorization: MemorizationRecord[];
  homeworkGrades?: HomeworkGrade[];
  vacations: Vacation[];
  studentHolds?: StudentHold[];
  date: string;
  isHoliday: boolean;
}): DailyClosingSummary {
  const operational = students
    .filter((student) => student.status === "active" || student.status === "suspended")
    .sort((a, b) => a.name.localeCompare(b.name, "ar"));
  const records = new Map(
    attendance
      .filter((record) => record.date === date)
      .map((record) => [record.studentId, record]),
  );
  const recited = new Set(
    [
      ...memorization
        .filter((record) => record.date === date)
        .map((record) => record.studentId),
      ...homeworkGrades
        .filter((record) => record.date === date && record.gradeMark !== "absent")
        .map((record) => record.studentId),
    ],
  );
  const activeHolds = studentHolds.filter(
    (hold) => !hold.endedAt && hold.startDate <= date && hold.endDate >= date,
  );
  const held = new Set(activeHolds.map((hold) => hold.studentId));
  const fullPaused = new Set(
    activeHolds
      .filter((hold) => hold.scope === "full_pause")
      .map((hold) => hold.studentId),
  );
  const approvedVacation = new Set(
    vacations
      .filter(
        (vacation) =>
          vacation.approved && vacation.startDate <= date && vacation.endDate >= date,
      )
      .map((vacation) => vacation.studentId),
  );

  const items = operational.map((student): DailyClosingItem => {
    const record = records.get(student.id);
    if (isHoliday) {
      return { student, attendance: record, state: "holiday", detail: "تعليق دراسة أو إجازة" };
    }
    if (fullPaused.has(student.id)) {
      return { student, attendance: record, state: "held", detail: "توقف مؤقت كامل عن الحلقة" };
    }
    if (record?.status === "excused") {
      return { student, attendance: record, state: "excused", detail: "إجازة أو استئذان معتمد" };
    }
    if (record && (record.status === "present" || record.status === "late") && recited.has(student.id)) {
      return { student, attendance: record, state: "completed", detail: "حضور وتسميع مسجلان" };
    }
    if (record && (record.status === "present" || record.status === "late") && record.talaqqinDone) {
      return { student, attendance: record, state: "talaqqin", detail: "حضور وتلقين مسجلان" };
    }
    if (record && (record.status === "present" || record.status === "late") && record.recitationExempt) {
      return {
        student,
        attendance: record,
        state: "activity",
        detail: record.activityType ? `نشاط: ${record.activityType}` : "نشاط مع إعفاء من التسميع",
      };
    }
    if (record && (record.status === "present" || record.status === "late") && held.has(student.id)) {
      return {
        student,
        attendance: record,
        state: "held",
        detail: "حاضر وموقوف مؤقتًا عن التسميع",
      };
    }
    if (record && (record.status === "present" || record.status === "late")) {
      return {
        student,
        attendance: record,
        state: "no_recitation",
        detail: "حاضر ولم يُسجل له حفظ أو مراجعة أو تلقين",
      };
    }
    if (approvedVacation.has(student.id)) {
      return { student, attendance: record, state: "excused", detail: "إجازة أو استئذان معتمد" };
    }
    if (!record) {
      return { student, state: "unrecorded", detail: "لم يُسجل الحضور بعد" };
    }
    if (record.status === "absent") {
      return { student, attendance: record, state: "absent", detail: "غياب مسجل" };
    }
    return {
      student,
      attendance: record,
      state: "no_recitation",
      detail: "حاضر ولم يُسجل له حفظ أو مراجعة",
    };
  });

  const count = (state: DailyClosingState) =>
    items.filter((item) => item.state === state).length;
  const absent = count("absent");
  const noRecitation = count("no_recitation");
  const unrecorded = count("unrecorded");
  return {
    items,
    completed: count("completed"),
    absent,
    noRecitation,
    unrecorded,
    excused:
      count("excused") +
      count("held") +
      count("activity") +
      count("talaqqin") +
      count("holiday"),
    actionRequired: absent + noRecitation + unrecorded,
  };
}
