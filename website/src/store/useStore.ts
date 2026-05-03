import { create } from 'zustand';
import { supabase } from '@/lib/supabase';

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
}

export interface Student {
  id: string;
  name: string;
  phone: string;
  parentPhone: string;
  age: number;
  level: string;
  joinDate: string;
  photoUrl?: string;
  planType: 'ayahs' | 'pages';
  planAmount: number;
  status: 'active' | 'inactive';
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

export interface Activity {
  id: string;
  type: string;
  description: string;
  date: string;
}

interface HalaqahStore {
  students: Student[];
  attendance: AttendanceRecord[];
  memorization: MemorizationRecord[];
  points: PointRecord[];
  exams: Exam[];
  vacations: Vacation[];
  activities: Activity[];
  loading: boolean;
  darkMode: boolean;
  centerType: 'men' | 'women';
  user: any | null;
  profile: Profile | null;
  currentCenter: { id: string, name: string, type: 'men' | 'women', activeHalaqa?: { id: string, name: string } } | null;
  userCenters: { id: string, name: string, type: 'men' | 'women' }[];
  currentSupervisor: Supervisor | null;
  teachers: Teacher[];
  halaqat: { id: string, name: string }[];

  // Actions
  setUser: (user: any) => void;
  fetchProfile: () => Promise<void>;
  setProfile: (profile: Profile | null) => void;
  createSupervisor: (name: string) => Promise<string | null>;
  joinSupervisor: (code: string) => Promise<boolean>;
  fetchTeachers: () => Promise<void>;
  addTeacher: (email: string, halaqahId?: string) => Promise<void>;
  removeTeacher: (id: string) => Promise<void>;
  setUserCenters: (centers: { id: string, name: string, type: 'men' | 'women' }[]) => void;
  setCurrentCenter: (center: { id: string, name: string, type: 'men' | 'women' } | null) => void;
  setCenterType: (type: 'men' | 'women') => void;
  fetchStudents: () => Promise<void>;
  addStudent: (student: Omit<Student, 'id'>) => Promise<void>;
  updateStudent: (id: string, student: Partial<Student>) => Promise<void>;
  deleteStudent: (id: string) => Promise<void>;
  fetchHalaqat: () => Promise<void>;
  
  addAttendance: (record: Omit<AttendanceRecord, 'id'>) => Promise<void>;
  updateAttendance: (id: string, status: AttendanceRecord['status'], extra?: Partial<AttendanceRecord>) => Promise<void>;
  
  addMemorization: (record: Omit<MemorizationRecord, 'id'>) => Promise<void>;
  addPoints: (record: Omit<PointRecord, 'id'>) => Promise<void>;
  resolveViolation: (pointId: string) => Promise<void>;

  addVacation: (vacation: Omit<Vacation, 'id'>) => Promise<void>;
  deleteVacation: (id: string) => Promise<void>;
  
  addExam: (exam: Omit<Exam, 'id'>) => Promise<void>;
  updateExamScore: (examId: string, studentId: string, degree: number, notes: string) => Promise<void>;
  
  addActivity: (type: string, description: string) => Promise<void>;
  fetchActivities: () => Promise<void>;

