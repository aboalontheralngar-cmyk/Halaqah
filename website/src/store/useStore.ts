import { create } from 'zustand';
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
  code: string;
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
  qrCode?: string;
  name: string;
  phone: string;
  parentPhone: string;
  age: number;
  level: string;
  joinDate: string;
  photoUrl?: string;
  planType: 'ayahs' | 'pages' | 'lines';
  planAmount: number;
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
  currencySymbol: string;
  loading: boolean;
  darkMode: boolean;
  centerType: 'men' | 'women' | 'mixed';
  user: any | null;
  profile: Profile | null;
  currentCenter: { id: string, name: string, type: 'men' | 'women' | 'mixed', activeHalaqa?: { id: string, name: string } } | null;
  userCenters: { id: string, name: string, type: 'men' | 'women' | 'mixed' }[];
  currentSupervisor: Supervisor | null;
  teachers: Teacher[];
  halaqat: { id: string, name: string, teacher_name?: string }[];

  // Actions
  setUser: (user: any) => void;
  fetchProfile: () => Promise<void>;
  setProfile: (profile: Profile | null) => void;
  createSupervisor: (name: string) => Promise<string | null>;
  joinSupervisor: (code: string) => Promise<boolean>;
  fetchTeachers: () => Promise<void>;
  addTeacher: (email: string, halaqahId?: string) => Promise<void>;
  removeTeacher: (id: string) => Promise<void>;
  setUserCenters: (centers: { id: string, name: string, type: 'men' | 'women' | 'mixed' }[]) => void;
  setCurrentCenter: (center: { id: string, name: string, type: 'men' | 'women' | 'mixed' } | null) => void;
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
  addHomeworkGrade: (record: Omit<HomeworkGrade, 'id'>) => Promise<void>;
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
      
      if (data.role === 'supervisor') {
        const { data: supData } = await supabase
          .from('supervisors')
          .select('*')
          .eq('owner_id', user.id)
          .maybeSingle();
        if (supData) set({ currentSupervisor: { id: supData.id, name: supData.name, code: supData.code } });
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

    const code = 'HAL-' + Math.random().toString(36).substring(2, 8).toUpperCase();
    const { data, error } = await supabase
      .from('supervisors')
      .insert([{ name, code, owner_id: user.id }])
      .select()
      .single();

    if (data && !error) {
      set({ currentSupervisor: { id: data.id, name: data.name, code: data.code } });
      return code;
    }
    return null;
  },

  joinSupervisor: async (code) => {
    if (!supabase) return false;
    const center = get().currentCenter;
    if (!center) return false;

    const { data: supData } = await supabase
      .from('supervisors')
      .select('id')
      .eq('code', code)
      .single();

    if (supData) {
      const { error } = await supabase
        .from('centers')
        .update({ supervisor_id: supData.id })
        .eq('id', center.id);
      
      return !error;
    }
    return false;
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
      const mapped = data.map((t: any) => ({
        id: t.id,
        email: t.email,
        role: t.role,
        halaqahId: t.halaqah_id,
        halaqahName: t.halaqat?.name,
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
        const mapped = data.map((s: any) => ({
          id: s.id,
          qrCode: s.qr_code,
          name: s.name,
          phone: s.phone,
          parentPhone: s.parent_phone,
          age: s.age,
          level: s.level,
          joinDate: s.join_date,
          photoUrl: s.photo_url,
          planType: s.plan_type,
          planAmount: s.plan_amount,
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
    } catch (err: any) {
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
          age: student.age,
          level: student.level,
          join_date: student.joinDate,
          plan_type: student.planType,
          plan_amount: student.planAmount,
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
          name: data.name,
          phone: data.phone,
          parentPhone: data.parent_phone,
          age: data.age,
          level: data.level,
          joinDate: data.join_date,
          planType: data.plan_type,
          planAmount: data.plan_amount,
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
      const mapped: any = {
        name: student.name,
        phone: student.phone,
        parent_phone: student.parentPhone,
        age: student.age,
        level: student.level,
        join_date: student.joinDate,
        plan_type: student.planType,
        plan_amount: student.planAmount,
        status: student.status,
      };
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
        const mapped = data.map((a: any) => ({
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
        const mapped = data.map((m: any) => ({
          id: m.id,
          studentId: m.student_id,
          surah: m.surah,
          fromAyah: m.from_ayah,
          toAyah: m.to_ayah,
          date: m.date,
          degree: m.degree,
          notes: m.notes
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
        const mapped = data.map((p: any) => ({
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
          notes: record.notes
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
          notes: data.notes
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
    const date = new Date().toISOString();
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
        vacations: data.map((v: any) => ({
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
        exams: data.map((e: any) => ({
          id: e.id,
          title: e.title,
          date: e.date,
          type: e.type,
          maxDegree: e.max_degree,
          studentScores: (e.exam_scores || []).map((s: any) => ({
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
      plans: (data || []).map((plan: any) => ({
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
    if (plan && (changes.unit !== undefined || changes.newAmount !== undefined) && plan.status === 'active') {
      await get().updateStudent(plan.studentId, {
        planType: changes.unit ?? plan.unit,
        planAmount: changes.newAmount ?? plan.newAmount,
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
      let query = supabase.from('homework_grades').select('*').eq('center_id', center.id);
      if (center.activeHalaqa?.id) {
        query = query.eq('halaqa_id', center.activeHalaqa.id);
      }
      const { data, error } = await query.order('date', { ascending: false }).order('created_at', { ascending: false });
      if (error) throw error;
      if (data) {
        const mapped = data.map((g: any) => ({
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
    if (!supabase || !center) return;
    try {
      const { data, error } = await supabase
        .from('homework_grades')
        .insert([{
          student_id: record.studentId,
          center_id: center.id,
          halaqa_id: center.activeHalaqa?.id,
          surah: record.surah,
          from_ayah: record.fromAyah,
          to_ayah: record.toAyah,
          date: record.date,
          grade_mark: record.gradeMark,
          mistakes_count: record.mistakesCount,
          is_revision: record.isRevision,
          remark: record.remark,
        }])
        .select()
        .single();
      
      if (error) {
        alert("فشل تسجيل التقييم: " + error.message);
        return;
      }
      
      if (data) {
        const newRecord: HomeworkGrade = {
          id: data.id,
          studentId: data.student_id,
          surah: data.surah,
          fromAyah: data.from_ayah,
          toAyah: data.to_ayah,
          date: data.date,
          gradeMark: data.grade_mark,
          mistakesCount: data.mistakes_count,
          isRevision: data.is_revision,
          remark: data.remark,
          createdAt: data.created_at,
        };
        
        set((state) => ({ homeworkGrades: [newRecord, ...state.homeworkGrades] }));
        
        // Add log activity
        const isMen = get().centerType === 'men';
        const studentName = get().students.find(s => s.id === record.studentId)?.name || '';
        get().addActivity('grade_added', `تم تسجيل تقييم لـ ${isMen ? 'الطالب' : 'الطالبة'}: ${studentName}`);

        // Update mushaf progress logic!
        if (record.gradeMark !== 'absent') {
          // Find surah number
          const surahObj = quranService.getSurahs().find(s => s.name === record.surah);
          if (surahObj) {
            const ayahs = quranService.getAyahRange(surahObj.number, record.fromAyah, record.toAyah);
            if (ayahs.length > 0) {
              let gradeVal = 3.0;
              switch (record.gradeMark) {
                case 'excellent': gradeVal = 5.0; break;
                case 'very_good': gradeVal = 4.0; break;
                case 'good': gradeVal = 3.0; break;
                case 'needs_work': gradeVal = 2.0; break;
              }

              // Keep track of unique (hizb, thumun) covered by this grade
              const coveredKeys = new Set<string>();
              for (const ayah of ayahs) {
                const hizb = ayah.hizb ?? 0;
                const quarter = ayah.quarter ?? 0;
                if (hizb < 1 || hizb > 60 || quarter < 1 || quarter > 240) continue;

                const quarterInHizb = ((quarter - 1) % 4) + 1;
                const thumun1 = (quarterInHizb - 1) * 2 + 1;
                const thumun2 = (quarterInHizb - 1) * 2 + 2;

                coveredKeys.add(`${hizb}_${thumun1}`);
                coveredKeys.add(`${hizb}_${thumun2}`);
              }

              for (const key of coveredKeys) {
                const [hizbStr, thumunStr] = key.split('_');
                const hizb = parseInt(hizbStr);
                const thumun = parseInt(thumunStr);

                // Fetch or compute new progress
                const existing = get().mushafProgress.find(
                  p => p.studentId === record.studentId && p.hizbNumber === hizb && p.thumunNumber === thumun
                );

                let newAvg = gradeVal;
                if (existing && existing.lastGradedDate) {
                  newAvg = (existing.averageGrade + gradeVal) / 2.0;
                }

                const { data: progData, error: progErr } = await supabase
                  .from('mushaf_progress')
                  .upsert([{
                    student_id: record.studentId,
                    center_id: center.id,
                    hizb_number: hizb,
                    thumun_number: thumun,
                    average_grade: newAvg,
                    last_graded_date: record.date,
                    is_pre_memorized: false
                  }], { onConflict: 'student_id,hizb_number,thumun_number' })
                  .select()
                  .single();

                if (!progErr && progData) {
                  const mappedProg: MushafProgress = {
                    id: progData.id,
                    studentId: progData.student_id,
                    hizbNumber: progData.hizb_number,
                    thumunNumber: progData.thumun_number,
                    averageGrade: Number(progData.average_grade),
                    lastGradedDate: progData.last_graded_date,
                    isPreMemorized: progData.is_pre_memorized
                  };

                  set((state) => {
                    const filtered = state.mushafProgress.filter(
                      p => !(p.studentId === record.studentId && p.hizbNumber === hizb && p.thumunNumber === thumun)
                    );
                    return { mushafProgress: [...filtered, mappedProg] };
                  });
                }
              }
            }
          }
        }
      }
    } catch (err) {
      console.error("Add homework grade error:", err);
    }
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
        const mapped = data.map((p: any) => ({
          id: p.id,
          studentId: p.student_id,
          hizbNumber: p.hizb_number,
          thumunNumber: p.thumun_number,
          averageGrade: Number(p.average_grade),
          lastGradedDate: p.last_graded_date,
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
        const mapped = data.map((t: any) => ({
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
      alert("فشل تحديث رمز العملة: " + (err as any).message);
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
