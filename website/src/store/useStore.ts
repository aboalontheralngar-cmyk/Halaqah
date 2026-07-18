import { create } from 'zustand';
import type { User } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import { quranService } from '@/services/quranService';

function createInvitationCode(): string {
  const bytes = new Uint8Array(12);
  crypto.getRandomValues(bytes);
  const token = Array.from(bytes, byte => byte.toString(16).padStart(2, '0'))
    .join('')
    .toUpperCase();
  return `HAL-SEC-${token}`;
}

export type UserRole = 'supervisor' | 'center_admin' | 'teacher';

export interface Profile {
  id: string;
  fullName: string;
  role: UserRole;
}

export interface Supervisor {
  id: string;
  name: string;
  role: 'owner' | 'admin' | 'analyst';
  code?: string;
}

export interface Teacher {
  id: string;
  email: string;
  role: 'admin' | 'teacher';
  halaqahId?: string;
  halaqahName?: string;
  invitation_code?: string;
}

export interface Student {
  id: string;
  familyId?: string;
  qrCode?: string;
  studentCode?: string;
  name: string;
  phone: string;
  parentPhone: string;
  age: number;
  level: string;
  joinDate: string;
  photoUrl?: string;
  planType: 'ayahs' | 'pages' | 'lines';
  planAmount: number;
  reviewPlanAmount: number;
  status: 'active' | 'inactive' | 'suspended' | 'expelled' | 'graduated';
  memorizationDirection?: 'asc' | 'desc';
  preMemorizedStartSurah?: number;
  preMemorizedStartAyah?: number;
  preMemorizedEndSurah?: number;
  preMemorizedEndAyah?: number;
}

export interface AttendanceRecord {
  id: string;
  studentId: string;
  date: string;
  status: 'present' | 'absent' | 'excused' | 'late';
  arrivalTime?: string;
  absenceReason?: string;
  notes?: string;
}

export interface MemorizationRecord {
  id: string;
  studentId: string;
  surah: string;
  fromAyah: number;
  toAyah: number;
  date: string;
  degree: number;
  notes: string;
  isRevision?: boolean;
}

export interface PointRecord {
  id: string;
  studentId: string;
  type: 'positive' | 'negative';
  amount: number;
  reason: string;
  date: string;
  resolved?: boolean; // For violations
}

export interface DailyAchievement {
  id: string;
  studentId: string;
  date: string;
  source: 'automatic' | 'manual';
  reason: string;
  actualAmount: number;
  planAmount: number;
  unit: 'ayahs' | 'pages' | 'lines';
  rewardType?: 'points' | 'certificate' | 'gift' | 'meal' | 'other';
  rewardDetails?: string;
  rewardPoints: number;
  awardedAt?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface DailyAchievementInput {
  studentId: string;
  date: string;
  source: 'automatic' | 'manual';
  reason: string;
  actualAmount: number;
  planAmount: number;
  unit: 'ayahs' | 'pages' | 'lines';
  notes?: string;
}

export interface Vacation {
  id: string;
  studentId: string;
  startDate: string;
  endDate: string;
  reason: string;
  approved: boolean;
}

export interface Exam {
  id: string;
  title: string;
  date: string;
  type: 'oral' | 'written';
  maxDegree: number;
  studentScores: { studentId: string; degree: number; notes: string }[];
}

export interface SmartPlan {
  id: string;
  studentId: string;
  period: 'weekly' | 'monthly';
  startDate: string;
  endDate: string;
  unit: 'ayahs' | 'pages' | 'lines';
  newAmount: number;
  reviewAmount: number;
  status: 'active' | 'completed' | 'cancelled';
  testStatus: 'not_required' | 'pending' | 'passed' | 'failed';
  completionExamId?: string;
  completedAt?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Activity {
  id: string;
  type: string;
  description: string;
  date: string;
}

export interface HomeworkGrade {
  id: string;
  studentId: string;
  surah: string;
  fromAyah: number;
  toAyah: number;
  date: string;
  gradeMark: 'excellent' | 'very_good' | 'good' | 'needs_work' | 'absent';
  mistakesCount: number;
  isRevision: boolean;
  remark?: string;
  createdAt?: string;
}

export interface MushafProgress {
  id: string;
  studentId: string;
  hizbNumber: number;
  thumunNumber: number;
  averageGrade: number;
  lastGradedDate?: string;
  isPreMemorized: boolean;
}

export interface MessageTemplate {
  centerId: string;
  type: 'assignment' | 'grading';
  content: string;
}

export type AppUser = Pick<User, 'id' | 'email'> & {
  name?: string;
  user_metadata?: User['user_metadata'];
};

type MushafProgressRow = {
  id: string;
  student_id: string;
  hizb_number: number;
  thumun_number: number;
  average_grade: number | string;
  last_graded_date?: string | null;
  is_pre_memorized: boolean;
};

type TeacherRow = {
  id: string;
  email: string;
  role: Teacher['role'];
  halaqah_id?: string | null;
  invitation_code?: string;
  halaqat?: { name: string } | { name: string }[] | null;
};

type StudentRow = {
  id: string;
  qr_code?: string;
  student_code?: string;
  name: string;
  phone: string;
  parent_phone: string;
  family_id?: string | null;
  age: number;
  level: string;
  join_date: string;
  photo_url?: string;
  plan_type: Student['planType'];
  plan_amount: number;
  review_plan_amount?: number;
  status: Student['status'];
  memorization_direction?: Student['memorizationDirection'];
  pre_memorized_start_surah?: number;
  pre_memorized_start_ayah?: number;
  pre_memorized_end_surah?: number;
  pre_memorized_end_ayah?: number;
};

type AttendanceRow = {
  id: string;
  student_id: string;
  date: string;
  status: AttendanceRecord['status'];
  arrival_time?: string;
  absence_reason?: string;
  notes?: string;
};

type MemorizationRow = {
  id: string;
  student_id: string;
  surah: string;
  from_ayah: number;
  to_ayah: number;
  date: string;
  degree: number;
  notes: string;
  session_type?: string;
};

type PointRow = {
  id: string;
  student_id: string;
  type: PointRecord['type'];
  amount: number;
  reason: string;
  date: string;
  resolved?: boolean;
};

type VacationRow = {
  id: string;
  student_id: string;
  start_date: string;
  end_date: string;
  reason: string;
  approved: boolean;
};

type ExamScoreRow = { student_id: string; degree: number; notes: string };
type ExamRow = {
  id: string;
  title: string;
  date: string;
  type: Exam['type'];
  max_degree: number;
  exam_scores?: ExamScoreRow[];
};

type PlanRow = {
  id: string;
  student_id: string;
  period: SmartPlan['period'];
  start_date: string;
  end_date: string;
  unit: SmartPlan['unit'];
  new_amount: number;
  review_amount: number;
  status: SmartPlan['status'];
  test_status?: SmartPlan['testStatus'];
  completion_exam_id?: string | null;
  completed_at?: string | null;
  notes?: string | null;
  created_at: string;
  updated_at?: string | null;
};

type HomeworkGradeRow = {
  id: string;
  student_id: string;
  surah: string;
  from_ayah: number;
  to_ayah: number;
  date: string;
  grade_mark: HomeworkGrade['gradeMark'];
  mistakes_count: number;
  is_revision: boolean;
  remark?: string;
  created_at?: string;
};

type MessageTemplateRow = { center_id: string; name: string; body: string };

interface HalaqahStore {
  students: Student[];
  attendance: AttendanceRecord[];
  memorization: MemorizationRecord[];
  points: PointRecord[];
  exams: Exam[];
  plans: SmartPlan[];
  vacations: Vacation[];
  activities: Activity[];
  homeworkGrades: HomeworkGrade[];
  mushafProgress: MushafProgress[];
  messageTemplates: MessageTemplate[];
  dailyAchievements: DailyAchievement[];
  currencySymbol: string;
  loading: boolean;
  darkMode: boolean;
  centerType: 'men' | 'women' | 'mixed';
  user: AppUser | null;
  profile: Profile | null;
  currentCenter: { id: string, name: string, type: 'men' | 'women' | 'mixed', activeHalaqa?: { id: string, name: string } } | null;
  userCenters: { id: string, name: string, type: 'men' | 'women' | 'mixed' }[];
  currentSupervisor: Supervisor | null;
  teachers: Teacher[];
  halaqat: { id: string, name: string, teacher_name?: string }[];

