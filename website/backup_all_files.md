# نسخة احتياطية شاملة - مشروع حلقتي (إصدار المراكز المتعددة)

## 1. ملف المتجر (src/store/useStore.ts)
```typescript
import { create } from 'zustand';
import { supabase } from '@/lib/supabase';

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
  resolved?: boolean;
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

interface HalaqahStore {
  students: Student[];
  attendance: AttendanceRecord[];
  memorization: MemorizationRecord[];
  points: PointRecord[];
  exams: Exam[];
  vacations: Vacation[];
  loading: boolean;
  darkMode: boolean;
  centerType: 'men' | 'women';
  user: any | null;
  currentCenter: { id: string, name: string, type: 'men' | 'women', activeHalaqa?: { id: string, name: string } } | null;
  userCenters: { id: string, name: string, type: 'men' | 'women' }[];

  setUser: (user: any) => void;
  setUserCenters: (centers: { id: string, name: string, type: 'men' | 'women' }[]) => void;
  setCurrentCenter: (center: { id: string, name: string, type: 'men' | 'women', activeHalaqa?: { id: string, name: string } } | null) => void;
  setCenterType: (type: 'men' | 'women') => void;
  fetchStudents: () => Promise<void>;
  addStudent: (student: Omit<Student, 'id'>) => Promise<void>;
  updateStudent: (id: string, student: Partial<Student>) => Promise<void>;
  deleteStudent: (id: string) => Promise<void>;
  addAttendance: (record: Omit<AttendanceRecord, 'id'>) => Promise<void>;
  updateAttendance: (id: string, status: AttendanceRecord['status'], extra?: Partial<AttendanceRecord>) => Promise<void>;
  addMemorization: (record: Omit<MemorizationRecord, 'id'>) => Promise<void>;
  addPoints: (record: Omit<PointRecord, 'id'>) => Promise<void>;
  resolveViolation: (pointId: string) => Promise<void>;
  addVacation: (vacation: Omit<Vacation, 'id'>) => Promise<void>;
  deleteVacation: (id: string) => Promise<void>;
  addExam: (exam: Omit<Exam, 'id'>) => Promise<void>;
  updateExamScore: (examId: string, studentId: string, degree: number, notes: string) => Promise<void>;
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
  loading: false,
  centerType: typeof window !== "undefined" ? (localStorage.getItem("centerType") as 'men' | 'women') || 'men' : 'men',
  darkMode: typeof window !== "undefined" ? localStorage.getItem("darkMode") === "true" : false,
  user: null,
  currentCenter: null,
  userCenters: [],

  setUser: (user) => set({ user }),
  setUserCenters: (centers) => set({ userCenters: centers }),
  setCurrentCenter: (center) => {
    if (center) {
      localStorage.setItem("centerType", center.type);
      set({ currentCenter: center, centerType: center.type });
    } else {
      set({ currentCenter: null });
    }
  },
  setCenterType: (type) => {
    localStorage.setItem("centerType", type);
    set({ centerType: type });
  },
  toggleDarkMode: () => {
    const newMode = !get().darkMode;
    localStorage.setItem("darkMode", String(newMode));
    set({ darkMode: newMode });
  },
  setInitialData: () => set({ students: initialStudents }),
  fetchStudents: async () => {
    if (!supabase) return;
    set({ loading: true });
    try {
      const { data, error } = await supabase.from('students').select('*').order('name');
      if (!error && data) set({ students: data as Student[] });
    } finally {
      set({ loading: false });
    }
  },
  addStudent: async (student) => {
    const localId = Date.now().toString();
    set((state) => ({ students: [...state.students, { ...student, id: localId } as Student] }));
  },
  updateStudent: async (id, student) => {
    set((state) => ({
      students: state.students.map(s => s.id === id ? { ...s, ...student } : s)
    }));
  },
  deleteStudent: async (id) => {
    set((state) => ({ students: state.students.filter(s => s.id !== id) }));
  },
  addAttendance: async (record) => {
    set((state) => ({ attendance: [...state.attendance, { ...record, id: Date.now().toString() } as AttendanceRecord] }));
  },
  updateAttendance: async (id, status, extra) => {
    set((state) => ({
      attendance: state.attendance.map(a => a.id === id ? { ...a, status, ...extra } : a)
    }));
  },
  addMemorization: async (record) => {
    set((state) => ({ memorization: [...state.memorization, { ...record, id: Date.now().toString() } as MemorizationRecord] }));
  },
  addPoints: async (record) => {
    set((state) => ({ points: [...state.points, { ...record, id: Date.now().toString(), resolved: record.type === 'positive' } as PointRecord] }));
  },
  resolveViolation: async (pointId) => {
    set((state) => ({
      points: state.points.map(p => p.id === pointId ? { ...p, resolved: true } : p)
    }));
  },
  addVacation: async (vacation) => {
    set((state) => ({ vacations: [...state.vacations, { ...vacation, id: Date.now().toString() } as Vacation] }));
  },
  deleteVacation: async (id) => {
    set((state) => ({ vacations: state.vacations.filter(v => v.id !== id) }));
  },
  addExam: async (exam) => {
    set((state) => ({ exams: [...state.exams, { ...exam, id: Date.now().toString() } as Exam] }));
  },
  updateExamScore: async (examId, studentId, degree, notes) => {
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
```

(تم حفظ كافة الأكواد الحيوية في هذا الملف بنجاح)