  toggleDarkMode: () => void;
  setInitialData: () => void;
}

const initialStudents: Student[] = [
  { id: '1', name: 'أحمد محمد', phone: '0551234567', parentPhone: '0551234568', age: 12, level: 'متوسط', joinDate: '2024-09-01', planType: 'ayahs', planAmount: 5, status: 'active' },
  { id: '2', name: 'عمر علي', phone: '0552345678', parentPhone: '0552345679', age: 10, level: 'مبتدئ', joinDate: '2024-09-15', planType: 'ayahs', planAmount: 3, status: 'active' },
  { id: '3', name: 'خالد يوسف', phone: '0553456789', parentPhone: '0553456780', age: 14, level: 'متقدم', joinDate: '2024-08-20', planType: 'pages', planAmount: 1, status: 'active' },
];

export const useStore = create<HalaqahStore>((set, get) => ({
  students: initialStudents,
  attendance: [],
  memorization: [],
  points: [],
  exams: [],
  vacations: [],
  activities: [],
  loading: false,
  centerType: typeof window !== "undefined" ? (localStorage.getItem("centerType") as 'men' | 'women') || 'men' : 'men',
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
      .single();

    if (data && !error) {
      set({ profile: { id: data.id, fullName: data.full_name, role: data.role } });
      
      // If supervisor, fetch their supervisor record
      if (data.role === 'supervisor') {
        const { data: supData } = await supabase
          .from('supervisors')
          .select('*')
          .eq('owner_id', user.id)
          .single();
        if (supData) set({ currentSupervisor: { id: supData.id, name: supData.name, code: supData.code } });
      }
    } else {
      // If no profile, check if user is a teacher in any center
      const { data: memberData } = await supabase
        .from('center_members')
        .select('role')
        .eq('user_id', user.id)
        .limit(1);
      
      if (memberData && memberData.length > 0) {
        set({ profile: { id: user.id, fullName: user.user_metadata?.full_name || 'معلم', role: 'teacher' } });
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
        halaqat (name)
      `)
      .eq('center_id', center.id);

    if (!error && data) {
      const mapped = data.map((t: any) => ({
        id: t.id,
        email: t.email,
        role: t.role,
        halaqahId: t.halaqah_id,
        halaqahName: t.halaqat?.name
      }));
      set({ teachers: mapped as Teacher[] });
    }
  },

  addTeacher: async (email, halaqahId) => {
    if (!supabase) return;
    const center = get().currentCenter;
    if (!center) return;

    const { error } = await supabase
      .from('center_members')
      .insert([{ 
        email, 
        center_id: center.id, 
        halaqah_id: halaqahId,
        role: 'teacher' 
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

  setInitialData: () => set({ students: initialStudents }),

  fetchStudents: async () => {
    const center = get().currentCenter;
    if (!supabase || !center) return;
    set({ loading: true });
    try {
      const { data, error } = await supabase
        .from('students')
        .select('*')
        .eq('center_id', center.id)
        .order('name');
      
      if (error) throw error;
      
      if (data) {
        const mapped = data.map((s: any) => ({
          id: s.id,
          name: s.name,
          phone: s.phone,
          parentPhone: s.parent_phone,
          age: s.age,
          level: s.level,
          joinDate: s.join_date,
          photoUrl: s.photo_url,
          planType: s.plan_type,
          planAmount: s.plan_amount,
          status: s.status
        }));
        set({ students: mapped as Student[] });
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
          center_id: center.id 
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
          name: data.name,
          phone: data.phone,
          parentPhone: data.parent_phone,
          age: data.age,
          level: data.level,
          joinDate: data.join_date,
          planType: data.plan_type,
          planAmount: data.plan_amount,
          status: data.status
        };
        set((state) => ({ students: [...state.students, mapped as Student] }));
        get().addActivity('student_added', `تم إضافة ${isMen ? 'طالب' : 'طالبة'} جديد: ${student.name}`);
      }
    }
  },

  updateStudent: async (id, student) => {
    if (supabase) {
      const mapped = {
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
      students: state.students.map(s => s.id === id ? { ...s, ...student } : s)
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
        .insert([{ 
          student_id: record.studentId,
          center_id: center.id,
          date: record.date,
          status: record.status,
          arrival_time: record.arrivalTime,
          absence_reason: record.absenceReason,
          notes: record.notes
        }])
        .select()
        .single();
      if (error) {
        alert("فشل تسجيل الحضور: " + error.message);
        return;
      }
      if (data) {
        set((state) => ({ attendance: [...state.attendance, {
          id: data.id,
          studentId: data.student_id,
          date: data.date,
          status: data.status,
          arrivalTime: data.arrival_time,
          absenceReason: data.absence_reason,
          notes: data.notes
        } as AttendanceRecord] }));
      }
    }
  },

  updateAttendance: async (id, status, extra) => {
    if (supabase) {
      await supabase.from('attendance').update({ status, ...extra }).eq('id', id);
    }
    set((state) => ({
      attendance: state.attendance.map(a => a.id === id ? { ...a, status, ...extra } : a)
    }));
  },

  addMemorization: async (record) => {
    const center = get().currentCenter;
    if (supabase && center) {
      const { data, error } = await supabase
        .from('memorization')
        .insert([{ 
          student_id: record.studentId,
          center_id: center.id,
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
    if (supabase && center) {
      const { data, error } = await supabase
        .from('points')
        .insert([{ 
          student_id: record.studentId,
          center_id: center.id,
          type: record.type,
          amount: record.amount,
          reason: record.reason,
          date: record.date,
          resolved: record.type === 'positive' 
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

  addActivity: async (type, description) => {
    const center = get().currentCenter;
    const date = new Date().toISOString();
    if (supabase && center) {
      const { data, error } = await supabase
        .from('activities')
        .insert([{ type, description, center_id: center.id }])
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
      const { data, error } = await supabase
        .from('activities')
        .select('*')
        .eq('center_id', center.id)
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
        .insert([{ ...vacation, center_id: center.id }])
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
      await supabase.from('vacations').delete().eq('id', id);
    }
    set((state) => ({ vacations: state.vacations.filter(v => v.id !== id) }));
  },

  addExam: async (exam) => {
    const center = get().currentCenter;
    if (supabase && center) {
      const { data, error } = await supabase
        .from('exams')
        .insert([{ title: exam.title, date: exam.date, type: exam.type, max_degree: exam.maxDegree, center_id: center.id }])
        .select()
        .single();
      if (error) {
        alert("فشل إضافة الاختبار: " + error.message);
        return;
      }
      if (data) {
        set((state) => ({ exams: [...state.exams, { ...data, maxDegree: data.max_degree, studentScores: [] } as any] }));
      }
    }
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
}));