  // Actions
  setUser: (user: AppUser | null) => void;
  fetchProfile: () => Promise<void>;
  setProfile: (profile: Profile | null) => void;
  createSupervisor: (name: string) => Promise<string | null>;
  joinSupervisor: (code: string) => Promise<boolean>;
  acceptSupervisorMemberInvitation: (code: string) => Promise<boolean>;
  fetchTeachers: () => Promise<void>;
  addTeacher: (email: string, halaqahId?: string) => Promise<void>;
  removeTeacher: (id: string) => Promise<void>;
  setUserCenters: (centers: { id: string, name: string, type: 'men' | 'women' | 'mixed' }[]) => void;
  setCurrentCenter: (center: {
    id: string;
    name: string;
    type: 'men' | 'women' | 'mixed';
    activeHalaqa?: { id: string; name: string };
  } | null) => void;
  setCenterType: (type: 'men' | 'women' | 'mixed') => void;
  fetchStudents: () => Promise<void>;
  addStudent: (student: Omit<Student, 'id'>) => Promise<void>;
  updateStudent: (id: string, student: Partial<Student>) => Promise<void>;
  changeStudentStatus: (
    id: string,
    status: Student['status'],
    reason: string,
    notes?: string
  ) => Promise<void>;
  deleteStudent: (id: string) => Promise<void>;
  fetchHalaqat: () => Promise<void>;
  
  addAttendance: (record: Omit<AttendanceRecord, 'id'>) => Promise<void>;
  updateAttendance: (id: string, status: AttendanceRecord['status'], extra?: Partial<AttendanceRecord>) => Promise<void>;
  clearHalaqaData: () => void;
  fetchAllHalaqat: (centerId: string) => Promise<void>;
  updateHalaqa: (id: string, name: string) => Promise<void>;
  deleteHalaqa: (id: string) => Promise<void>;
  assignTeacherToHalaqa: (memberId: string, halaqahId: string | null) => Promise<void>;
  joinWithCode: (code: string) => Promise<boolean>;
  
  addMemorization: (record: Omit<MemorizationRecord, 'id'>) => Promise<void>;
  addPoints: (record: Omit<PointRecord, 'id'>) => Promise<void>;
  reassignPoint: (pointId: string, studentId: string, reason: string) => Promise<void>;
  deletePointWithAudit: (pointId: string, reason: string) => Promise<void>;
  fetchDailyAchievements: () => Promise<void>;
  saveDailyAchievement: (achievement: DailyAchievementInput) => Promise<void>;
  awardDailyAchievement: (
    achievement: DailyAchievementInput,
    rewardType: NonNullable<DailyAchievement['rewardType']>,
    rewardDetails?: string,
    rewardPoints?: number
  ) => Promise<void>;
  resolveViolation: (pointId: string) => Promise<void>;

  addVacation: (vacation: Omit<Vacation, 'id'>) => Promise<void>;
  deleteVacation: (id: string) => Promise<void>;
  
  addExam: (exam: Omit<Exam, 'id'>) => Promise<void>;
  updateExamScore: (examId: string, studentId: string, degree: number, notes: string) => Promise<void>;
  
  addActivity: (type: string, description: string) => Promise<void>;
  fetchActivities: () => Promise<void>;

  fetchAttendance: () => Promise<void>;
  fetchMemorization: () => Promise<void>;
  fetchPoints: () => Promise<void>;
  fetchVacations: () => Promise<void>;
  fetchExams: () => Promise<void>;
  fetchPlans: () => Promise<void>;
  addSmartPlan: (plan: Omit<SmartPlan, 'id' | 'createdAt' | 'updatedAt'>) => Promise<void>;
  updateSmartPlan: (id: string, changes: Partial<SmartPlan>) => Promise<void>;
  deleteSmartPlan: (id: string) => Promise<void>;
  fetchCenterData: () => Promise<void>;

  fetchHomeworkGrades: () => Promise<void>;
  addHomeworkGrade: (record: Omit<HomeworkGrade, 'id'>) => Promise<boolean>;
  updateHomeworkGrade: (
    id: string,
    record: Omit<HomeworkGrade, 'id' | 'createdAt'>
  ) => Promise<boolean>;
  deleteHomeworkGrade: (id: string) => Promise<boolean>;
  fetchMushafProgress: (studentId: string) => Promise<void>;
  togglePreMemorized: (studentId: string, hizbNumber: number, thumunNumber: number, isPre: boolean) => Promise<void>;
  fetchMessageTemplates: () => Promise<void>;
  saveMessageTemplate: (type: 'assignment' | 'grading', content: string) => Promise<void>;
  fetchCenterSettings: () => Promise<void>;
  updateCurrencySymbol: (symbol: string) => Promise<void>;

