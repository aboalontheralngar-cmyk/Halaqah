-- إزالة الجداول القديمة إذا كانت موجودة (لضمان إعادة بناء نظيفة)
DROP TABLE IF EXISTS center_members CASCADE;
DROP TABLE IF EXISTS activities CASCADE;
DROP TABLE IF EXISTS vacations CASCADE;
DROP TABLE IF EXISTS exam_scores CASCADE;
DROP TABLE IF EXISTS exams CASCADE;
DROP TABLE IF EXISTS points CASCADE;
DROP TABLE IF EXISTS memorization CASCADE;
DROP TABLE IF EXISTS attendance CASCADE;
DROP TABLE IF EXISTS students CASCADE;
DROP TABLE IF EXISTS halaqat CASCADE;
DROP TABLE IF EXISTS centers CASCADE;
DROP TABLE IF EXISTS supervisors CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TYPE IF EXISTS user_role CASCADE;

-- 0. تعريف أنواع المستخدمين
CREATE TYPE user_role AS ENUM ('supervisor', 'center_admin', 'teacher');

-- 1. جدول الملفات الشخصية (Profiles) - يربط بين المستخدم ودوره
CREATE TABLE profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    role user_role DEFAULT 'center_admin',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. جدول الجهات الإشرافية (Supervisors)
CREATE TABLE supervisors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL, -- كود الربط الذي سيستخدمه المركز
    owner_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. جدول المراكز (Centers)
CREATE TABLE centers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    address TEXT,
    type TEXT CHECK (type IN ('men', 'women', 'mixed')) NOT NULL,
    supervisor_id UUID REFERENCES supervisors(id) ON DELETE SET NULL, -- اختياري
    owner_id UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. جدول الحلقات (Halaqat)
CREATE TABLE halaqat (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    teacher_name TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. جدول أعضاء المراكز (Center Members) - للمعلمين والمشرفين الإداريين
CREATE TABLE center_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id), -- اختياري حتى يقوم المعلم بالتسجيل
    email TEXT NOT NULL, -- البريد الإلكتروني للمعلم
    role TEXT CHECK (role IN ('admin', 'teacher')) DEFAULT 'teacher',
    halaqah_id UUID REFERENCES halaqat(id) ON DELETE SET NULL, -- الحلقة المسندة للمعلم
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(center_id, email)
);

-- 3. جدول الطلاب (Students)
CREATE TABLE students (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    halaqa_id UUID REFERENCES halaqat(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    phone TEXT,
    parent_phone TEXT,
    qr_code TEXT UNIQUE NOT NULL DEFAULT gen_random_uuid()::text,
    age INTEGER,
    level TEXT,
    join_date DATE DEFAULT CURRENT_DATE,
    photo_url TEXT,
    plan_type TEXT CHECK (plan_type IN ('ayahs', 'pages', 'lines')) DEFAULT 'ayahs',
    plan_amount INTEGER DEFAULT 5,
    total_memorized INTEGER DEFAULT 0 CHECK (total_memorized BETWEEN 0 AND 6236),
    status TEXT CHECK (status IN ('active', 'inactive', 'suspended', 'expelled', 'graduated')) DEFAULT 'active',
    notes TEXT,
    memorization_direction TEXT CHECK (memorization_direction IN ('asc', 'desc')) DEFAULT 'desc',
    pre_memorized_start_surah INTEGER,
    pre_memorized_start_ayah INTEGER,
    pre_memorized_end_surah INTEGER,
    pre_memorized_end_ayah INTEGER,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. جدول الحضور (Attendance)
CREATE TABLE attendance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    halaqa_id UUID REFERENCES halaqat(id) ON DELETE SET NULL,
    date DATE NOT NULL,
    status TEXT CHECK (status IN ('present', 'absent', 'excused', 'late')) NOT NULL,
    arrival_time TIME,
    absence_reason TEXT,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, date)
);