  toggleDarkMode: () => void;
  pointsConfig: Record<string, number>;
  fetchPointsConfig: () => void;
  savePointsConfig: (config: Record<string, number>) => void;
  suspendedDates: string[];
  fetchSuspendedDates: () => void;
  toggleSuspendedDate: (date: string) => void;
}

const gradeValue = (mark: HomeworkGrade['gradeMark']) => {
  switch (mark) {
    case 'excellent': return 5;
    case 'very_good': return 4;
    case 'good': return 3;
    case 'needs_work': return 2;
    default: return 0;
  }
};

async function rebuildWebMushafProgress(
  studentId: string,
  centerId: string,
  grades: HomeworkGrade[],
): Promise<MushafProgress[]> {
  if (!supabase || quranService.getSurahs().length === 0) return [];
  const { data: existingRows, error: existingError } = await supabase
    .from('mushaf_progress')
    .select('*')
    .eq('student_id', studentId);
  if (existingError) throw existingError;

  const existing = (existingRows ?? []) as MushafProgressRow[];
  const aggregates = new Map<string, { total: number; count: number; lastDate: string }>();
  for (const grade of grades) {
    if (grade.studentId !== studentId || grade.gradeMark === 'absent') continue;
    const surah = quranService.getSurahs().find(item => item.name === grade.surah);
    if (!surah) continue;
    const covered = new Set<string>();
    for (const ayah of quranService.getAyahRange(
      surah.number,
      grade.fromAyah,
      grade.toAyah,
    )) {
      const hizb = ayah.hizb ?? 0;
      const quarter = ayah.quarter ?? 0;
      if (hizb < 1 || hizb > 60 || quarter < 1 || quarter > 240) continue;
      const quarterInHizb = ((quarter - 1) % 4) + 1;
      covered.add(`${hizb}_${(quarterInHizb - 1) * 2 + 1}`);
      covered.add(`${hizb}_${(quarterInHizb - 1) * 2 + 2}`);
    }
    for (const key of covered) {
      const current = aggregates.get(key) ?? { total: 0, count: 0, lastDate: grade.date };
      current.total += gradeValue(grade.gradeMark);
      current.count += 1;
      if (grade.date > current.lastDate) current.lastDate = grade.date;
      aggregates.set(key, current);
    }
  }

  const existingByKey = new Map(
    existing.map(row => [`${row.hizb_number}_${row.thumun_number}`, row]),
  );
  const staleIds = existing
    .filter(row => !row.is_pre_memorized && !aggregates.has(`${row.hizb_number}_${row.thumun_number}`))
    .map(row => row.id);
  if (staleIds.length > 0) {
    const { error } = await supabase
      .from('mushaf_progress')
      .delete()
      .in('id', staleIds);
    if (error) throw error;
  }

  const payload = Array.from(aggregates.entries()).map(([key, aggregate]) => {
    const [hizbNumber, thumunNumber] = key.split('_').map(Number);
    const previous = existingByKey.get(key);
    return {
      student_id: studentId,
      center_id: centerId,
      hizb_number: hizbNumber,
      thumun_number: thumunNumber,
      average_grade: aggregate.total / aggregate.count,
      last_graded_date: aggregate.lastDate,
      is_pre_memorized: previous?.is_pre_memorized ?? false,
    };
  });
  if (payload.length > 0) {
    const { error } = await supabase
      .from('mushaf_progress')
      .upsert(payload, { onConflict: 'student_id,hizb_number,thumun_number' });
    if (error) throw error;
  }

  const { data: rebuilt, error: rebuiltError } = await supabase
    .from('mushaf_progress')
    .select('*')
    .eq('student_id', studentId);
  if (rebuiltError) throw rebuiltError;
  return ((rebuilt ?? []) as MushafProgressRow[]).map((row) => ({
    id: row.id,
    studentId: row.student_id,
    hizbNumber: row.hizb_number,
    thumunNumber: row.thumun_number,
    averageGrade: Number(row.average_grade),
    lastGradedDate: row.last_graded_date || undefined,
    isPreMemorized: row.is_pre_memorized,
  }));
}

export const useStore = create<HalaqahStore>((set, get) => ({
  students: [],
  attendance: [],
  memorization: [],
  points: [],
  exams: [],
  plans: [],
  vacations: [],
  activities: [],
  homeworkGrades: [],
  mushafProgress: [],
  messageTemplates: [],
  dailyAchievements: [],
  currencySymbol: 'ر.س',
  pointsConfig: {},
  suspendedDates: [],
  loading: false,
  centerType: typeof window !== "undefined" ? (localStorage.getItem("centerType") as 'men' | 'women' | 'mixed') || 'men' : 'men',
  darkMode: typeof window !== "undefined" ? localStorage.getItem("darkMode") === "true" : false,
  user: null,
  profile: null,
  currentCenter: null,
  userCenters: [],
  currentSupervisor: null,
  teachers: [],
  halaqat: [],

  setUser: (user) => {
    set({ user });
    if (user) {
      get().fetchProfile();
    } else {
      set({ profile: null, currentCenter: null, userCenters: [], currentSupervisor: null, teachers: [] });
    }
  },

  setProfile: (profile) => set({ profile }),

  fetchProfile: async () => {
    if (!supabase) return;
    const user = get().user;
    if (!user) return;

    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .maybeSingle();

    if (data && !error) {
      set({ profile: { id: data.id, fullName: data.full_name, role: data.role } });
      
      const { data: supervisoryData, error: supervisoryError } = await supabase
        .rpc('get_my_supervisors');
      const organizations = Array.isArray(supervisoryData)
        ? supervisoryData as Array<{ id: string; name: string; role: Supervisor['role'] }>
        : [];

      if (!supervisoryError) {
        set({ currentSupervisor: organizations[0] || null });
      } else if (data.role === 'supervisor') {
        // Compatibility fallback until the P7.3 migration is applied.
        const { data: supData } = await supabase
          .from('supervisors')
          .select('*')
          .eq('owner_id', user.id)
          .maybeSingle();
        if (supData) {
          set({
            currentSupervisor: {
              id: supData.id,
              name: supData.name,
              role: 'owner',
              code: supData.code,
            },
          });
        }
      }
    } else {
      // Check if user owns any centers (fallback for admins)
      const { data: centerData } = await supabase
        .from('centers')
        .select('id, owner_id')
        .eq('owner_id', user.id)
        .limit(1);
      
      if (centerData && centerData.length > 0) {
        set({ profile: { id: user.id, fullName: user.user_metadata?.full_name || 'مدير المركز', role: 'center_admin' } });
        return;
      }

      // Check center_members
      const { data: memberData } = await supabase
        .from('center_members')
        .select('id, role, user_id')
        .eq('email', user.email)
        .maybeSingle();
      
      if (memberData) {
        if (!memberData.user_id) {
          await supabase
            .from('center_members')
            .update({ user_id: user.id })
            .eq('id', memberData.id);
        }
        set({ profile: { id: user.id, fullName: user.user_metadata?.full_name || 'عضو', role: memberData.role as UserRole } });
      }
    }
  },

  createSupervisor: async (name) => {
    if (!supabase) return null;
    const user = get().user;
    if (!user) return null;

    const { data, error } = await supabase
      .rpc('create_supervisor_organization', { p_name: name.trim() });

    if (data && !error) {
      const organization = data as { id: string; name: string; role: Supervisor['role'] };
      set({ currentSupervisor: organization });
      return organization.id;
    }
    return null;
  },

  joinSupervisor: async (code) => {
    if (!supabase) return false;
    const center = get().currentCenter;
    if (!center) return false;

    const { data, error } = await supabase.rpc(
      'accept_supervisor_center_invitation',
      { p_center_id: center.id, p_code: code.trim().toUpperCase() },
    );
    return !error && Boolean((data as { success?: boolean } | null)?.success);
  },

  acceptSupervisorMemberInvitation: async (code) => {
    if (!supabase) return false;
    const { data, error } = await supabase.rpc(
      'accept_supervisor_member_invitation',
      { p_code: code.trim().toUpperCase() },
    );
    if (error || !(data as { success?: boolean } | null)?.success) return false;
    await get().fetchProfile();
    return true;
  },

  fetchTeachers: async () => {
    if (!supabase) return;
    const center = get().currentCenter;
    if (!center) return;

    const { data, error } = await supabase
      .from('center_members')
      .select(`
        id,
        email,
        role,
        halaqah_id,
        invitation_code,
        halaqat (name)
      `)
      .eq('center_id', center.id);

    if (!error && data) {
      const mapped = (data as TeacherRow[]).map((t) => ({
        id: t.id,
        email: t.email,
        role: t.role,
        halaqahId: t.halaqah_id,
        halaqahName: Array.isArray(t.halaqat) ? t.halaqat[0]?.name : t.halaqat?.name,
        invitation_code: t.invitation_code
      }));
      set({ teachers: mapped as Teacher[] });
    }
  },

  addTeacher: async (email, halaqahId) => {
    if (!supabase) return;
    const center = get().currentCenter;
    if (!center) return;

    const invitation_code = createInvitationCode();
    const invitation_expires_at = new Date(
      Date.now() + 14 * 24 * 60 * 60 * 1000
    ).toISOString();
    const { error } = await supabase
      .from('center_members')
      .insert([{ 
        email: email.trim().toLowerCase(),
        center_id: center.id, 
        halaqah_id: halaqahId,
        role: 'teacher',
        invitation_code,
        invitation_expires_at,
      }]);

    if (!error) {
      get().fetchTeachers();
    } else {
      alert("فشل إضافة المعلم: " + error.message);
    }
  },

  removeTeacher: async (id) => {
    if (!supabase) return;
    const { error } = await supabase
      .from('center_members')
      .delete()
      .eq('id', id);

    if (!error) {
      set((state) => ({ teachers: state.teachers.filter(t => t.id !== id) }));
    }
  },

  fetchHalaqat: async () => {
    if (!supabase) return;
    const center = get().currentCenter;
    if (!center) return;

    const { data, error } = await supabase
      .from('halaqat')
      .select('id, name')
      .eq('center_id', center.id);

    if (!error && data) {
      set({ halaqat: data });
    }
  },

  setUserCenters: (centers) => set({ userCenters: centers }),
  setCurrentCenter: (center) => {
    if (center) {
      if (typeof window !== 'undefined') {
        localStorage.setItem("centerType", center.type);
      }
      set({ currentCenter: center, centerType: center.type });
    } else {
      set({ currentCenter: null });
    }
  },

  setCenterType: async (type) => {
    const { currentCenter } = get();
    if (currentCenter && supabase) {
      const { error } = await supabase
        .from('centers')
        .update({ type })
        .eq('id', currentCenter.id);
      
      if (!error) {
        localStorage.setItem("centerType", type);
        set({ 
          centerType: type,
          currentCenter: { ...currentCenter, type }
        });
      }
    } else {
      localStorage.setItem("centerType", type);
      set({ centerType: type });
    }
  },

  toggleDarkMode: () => {
    const newMode = !get().darkMode;
    localStorage.setItem("darkMode", String(newMode));
    set({ darkMode: newMode });
  },

  fetchStudents: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    set({ loading: true });
    try {
      let query = supabase
        .from('students')
        .select('*')
        .eq('center_id', center.id);
      
      // Filter by halaqa if activeHalaqa is selected
      if (center.activeHalaqa?.id) {
        query = query.eq('halaqa_id', center.activeHalaqa.id);
      }

      const { data, error } = await query.order('name');
      
      if (error) throw error;
      
      if (data) {
        const mapped = (data as StudentRow[]).map((s) => ({
          id: s.id,
          qrCode: s.qr_code,
          studentCode: s.student_code,
          name: s.name,
          phone: s.phone,
          parentPhone: s.parent_phone,
          familyId: s.family_id || undefined,
          age: s.age,
          level: s.level,
          joinDate: s.join_date,
          photoUrl: s.photo_url,
          planType: s.plan_type,
          planAmount: s.plan_amount,
          reviewPlanAmount: s.review_plan_amount ?? 10,
          status: s.status,
          memorizationDirection: s.memorization_direction || 'desc',
          preMemorizedStartSurah: s.pre_memorized_start_surah,
          preMemorizedStartAyah: s.pre_memorized_start_ayah,
          preMemorizedEndSurah: s.pre_memorized_end_surah,
          preMemorizedEndAyah: s.pre_memorized_end_ayah,
        }));
        set({
          students: (mapped as Student[]).sort((a, b) =>
            a.name.localeCompare(b.name, 'ar', { sensitivity: 'base' })
          ),
        });
      } else {
        set({ students: [] });
      }
    } catch (err: unknown) {
      console.error("Fetch students error:", err);
      set({ students: [] });
    } finally {
      set({ loading: false });
    }
  },

  addStudent: async (student) => {
    const center = get().currentCenter;
    const isMen = get().centerType === 'men';
    if (supabase && center) {
      const { data, error } = await supabase
        .from('students')
        .insert([{ 
          name: student.name,
          phone: student.phone,
          parent_phone: student.parentPhone,
          family_id: student.familyId || null,
          age: student.age,
          level: student.level,
          join_date: student.joinDate,
          plan_type: student.planType,
          plan_amount: student.planAmount,
          review_plan_amount: student.reviewPlanAmount,
          status: student.status,
          center_id: center.id,
          halaqa_id: center.activeHalaqa?.id, // Assign to current halaqa
          memorization_direction: student.memorizationDirection || 'desc',
          pre_memorized_start_surah: student.preMemorizedStartSurah || null,
          pre_memorized_start_ayah: student.preMemorizedStartAyah || null,
          pre_memorized_end_surah: student.preMemorizedEndSurah || null,
          pre_memorized_end_ayah: student.preMemorizedEndAyah || null,
        }])
        .select()
        .single();
      
      if (error) {
        alert("فشل إضافة الطالب: " + error.message);
        return;
      }

      if (data) {
        const mapped = {
          id: data.id,
          qrCode: data.qr_code,
          studentCode: data.student_code,
          name: data.name,
          phone: data.phone,
          parentPhone: data.parent_phone,
          familyId: data.family_id || undefined,
          age: data.age,
          level: data.level,
          joinDate: data.join_date,
          planType: data.plan_type,
          planAmount: data.plan_amount,
          reviewPlanAmount: data.review_plan_amount ?? 10,
          status: data.status,
          memorizationDirection: data.memorization_direction || 'desc',
          preMemorizedStartSurah: data.pre_memorized_start_surah,
          preMemorizedStartAyah: data.pre_memorized_start_ayah,
          preMemorizedEndSurah: data.pre_memorized_end_surah,
          preMemorizedEndAyah: data.pre_memorized_end_ayah,
        };
        set((state) => ({
          students: [...state.students, mapped as Student].sort((a, b) =>
            a.name.localeCompare(b.name, 'ar', { sensitivity: 'base' })
          ),
        }));
        get().addActivity('student_added', `تم إضافة ${isMen ? 'طالب' : 'طالبة'} جديد: ${student.name}`);
      }
    }
  },

  updateStudent: async (id, student) => {
    if (supabase) {
      const mapped: Record<string, string | number | null | undefined> = {
        name: student.name,
        phone: student.phone,
        parent_phone: student.parentPhone,
        age: student.age,
        level: student.level,
        join_date: student.joinDate,
        plan_type: student.planType,
        plan_amount: student.planAmount,
        review_plan_amount: student.reviewPlanAmount,
        status: student.status,
      };
      if (student.familyId !== undefined) {
        mapped.family_id = student.familyId || null;
      }
      if (student.memorizationDirection !== undefined) {
        mapped.memorization_direction = student.memorizationDirection;
      }
      if (student.preMemorizedStartSurah !== undefined) {
        mapped.pre_memorized_start_surah = student.preMemorizedStartSurah;
      }
      if (student.preMemorizedStartAyah !== undefined) {
        mapped.pre_memorized_start_ayah = student.preMemorizedStartAyah;
      }
      if (student.preMemorizedEndSurah !== undefined) {
        mapped.pre_memorized_end_surah = student.preMemorizedEndSurah;
      }
      if (student.preMemorizedEndAyah !== undefined) {
        mapped.pre_memorized_end_ayah = student.preMemorizedEndAyah;
      }
      const { error } = await supabase
        .from('students')
        .update(mapped)
        .eq('id', id);
      
      if (error) {
        alert("فشل تحديث بيانات الطالب: " + error.message);
        return;
      }
    }

    set((state) => ({
      students: state.students
        .map(s => s.id === id ? { ...s, ...student } : s)
        .sort((a, b) =>
          a.name.localeCompare(b.name, 'ar', { sensitivity: 'base' })
        )
    }));
  },

  changeStudentStatus: async (id, status, reason, notes) => {
    if (!reason.trim()) {
      alert('سبب تغيير حالة الطالب مطلوب');
      return;
    }
    if (supabase) {
      const { error } = await supabase.rpc('change_student_status', {
        p_student_id: id,
        p_new_status: status,
        p_reason: reason.trim(),
        p_notes: notes?.trim() || null,
      });
      if (error) {
        alert('فشل تغيير حالة الطالب: ' + error.message);
        return;
      }
    }
    set((state) => ({
      students: state.students.map((student) =>
        student.id === id ? { ...student, status } : student
      ),
    }));
  },

  deleteStudent: async (id) => {
    if (supabase) {
      const { error } = await supabase
        .from('students')
        .delete()
        .eq('id', id);
      
      if (error) {
        alert("فشل حذف الطالب: " + error.message);
        return;
      }
    }
    set((state) => ({ students: state.students.filter(s => s.id !== id) }));
  },

  addAttendance: async (record) => {
    const center = get().currentCenter;
    if (supabase && center) {
      const { data, error } = await supabase
        .from('attendance')
        .upsert([{
          student_id: record.studentId,
          center_id: center.id,
          halaqa_id: center.activeHalaqa?.id,
          date: record.date,
          status: record.status,
          arrival_time: record.arrivalTime,
          absence_reason: record.absenceReason,
          notes: record.notes
        }], { onConflict: 'student_id,date' })
        .select()
        .single();
      if (error) {
        alert("فشل تسجيل الحضور: " + error.message);
        return;
      }
      if (data) {
        set((state) => {
          const mapped = {
            id: data.id,
            studentId: data.student_id,
            date: data.date,
            status: data.status,
            arrivalTime: data.arrival_time,
            absenceReason: data.absence_reason,
            notes: data.notes,
          } as AttendanceRecord;
          return {
            attendance: [
              ...state.attendance.filter(item =>
                !(item.studentId === mapped.studentId && item.date === mapped.date)
              ),
              mapped,
            ],
          };
        });
      }
    }
  },

  updateAttendance: async (id, status, extra) => {
    if (supabase) {
      const { error } = await supabase
        .from('attendance')
        .update({
          status,
          arrival_time: extra?.arrivalTime,
          absence_reason: extra?.absenceReason,
          notes: extra?.notes,
        })
        .eq('id', id);
      if (error) {
        alert(`فشل تحديث الحضور: ${error.message}`);
        return;
      }
    }
    set((state) => ({
      attendance: state.attendance.map(a => a.id === id ? { ...a, status, ...extra } : a)
    }));
  },

  fetchAttendance: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      let query = supabase.from('attendance').select('*').eq('center_id', center.id);
      if (center.activeHalaqa?.id) query = query.eq('halaqa_id', center.activeHalaqa.id);
      
      const { data, error } = await query.order('date', { ascending: false });
      if (error) throw error;
      if (data) {
        const mapped = (data as AttendanceRow[]).map((a) => ({
          id: a.id,
          studentId: a.student_id,
          date: a.date,
          status: a.status,
          arrivalTime: a.arrival_time,
          absenceReason: a.absence_reason,
          notes: a.notes
        }));
        set({ attendance: mapped as AttendanceRecord[] });
      }
    } catch (err) {
      console.error("Fetch attendance error:", err);
    }
  },

  fetchMemorization: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      let query = supabase.from('memorization').select('*').eq('center_id', center.id);
      if (center.activeHalaqa?.id) query = query.eq('halaqa_id', center.activeHalaqa.id);
      
      const { data, error } = await query.order('date', { ascending: false });
      if (error) throw error;
      if (data) {
        const mapped = (data as MemorizationRow[]).map((m) => ({
          id: m.id,
          studentId: m.student_id,
          surah: m.surah,
          fromAyah: m.from_ayah,
          toAyah: m.to_ayah,
          date: m.date,
          degree: m.degree,
          notes: m.notes,
          isRevision: m.session_type === 'review',
        }));
        set({ memorization: mapped as MemorizationRecord[] });
      }
    } catch (err) {
      console.error("Fetch memorization error:", err);
    }
  },

  fetchPoints: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      let query = supabase.from('points').select('*').eq('center_id', center.id);
      if (center.activeHalaqa?.id) query = query.eq('halaqa_id', center.activeHalaqa.id);
      
      const { data, error } = await query.order('date', { ascending: false });
      if (error) throw error;
      if (data) {
        const mapped = (data as PointRow[]).map((p) => ({
          id: p.id,
          studentId: p.student_id,
          type: p.type,
          amount: p.amount,
          reason: p.reason,
          date: p.date,
          resolved: p.resolved
        }));
        set({ points: mapped as PointRecord[] });
      }
    } catch (err) {
      console.error("Fetch points error:", err);
    }
  },

  clearHalaqaData: () => set({ 
    students: [], 
    attendance: [], 
    memorization: [], 
    points: [], 
    plans: [],
    dailyAchievements: [],
    activities: [],
    loading: true 
  }),

  fetchAllHalaqat: async (centerId: string) => {
    if (!supabase) return;
    const { data, error } = await supabase
      .from('halaqat')
      .select('*')
      .eq('center_id', centerId);
    if (!error && data) {
      set({ halaqat: data });
    }
  },

  updateHalaqa: async (id: string, name: string) => {
    if (!supabase) return;
    const { error } = await supabase
      .from('halaqat')
      .update({ name })
      .eq('id', id);
    if (!error) {
      const { currentCenter } = get();
      if (currentCenter) {
        get().fetchAllHalaqat(currentCenter.id);
      }
    } else {
      console.error("Error updating halaqah:", error);
    }
  },

  deleteHalaqa: async (id: string) => {
    if (!supabase) return;
    const { error } = await supabase
      .from('halaqat')
      .delete()
      .eq('id', id);
    if (!error) {
      const { currentCenter } = get();
      if (currentCenter) {
        get().fetchAllHalaqat(currentCenter.id);
      }
    } else {
      console.error("Error deleting halaqah:", error);
    }
  },

  assignTeacherToHalaqa: async (memberId, halaqahId) => {
    if (!supabase) return;
    const { error } = await supabase
      .from('center_members')
      .update({ halaqah_id: halaqahId })
      .eq('id', memberId);
    
    if (!error) {
      get().fetchTeachers();
    } else {
      alert("فشل إسناد المعلم: " + error.message);
    }
  },

  joinWithCode: async (code: string) => {
    const user = get().user;
    if (!supabase || !user) return false;

    // استدعاء الدالة الآمنة في قاعدة البيانات (تتجاوز RLS وتتحقق من الكود والبريد)
    const { data, error } = await supabase.rpc('join_center_with_code', {
      p_code: code.trim().toUpperCase(),
    });

    if (error) {
      alert("فشل الانضمام: " + error.message);
      return false;
    }

    const result = data as { success: boolean; error?: string };

    if (!result?.success) {
      switch (result?.error) {
        case 'invalid_code':
          alert("الكود غير صحيح أو منتهي الصلاحية");
          break;
        case 'email_mismatch':
          alert("البريد المسجل في الحساب لا يطابق البريد المحدد في الدعوة");
          break;
        case 'expired_code':
          alert("انتهت صلاحية الكود؛ اطلب دعوة جديدة من مدير المركز");
          break;
        case 'already_used':
          alert("هذا الكود تم استخدامه من قبل حساب آخر");
          break;
        case 'not_authenticated':
          alert("يجب تسجيل الدخول أولاً");
          break;
        default:
          alert("تعذّر الانضمام، حاول مرة أخرى");
      }
      return false;
    }

    // تحديث الملف الشخصي وإرجاع النجاح
    await get().fetchProfile();
    return true;
  },

  addMemorization: async (record) => {
    const center = get().currentCenter;
    if (supabase && center) {
      const { data, error } = await supabase
        .from('memorization')
        .insert([{ 
          student_id: record.studentId,
          center_id: center.id,
          halaqa_id: center.activeHalaqa?.id,
          surah: record.surah,
          from_ayah: record.fromAyah,
          to_ayah: record.toAyah,
          date: record.date,
          degree: record.degree,
          notes: record.notes,
          session_type: record.isRevision ? 'review' : 'new',
        }])
        .select()
        .single();
      if (error) {
        alert("فشل تسجيل الحفظ: " + error.message);
        return;
      }
      if (data) {
        set((state) => ({ memorization: [...state.memorization, {
          id: data.id,
          studentId: data.student_id,
          surah: data.surah,
          fromAyah: data.from_ayah,
          toAyah: data.to_ayah,
          date: data.date,
          degree: data.degree,
          notes: data.notes,
          isRevision: data.session_type === 'review',
        } as MemorizationRecord] }));
      }
    }
  },

  addPoints: async (record) => {
    const center = get().currentCenter;
    const persistentViolation = record.type === 'negative' && [
      'مخالفة المظهر/الحلاقة',
      'عدم لبس الثوب',
    ].includes(record.reason);
    if (supabase && center) {
      const { data, error } = await supabase
        .from('points')
        .insert([{ 
          student_id: record.studentId,
          center_id: center.id,
          halaqa_id: center.activeHalaqa?.id,
          type: record.type,
          amount: record.amount,
          reason: record.reason,
          date: record.date,
          resolved: !persistentViolation,
        }])
        .select()
        .single();
      if (error) {
        alert("فشل تسجيل النقاط: " + error.message);
        return;
      }
      if (data) {
        set((state) => ({ points: [...state.points, {
          id: data.id,
          studentId: data.student_id,
          type: data.type,
          amount: data.amount,
          reason: data.reason,
          date: data.date,
          resolved: data.resolved
        } as PointRecord] }));
        get().addActivity('points_awarded', `${record.type === 'positive' ? 'منح نقاط' : 'تسجيل مخالفة'} لـ ${get().students.find(s=>s.id===record.studentId)?.name}`);
      }
    }
  },

  reassignPoint: async (pointId, studentId, reason) => {
    if (!supabase || !reason.trim()) return;
    const { error } = await supabase.rpc('reassign_behavior_point', {
      p_point_id: pointId,
      p_corrected_student_id: studentId,
      p_reason: reason.trim(),
    });
    if (error) {
      alert('فشل تصحيح إسناد السجل: ' + error.message);
      return;
    }
    set((state) => ({
      points: state.points.map((point) =>
        point.id === pointId ? { ...point, studentId } : point
      ),
    }));
  },

  deletePointWithAudit: async (pointId, reason) => {
    if (!supabase || !reason.trim()) return;
    const { error } = await supabase.rpc('delete_behavior_point_with_audit', {
      p_point_id: pointId,
      p_reason: reason.trim(),
    });
    if (error) {
      alert('فشل حذف سجل النقاط: ' + error.message);
      return;
    }
    set((state) => ({
      points: state.points.filter((point) => point.id !== pointId),
    }));
  },

  addActivity: async (type, description) => {
    const center = get().currentCenter;
    if (supabase && center) {
      const { data, error } = await supabase
        .from('activities')
        .insert([{ 
          type, 
          description, 
          center_id: center.id,
          halaqa_id: center.activeHalaqa?.id 
        }])
        .select()
        .single();
      if (!error && data) {
        set((state) => ({ activities: [data as Activity, ...state.activities].slice(0, 10) }));
      }
    }
  },

  fetchActivities: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      let query = supabase
        .from('activities')
        .select('*')
        .eq('center_id', center.id);
      
      if (center.activeHalaqa?.id) {
        query = query.eq('halaqa_id', center.activeHalaqa.id);
      }

      const { data, error } = await query
        .order('created_at', { ascending: false })
        .limit(10);
      
      if (error) throw error;
      if (data) set({ activities: data as Activity[] });
      else set({ activities: [] });
    } catch (err) {
      console.error("Fetch activities error:", err);
      set({ activities: [] });
    }
  },

  resolveViolation: async (pointId) => {
    if (supabase) {
      await supabase.from('points').update({ resolved: true }).eq('id', pointId);
    }
    set((state) => ({
      points: state.points.map(p => p.id === pointId ? { ...p, resolved: true } : p)
    }));
  },

  addVacation: async (vacation) => {
    const center = get().currentCenter;
    if (supabase && center) {
      const { data, error } = await supabase
        .from('vacations')
        .insert([{ 
          ...vacation, 
          center_id: center.id,
          halaqa_id: center.activeHalaqa?.id 
        }])
        .select()
        .single();
      if (error) {
        alert("فشل تسجيل الإجازة: " + error.message);
        return;
      }
      if (data) {
        set((state) => ({ vacations: [...state.vacations, data as Vacation] }));
      }
    }
  },

  deleteVacation: async (id) => {
    if (supabase) {
      // Fetch details before deleting
      const { data: vac } = await supabase
        .from("vacations")
        .select("student_id, start_date, end_date")
        .eq("id", id)
        .single();
        
      await supabase.from('vacations').delete().eq('id', id);
      
      if (vac) {
        // Revert excused to absent
        const { data: excusedRecords } = await supabase
          .from("attendance")
          .select("id, notes")
          .eq("student_id", vac.student_id)
          .gte("date", vac.start_date)
          .lte("date", vac.end_date)
          .eq("status", "excused");

        if (excusedRecords && excusedRecords.length > 0) {
          const idsToRevert = excusedRecords
            .filter(r => r.notes?.includes("إجازة") || r.notes?.includes("vacation") || r.notes?.includes("تلقائي"))
            .map(r => r.id);
          
          if (idsToRevert.length > 0) {
            await supabase
              .from("attendance")
              .update({ status: "absent", notes: "تم حذف الإجازة" })
              .in("id", idsToRevert);
            await get().fetchAttendance();
          }
        }
      }
    }
    set((state) => ({ vacations: state.vacations.filter(v => v.id !== id) }));
  },

  addExam: async (exam) => {
    const center = get().currentCenter;
    if (!supabase || !center) {
      alert("تعذّر حفظ الاختبار: لا يوجد مركز محدد أو الاتصال بقاعدة البيانات غير متاح.");
      return;
    }
    const { data, error } = await supabase
      .from('exams')
      .insert([{ 
        title: exam.title, 
        date: exam.date, 
        type: exam.type, 
        max_degree: exam.maxDegree, 
        center_id: center.id,
        halaqa_id: center.activeHalaqa?.id 
      }])
      .select()
      .single();
    if (error) {
      alert("فشل إضافة الاختبار: " + error.message);
      return;
    }
    if (data) {
      set((state) => ({
        exams: [
          ...state.exams,
          {
            id: data.id,
            title: data.title,
            date: data.date,
            type: data.type,
            maxDegree: data.max_degree,
            studentScores: [],
          } as Exam,
        ],
      }));
    }
  },


  fetchVacations: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    const { data, error } = await supabase
      .from('vacations')
      .select('*')
      .eq('center_id', center.id)
      .order('start_date', { ascending: false });
    if (!error && data) {
      set({
        vacations: (data as VacationRow[]).map((v) => ({
          id: v.id,
          studentId: v.student_id,
          startDate: v.start_date,
          endDate: v.end_date,
          reason: v.reason,
          approved: v.approved,
        })) as Vacation[],
      });
    }
  },

  fetchExams: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    const { data, error } = await supabase
      .from('exams')
      .select('*, exam_scores (student_id, degree, notes)')
      .eq('center_id', center.id)
      .order('date', { ascending: false });
    if (!error && data) {
      set({
        exams: (data as ExamRow[]).map((e) => ({
          id: e.id,
          title: e.title,
          date: e.date,
          type: e.type,
          maxDegree: e.max_degree,
          studentScores: (e.exam_scores || []).map((s) => ({
            studentId: s.student_id,
            degree: s.degree,
            notes: s.notes,
          })),
        })) as Exam[],
      });
    }
  },

  fetchPlans: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    let query = supabase
      .from('plans')
      .select('*')
      .eq('center_id', center.id)
      .is('deleted_at', null);
    if (center.activeHalaqa?.id) {
      query = query.eq('halaqa_id', center.activeHalaqa.id);
    }
    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) throw error;
    set({
      plans: ((data || []) as PlanRow[]).map((plan) => ({
        id: plan.id,
        studentId: plan.student_id,
        period: plan.period,
        startDate: plan.start_date,
        endDate: plan.end_date,
        unit: plan.unit,
        newAmount: plan.new_amount,
        reviewAmount: plan.review_amount,
        status: plan.status,
        testStatus: plan.test_status || 'not_required',
        completionExamId: plan.completion_exam_id || undefined,
        completedAt: plan.completed_at || undefined,
        notes: plan.notes || undefined,
        createdAt: plan.created_at,
        updatedAt: plan.updated_at || plan.created_at,
      })) as SmartPlan[],
    });
  },

  addSmartPlan: async (plan) => {
    const center = get().currentCenter;
    if (!supabase || !center) throw new Error('الاتصال بقاعدة البيانات غير متاح');
    const { error } = await supabase.from('plans').insert({
      student_id: plan.studentId,
      center_id: center.id,
      halaqa_id: center.activeHalaqa?.id,
      period: plan.period,
      start_date: plan.startDate,
      end_date: plan.endDate,
      unit: plan.unit,
      new_amount: plan.newAmount,
      review_amount: plan.reviewAmount,
      status: plan.status,
      test_status: plan.testStatus,
      completion_exam_id: plan.completionExamId,
      completed_at: plan.completedAt,
      notes: plan.notes,
    });
    if (error) throw error;
    await Promise.all([
      get().fetchPlans(),
      get().updateStudent(plan.studentId, {
        planType: plan.unit,
        planAmount: plan.newAmount,
        reviewPlanAmount: plan.reviewAmount,
      }),
    ]);
  },

  updateSmartPlan: async (id, changes) => {
    if (!supabase) throw new Error('الاتصال بقاعدة البيانات غير متاح');
    const payload: Record<string, unknown> = {};
    if (changes.period !== undefined) payload.period = changes.period;
    if (changes.startDate !== undefined) payload.start_date = changes.startDate;
    if (changes.endDate !== undefined) payload.end_date = changes.endDate;
    if (changes.unit !== undefined) payload.unit = changes.unit;
    if (changes.newAmount !== undefined) payload.new_amount = changes.newAmount;
    if (changes.reviewAmount !== undefined) payload.review_amount = changes.reviewAmount;
    if (changes.status !== undefined) payload.status = changes.status;
    if (changes.testStatus !== undefined) payload.test_status = changes.testStatus;
    if (changes.completionExamId !== undefined) {
      payload.completion_exam_id = changes.completionExamId || null;
    }
    if (changes.completedAt !== undefined) payload.completed_at = changes.completedAt || null;
    if (changes.notes !== undefined) payload.notes = changes.notes || null;
    const { error } = await supabase.from('plans').update(payload).eq('id', id);
    if (error) throw error;
    const plan = get().plans.find((item) => item.id === id);
    if (
      plan &&
      (changes.unit !== undefined ||
        changes.newAmount !== undefined ||
        changes.reviewAmount !== undefined) &&
      plan.status === 'active'
    ) {
      await get().updateStudent(plan.studentId, {
        planType: changes.unit ?? plan.unit,
        planAmount: changes.newAmount ?? plan.newAmount,
        reviewPlanAmount: changes.reviewAmount ?? plan.reviewAmount,
      });
    }
    await get().fetchPlans();
  },

  deleteSmartPlan: async (id) => {
    if (!supabase) throw new Error('الاتصال بقاعدة البيانات غير متاح');
    const { error } = await supabase
      .from('plans')
      .update({ deleted_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw error;
    set((state) => ({ plans: state.plans.filter((plan) => plan.id !== id) }));
  },

  fetchDailyAchievements: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    let query = supabase
      .from('daily_achievements')
      .select('*')
      .eq('center_id', center.id);
    if (center.activeHalaqa?.id) {
      query = query.eq('halaqa_id', center.activeHalaqa.id);
    }
    const { data, error } = await query.order('date', { ascending: false });
    if (error) {
      console.error('Fetch daily achievements error:', error);
      return;
    }
    set({
      dailyAchievements: (data || []).map((row: Record<string, unknown>) => ({
        id: String(row.id),
        studentId: String(row.student_id),
        date: String(row.date),
        source: (row.source === 'automatic' ? 'automatic' : 'manual') as DailyAchievement['source'],
        reason: String(row.reason || 'تميز يومي'),
        actualAmount: Number(row.actual_amount || 0),
        planAmount: Number(row.plan_amount || 0),
        unit: (row.unit || 'ayahs') as DailyAchievement['unit'],
        rewardType: row.reward_type as DailyAchievement['rewardType'],
        rewardDetails: row.reward_details ? String(row.reward_details) : undefined,
        rewardPoints: Number(row.reward_points || 0),
        awardedAt: row.awarded_at ? String(row.awarded_at) : undefined,
        notes: row.notes ? String(row.notes) : undefined,
        createdAt: String(row.created_at),
        updatedAt: String(row.updated_at || row.created_at),
      })),
    });
  },

  saveDailyAchievement: async (achievement) => {
    const center = get().currentCenter;
    if (!supabase || !center) throw new Error('الاتصال بقاعدة البيانات غير متاح');
    const { error } = await supabase.from('daily_achievements').upsert({
      student_id: achievement.studentId,
      center_id: center.id,
      halaqa_id: center.activeHalaqa?.id,
      date: achievement.date,
      source: achievement.source,
      reason: achievement.reason,
      actual_amount: achievement.actualAmount,
      plan_amount: achievement.planAmount,
      unit: achievement.unit,
      notes: achievement.notes,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'student_id,date' });
    if (error) throw error;
    await get().fetchDailyAchievements();
  },

  awardDailyAchievement: async (
    achievement,
    rewardType,
    rewardDetails,
    rewardPoints = 0
  ) => {
    if (!supabase) throw new Error('الاتصال بقاعدة البيانات غير متاح');
    const { error } = await supabase.rpc('award_daily_achievement', {
      p_student_id: achievement.studentId,
      p_date: achievement.date,
      p_source: achievement.source,
      p_reason: achievement.reason,
      p_actual_amount: achievement.actualAmount,
      p_plan_amount: achievement.planAmount,
      p_unit: achievement.unit,
      p_reward_type: rewardType,
      p_reward_details: rewardDetails || null,
      p_reward_points: rewardType === 'points' ? rewardPoints : 0,
      p_notes: achievement.notes || null,
    });
    if (error) throw error;
    await Promise.all([get().fetchDailyAchievements(), get().fetchPoints()]);
  },

  fetchCenterData: async () => {
    const g = get();
    await Promise.all([
      g.fetchStudents(),
      g.fetchAttendance(),
      g.fetchMemorization(),
      g.fetchPoints(),
      g.fetchVacations(),
      g.fetchExams(),
      g.fetchPlans(),
      g.fetchActivities(),
      g.fetchHomeworkGrades(),
      g.fetchMessageTemplates(),
      g.fetchCenterSettings(),
      g.fetchDailyAchievements(),
    ]);
  },

  updateExamScore: async (examId, studentId, degree, notes) => {
    if (supabase) {
      await supabase.from('exam_scores').upsert([{ exam_id: examId, student_id: studentId, degree, notes }], { onConflict: 'exam_id,student_id' });
    }
    set((state) => ({
      exams: state.exams.map(e => {
        if (e.id !== examId) return e;
        const existingIndex = e.studentScores.findIndex(s => s.studentId === studentId);
        const newScores = [...e.studentScores];
        if (existingIndex >= 0) {
          newScores[existingIndex] = { studentId, degree, notes };
        } else {
          newScores.push({ studentId, degree, notes });
        }
        return { ...e, studentScores: newScores };
      })
    }));
  },

  fetchHomeworkGrades: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      let query = supabase
        .from('homework_grades')
        .select('*')
        .eq('center_id', center.id)
        .is('deleted_at', null);
      if (center.activeHalaqa?.id) {
        query = query.eq('halaqa_id', center.activeHalaqa.id);
      }
      const { data, error } = await query.order('date', { ascending: false }).order('created_at', { ascending: false });
      if (error) throw error;
      if (data) {
        const mapped = (data as HomeworkGradeRow[]).map((g) => ({
          id: g.id,
          studentId: g.student_id,
          surah: g.surah,
          fromAyah: g.from_ayah,
          toAyah: g.to_ayah,
          date: g.date,
          gradeMark: g.grade_mark,
          mistakesCount: g.mistakes_count,
          isRevision: g.is_revision,
          remark: g.remark,
          createdAt: g.created_at,
        }));
        set({ homeworkGrades: mapped });
      }
    } catch (err) {
      console.error("Fetch homework grades error:", err);
    }
  },

  addHomeworkGrade: async (record) => {
    const center = get().currentCenter;
    if (!supabase || !center) return false;
    try {
      const recordId = crypto.randomUUID();
      const { error } = await supabase.rpc('save_recitation_record', {
        p_record_id: recordId,
        p_student_id: record.studentId,
        p_surah: record.surah,
        p_from_ayah: record.fromAyah,
        p_to_ayah: record.toAyah,
        p_date: record.date,
        p_grade_mark: record.gradeMark,
        p_mistakes_count: record.mistakesCount,
        p_is_revision: record.isRevision,
        p_remark: record.remark || null,
      });
      if (error) {
        alert(
          'فشل تسجيل التسميع. تأكد من تنفيذ migration المرحلة P5.6: ' +
          error.message,
        );
        return false;
      }
      const now = new Date().toISOString();
      const newRecord: HomeworkGrade = { id: recordId, ...record, createdAt: now };
      set((state) => ({ homeworkGrades: [newRecord, ...state.homeworkGrades] }));
      const isMen = get().centerType === 'men';
      const studentName = get().students.find(s => s.id === record.studentId)?.name || '';
      get().addActivity(
        'grade_added',
        `تم تسجيل تقييم لـ ${isMen ? 'الطالب' : 'الطالبة'}: ${studentName}`,
      );
      try {
        const rebuilt = await rebuildWebMushafProgress(
          record.studentId,
          center.id,
          get().homeworkGrades,
        );
        set((state) => ({
          mushafProgress: [
            ...state.mushafProgress.filter(item => item.studentId !== record.studentId),
            ...rebuilt,
          ],
        }));
      } catch (rebuildError) {
        console.warn('Mushaf rebuild after recitation failed:', rebuildError);
      }
      return true;
    } catch (err) {
      console.error("Add homework grade error:", err);
      return false;
    }
  },

  updateHomeworkGrade: async (id, record) => {
    const center = get().currentCenter;
    if (!supabase || !center) return false;
    const existing = get().homeworkGrades.find(item => item.id === id);
    if (!existing) return false;
    const { error } = await supabase.rpc('save_recitation_record', {
      p_record_id: id,
      p_student_id: record.studentId,
      p_surah: record.surah,
      p_from_ayah: record.fromAyah,
      p_to_ayah: record.toAyah,
      p_date: record.date,
      p_grade_mark: record.gradeMark,
      p_mistakes_count: record.mistakesCount,
      p_is_revision: record.isRevision,
      p_remark: record.remark || null,
    });
    if (error) {
      alert('فشل تعديل سجل التسميع: ' + error.message);
      return false;
    }
    set((state) => ({
      homeworkGrades: state.homeworkGrades.map(item =>
        item.id === id ? { ...item, ...record } : item
      ),
    }));
    try {
      const rebuilt = await rebuildWebMushafProgress(
        record.studentId,
        center.id,
        get().homeworkGrades,
      );
      set((state) => ({
        mushafProgress: [
          ...state.mushafProgress.filter(item => item.studentId !== record.studentId),
          ...rebuilt,
        ],
      }));
    } catch (rebuildError) {
      console.warn('Mushaf rebuild after edit failed:', rebuildError);
    }
    get().addActivity('grade_updated', `تم تعديل سجل تسميع: ${existing.surah}`);
    return true;
  },

  deleteHomeworkGrade: async (id) => {
    const center = get().currentCenter;
    if (!supabase || !center) return false;
    const existing = get().homeworkGrades.find(item => item.id === id);
    if (!existing) return false;
    const { error } = await supabase.rpc('delete_recitation_record', {
      p_record_id: id,
    });
    if (error) {
      alert('فشل حذف سجل التسميع: ' + error.message);
      return false;
    }
    set((state) => ({
      homeworkGrades: state.homeworkGrades.filter(item => item.id !== id),
    }));
    try {
      const rebuilt = await rebuildWebMushafProgress(
        existing.studentId,
        center.id,
        get().homeworkGrades,
      );
      set((state) => ({
        mushafProgress: [
          ...state.mushafProgress.filter(item => item.studentId !== existing.studentId),
          ...rebuilt,
        ],
      }));
    } catch (rebuildError) {
      console.warn('Mushaf rebuild after deletion failed:', rebuildError);
    }
    get().addActivity('grade_deleted', `تم حذف سجل تسميع: ${existing.surah}`);
    return true;
  },

  fetchMushafProgress: async (studentId) => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      const { data, error } = await supabase
        .from('mushaf_progress')
        .select('*')
        .eq('student_id', studentId);
      
      if (error) throw error;
      if (data) {
        const mapped = (data as MushafProgressRow[]).map((p) => ({
          id: p.id,
          studentId: p.student_id,
          hizbNumber: p.hizb_number,
          thumunNumber: p.thumun_number,
          averageGrade: Number(p.average_grade),
          lastGradedDate: p.last_graded_date || undefined,
          isPreMemorized: p.is_pre_memorized,
        }));
        
        set((state) => {
          const filtered = state.mushafProgress.filter(x => x.studentId !== studentId);
          return { mushafProgress: [...filtered, ...mapped] };
        });
      }
    } catch (err) {
      console.error("Fetch mushaf progress error:", err);
    }
  },

  togglePreMemorized: async (studentId, hizbNumber, thumunNumber, isPre) => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      const existing = get().mushafProgress.find(
        p => p.studentId === studentId && p.hizbNumber === hizbNumber && p.thumunNumber === thumunNumber
      );

      const { data, error } = await supabase
        .from('mushaf_progress')
        .upsert([{
          student_id: studentId,
          center_id: center.id,
          hizb_number: hizbNumber,
          thumun_number: thumunNumber,
          average_grade: existing ? existing.averageGrade : 0.0,
          last_graded_date: existing ? existing.lastGradedDate : null,
          is_pre_memorized: isPre
        }], { onConflict: 'student_id,hizb_number,thumun_number' })
        .select()
        .single();

      if (error) throw error;
      if (data) {
        const mapped: MushafProgress = {
          id: data.id,
          studentId: data.student_id,
          hizbNumber: data.hizb_number,
          thumunNumber: data.thumun_number,
          averageGrade: Number(data.average_grade),
          lastGradedDate: data.last_graded_date,
          isPreMemorized: data.is_pre_memorized,
        };

        set((state) => {
          const filtered = state.mushafProgress.filter(
            p => !(p.studentId === studentId && p.hizbNumber === hizbNumber && p.thumunNumber === thumunNumber)
          );
          return { mushafProgress: [...filtered, mapped] };
        });
      }
    } catch (err) {
      console.error("Toggle pre memorized error:", err);
    }
  },

  fetchMessageTemplates: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      const { data, error } = await supabase
        .from('message_templates')
        .select('*')
        .eq('center_id', center.id);

      if (error) throw error;
      if (data) {
        const mapped = (data as MessageTemplateRow[]).map((t) => ({
          centerId: t.center_id,
          type: t.name as 'assignment' | 'grading',
          content: t.body,
        }));
        set({ messageTemplates: mapped });
      }
    } catch (err) {
      console.error("Fetch message templates error:", err);
    }
  },

  saveMessageTemplate: async (type, content) => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      const { data: existing, error: findError } = await supabase
        .from('message_templates')
        .select('id')
        .eq('center_id', center.id)
        .eq('name', type)
        .maybeSingle();

      if (findError) throw findError;

      if (existing) {
        const { error } = await supabase
          .from('message_templates')
          .update({ body: content })
          .eq('id', existing.id);
        if (error) throw error;
      } else {
        const { error } = await supabase
          .from('message_templates')
          .insert([{ center_id: center.id, name: type, body: content }]);
        if (error) throw error;
      }

      await get().fetchMessageTemplates();
    } catch (err) {
      console.error("Save message template error:", err);
    }
  },

  fetchCenterSettings: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      const { data, error } = await supabase
        .from('center_settings')
        .select('currency_symbol')
        .eq('center_id', center.id)
        .maybeSingle();

      if (error) throw error;
      if (data && data.currency_symbol) {
        set({ currencySymbol: data.currency_symbol });
      } else {
        set({ currencySymbol: 'ر.س' });
      }
    } catch (err) {
      console.error("Fetch center settings error:", err);
    }
  },

  updateCurrencySymbol: async (symbol: string) => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    try {
      const { error } = await supabase
        .from('center_settings')
        .upsert([{
          center_id: center.id,
          currency_symbol: symbol
        }], { onConflict: 'center_id' });

      if (error) throw error;
      set({ currencySymbol: symbol });
    } catch (err) {
      console.error("Update currency symbol error:", err);
      const message = err instanceof Error ? err.message : String(err);
      alert("فشل تحديث رمز العملة: " + message);
    }
  },

  fetchPointsConfig: () => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('pointsConfig');
      if (stored) {
        set({ pointsConfig: JSON.parse(stored) });
        return;
      }
    }
    const defaultPointsConfig = {
      daily_memorization: 5,
      extra_memorization: 2,
      early_attendance: 2,
      revision_complete: 3,
      monthly_exam_pass: 10,
      good_appearance: 1,
      late_penalty: -2,
      incomplete_penalty: -3,
      unexcused_absence: -5,
      appearance_violation: -3
    };
    set({ pointsConfig: defaultPointsConfig });
  },

  savePointsConfig: (config: Record<string, number>) => {
    if (typeof window !== 'undefined') {
      localStorage.setItem('pointsConfig', JSON.stringify(config));
    }
    set({ pointsConfig: config });
  },

  fetchSuspendedDates: () => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('suspendedDates');
      if (stored) {
        set({ suspendedDates: JSON.parse(stored) });
        return;
      }
    }
    set({ suspendedDates: [] });
  },

  toggleSuspendedDate: (date: string) => {
    const current = get().suspendedDates;
    const updated = current.includes(date)
      ? current.filter(d => d !== date)
      : [...current, date];
    if (typeof window !== 'undefined') {
      localStorage.setItem('suspendedDates', JSON.stringify(updated));
    }
    set({ suspendedDates: updated });
  },
}));