-- 5. جدول الحفظ (Memorization)
CREATE TABLE memorization (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    halaqa_id UUID REFERENCES halaqat(id) ON DELETE SET NULL,
    surah TEXT NOT NULL,
    from_ayah INTEGER,
    to_ayah INTEGER,
    degree INTEGER CHECK (degree BETWEEN 1 AND 5),
    date DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 6. جدول النقاط والسلوك (Points & Behavior)
CREATE TABLE points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    halaqa_id UUID REFERENCES halaqat(id) ON DELETE SET NULL,
    type TEXT CHECK (type IN ('positive', 'negative')) NOT NULL,
    amount INTEGER NOT NULL,
    reason TEXT NOT NULL,
    date DATE NOT NULL,
    resolved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 7. جدول الامتحانات (Exams)
CREATE TABLE exams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    date DATE NOT NULL,
    type TEXT CHECK (type IN ('oral', 'written')) NOT NULL,
    max_degree INTEGER DEFAULT 100,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 8. جدول درجات الامتحانات (Exam Scores)
CREATE TABLE exam_scores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    exam_id UUID REFERENCES exams(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    degree INTEGER NOT NULL,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(exam_id, student_id)
);

-- 9. جدول الإجازات (Vacations)
CREATE TABLE vacations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    reason TEXT,
    approved BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 10. جدول النشاطات (Activities)
CREATE TABLE activities (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    type TEXT NOT NULL, -- 'student_added', 'attendance_recorded', 'points_awarded', 'exam_created', etc.
    description TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفعيل Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE supervisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE center_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE halaqat ENABLE ROW LEVEL SECURITY;
ALTER TABLE students ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE memorization ENABLE ROW LEVEL SECURITY;
ALTER TABLE points ENABLE ROW LEVEL SECURITY;
ALTER TABLE exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE vacations ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;

-- سياسات الملفات الشخصية (Profiles) - آمنة بدون recursion
DROP POLICY IF EXISTS "Allow individual select" ON profiles;
CREATE POLICY "Allow individual select" ON profiles FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Allow individual insert" ON profiles;
CREATE POLICY "Allow individual insert" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Allow individual update" ON profiles;
CREATE POLICY "Allow individual update" ON profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- سياسات الجهات الإشرافية (Supervisors)
DROP POLICY IF EXISTS "Manage own supervisor" ON supervisors;
CREATE POLICY "Manage own supervisor" ON supervisors FOR ALL USING (auth.uid() = owner_id);

-- سياسات المراكز (Centers) - بسيطة وآمنة بدون recursion
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON centers;
CREATE POLICY "Enable insert for authenticated users only" ON centers
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Enable select for owners" ON centers;
CREATE POLICY "Enable select for owners" ON centers
    FOR SELECT USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Enable update for owners" ON centers;
CREATE POLICY "Enable update for owners" ON centers
    FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS "Enable delete for owners" ON centers;
CREATE POLICY "Enable delete for owners" ON centers
    FOR DELETE USING (auth.uid() = owner_id);

-- سياسات أعضاء المركز (Center Members) - بدون recursion
DROP POLICY IF EXISTS "Manage center members" ON center_members;
CREATE POLICY "Manage center members" ON center_members FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid())) OR
    user_id = auth.uid()
);

-- سياسات الحلقات (Halaqat) - بدون recursion
DROP POLICY IF EXISTS "Access halaqat by center_id" ON halaqat;
CREATE POLICY "Access halaqat by center_id" ON halaqat FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

-- سياسات الطلاب (Students) - بدون recursion
DROP POLICY IF EXISTS "Access students by center_id" ON students;
CREATE POLICY "Access students by center_id" ON students FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

-- سياسات الجداول التابعة (تعطى صلاحية الوصول للأعضاء والمدراء) - بدون recursion
DROP POLICY IF EXISTS "Access attendance by center_id" ON attendance;
CREATE POLICY "Access attendance by center_id" ON attendance FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

DROP POLICY IF EXISTS "Access memorization by center_id" ON memorization;
CREATE POLICY "Access memorization by center_id" ON memorization FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

DROP POLICY IF EXISTS "Access points by center_id" ON points;
CREATE POLICY "Access points by center_id" ON points FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

DROP POLICY IF EXISTS "Access exams by center_id" ON exams;
CREATE POLICY "Access exams by center_id" ON exams FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

DROP POLICY IF EXISTS "Access vacations by center_id" ON vacations;
CREATE POLICY "Access vacations by center_id" ON vacations FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

DROP POLICY IF EXISTS "Access activities by center_id" ON activities;
CREATE POLICY "Access activities by center_id" ON activities FOR ALL USING (
    center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);
