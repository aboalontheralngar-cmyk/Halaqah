-- =====================================================================
-- توسعة مخطط قاعدة البيانات — المرحلة 1
-- يُطبَّق بعد database_schema.sql الأساسي
-- يغطي: الصندوق، الخطط، أخطاء التسميع، الصلوات، المظهر،
-- متابعة الغياب، الإشعارات، نماذج الاختبارات، المسابقات، إعدادات
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) أعمدة جديدة على الجداول القائمة
-- ---------------------------------------------------------------------

-- الطلاب: حد الفصل التلقائي، وقت الحضور المحدد، آخر موضع محفوظ، ترتيب
ALTER TABLE students
  ADD COLUMN IF NOT EXISTS dismissal_threshold INTEGER DEFAULT 0, -- 0 = معطل
  ADD COLUMN IF NOT EXISTS scheduled_time TIME,                    -- وقت حضور خاص بالطالب
  ADD COLUMN IF NOT EXISTS last_memorized_surah INTEGER,           -- رقم السورة (1-114)
  ADD COLUMN IF NOT EXISTS last_memorized_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS memorization_direction TEXT
    CHECK (memorization_direction IN ('asc', 'desc')) DEFAULT 'desc', -- desc = من الناس إلى البقرة
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;

-- النقاط: فئة النقطة + سداد المخالفات بالنقاط + مجموعة جماعية
ALTER TABLE points
  ADD COLUMN IF NOT EXISTS category TEXT
    CHECK (category IN (
      'fajr',            -- صلاة الفجر جماعة
      'asr',             -- حضور العصر
      'lecture',         -- حضور محاضرة
      'first_row',       -- الصف الأول
      'fasting',         -- صيام
      'appearance',      -- المظهر
      'memorization',    -- إنجاز حفظ
      'behavior',        -- سلوك عام
      'other'
    )) DEFAULT 'other',
  ADD COLUMN IF NOT EXISTS paid_with_points BOOLEAN DEFAULT FALSE, -- سُددت المخالفة بالنقاط
  ADD COLUMN IF NOT EXISTS group_batch_id UUID,                    -- لربط العقوبات الجماعية
  ADD COLUMN IF NOT EXISTS reduced BOOLEAN DEFAULT FALSE;          -- خُففت العقوبة (لأصحاب الفجر/المحاضرات)

-- الحضور: دقائق التأخير المحسوبة
ALTER TABLE attendance
  ADD COLUMN IF NOT EXISTS late_minutes INTEGER DEFAULT 0;

-- أعضاء المركز: كود دعوة المعلم
ALTER TABLE center_members
  ADD COLUMN IF NOT EXISTS invitation_code TEXT;

-- الحفظ: نوع الجلسة (حفظ جديد / مراجعة) وعدد الأسطر
ALTER TABLE memorization
  ADD COLUMN IF NOT EXISTS session_type TEXT
    CHECK (session_type IN ('new', 'review')) DEFAULT 'new',
  ADD COLUMN IF NOT EXISTS lines_count INTEGER;

-- ---------------------------------------------------------------------
-- 2) صندوق الحلقة (المالية)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fund_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE SET NULL, -- اختياري (المصروفات بلا طالب)
    type TEXT CHECK (type IN ('subscription', 'penalty', 'expense', 'donation')) NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    note TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 3) الخطط (أسبوعية / شهرية)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    period TEXT CHECK (period IN ('weekly', 'monthly')) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    -- المقرر
    unit TEXT CHECK (unit IN ('ayahs', 'pages', 'lines')) DEFAULT 'ayahs',
    new_amount INTEGER NOT NULL DEFAULT 5,       -- مقرر الحفظ الجديد
    review_amount INTEGER NOT NULL DEFAULT 10,   -- مقرر المراجعة
    review_direction TEXT CHECK (review_direction IN ('asc', 'desc')) DEFAULT 'asc',
    auto_increase BOOLEAN DEFAULT FALSE,          -- زيادة المقرر تلقائياً مع التقدم
    auto_increase_step INTEGER DEFAULT 1,
    status TEXT CHECK (status IN ('active', 'completed', 'cancelled')) DEFAULT 'active',
    completed_at TIMESTAMP WITH TIME ZONE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 4) سجل أخطاء التسميع
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS recitation_errors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    memorization_id UUID REFERENCES memorization(id) ON DELETE CASCADE, -- جلسة التسميع
    surah INTEGER NOT NULL,        -- رقم السورة
    ayah INTEGER NOT NULL,
    error_type TEXT CHECK (error_type IN (
      'forgetting',   -- نسيان
      'tashkeel',     -- خطأ تشكيل
      'tajweed',      -- خطأ تجويد
      'substitution', -- إبدال كلمة
      'hesitation'    -- تردد
    )) NOT NULL,
    note TEXT,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 5) متابعة الصلوات (الفجر، الصف الأول...)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS prayer_tracking (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    prayer TEXT CHECK (prayer IN ('fajr', 'dhuhr', 'asr', 'maghrib', 'isha')) NOT NULL,
    status TEXT CHECK (status IN ('congregation', 'alone', 'missed')) NOT NULL,
    first_row BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(student_id, date, prayer)
);

-- ---------------------------------------------------------------------
-- 6) متابعة المظهر (عقوبة مستمرة حتى التعديل)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS appearance_checks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    issue TEXT NOT NULL,                 -- وصف الملاحظة
    status TEXT CHECK (status IN ('open', 'resolved')) DEFAULT 'open',
    opened_at DATE NOT NULL DEFAULT CURRENT_DATE,
    resolved_at DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 7) متابعة الغياب (السؤال عن الغائب بعد يومين)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS absence_followups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    absence_start DATE NOT NULL,           -- بداية فترة الغياب
    days_absent INTEGER DEFAULT 0,
    reason TEXT CHECK (reason IN ('sickness', 'work', 'travel', 'family', 'unknown', 'other')),
    reason_note TEXT,
    status TEXT CHECK (status IN ('pending', 'contacted', 'resolved')) DEFAULT 'pending',
    contacted_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 8) الإشعارات وقوالب الرسائل
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    type TEXT CHECK (type IN (
      'low_performance',  -- تدني المستوى
      'repeated_absence', -- غياب متكرر
      'plan_completed',   -- إتمام الخطة (مكافأة ولي الأمر)
      'dismissal_warning',-- إنذار فصل
      'general'
    )) NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    sent_via TEXT CHECK (sent_via IN ('app', 'whatsapp', 'none')) DEFAULT 'none',
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS message_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,            -- اسم القالب (إهمال / غياب / تقرير شهري...)
    body TEXT NOT NULL,            -- يدعم متغيرات مثل {student_name} {date}
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 9) نماذج الاختبارات بباركود + امتحان المراجعة الشهري
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS exam_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    type TEXT CHECK (type IN ('monthly_review', 'custom')) DEFAULT 'custom',
    surah_from INTEGER,            -- نطاق الاختبار
    surah_to INTEGER,
    questions_count INTEGER DEFAULT 10,
    barcode_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS exam_questions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID REFERENCES exam_templates(id) ON DELETE CASCADE,
    question_order INTEGER NOT NULL,
    surah INTEGER NOT NULL,
    from_ayah INTEGER NOT NULL,
    to_ayah INTEGER NOT NULL,
    question_type TEXT CHECK (question_type IN (
      'recite_from',     -- اقرأ من قوله تعالى
      'complete_ayah',   -- أكمل الآية
      'ayah_location'    -- أين توجد هذه الآية
    )) DEFAULT 'recite_from',
    answer_text TEXT,    -- الجواب (للامتحان الأوفلاين المطبوع)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ربط الامتحان الفعلي بالنموذج
ALTER TABLE exams
  ADD COLUMN IF NOT EXISTS template_id UUID REFERENCES exam_templates(id) ON DELETE SET NULL;

-- ---------------------------------------------------------------------
-- 10) مسابقة التلاوة الأسبوعية
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS weekly_competitions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    title TEXT NOT NULL DEFAULT 'مسابقة التلاوة الأسبوعية',
    status TEXT CHECK (status IN ('open', 'closed')) DEFAULT 'open',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS competition_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    competition_id UUID REFERENCES weekly_competitions(id) ON DELETE CASCADE,
    student_id UUID REFERENCES students(id) ON DELETE CASCADE,
    score INTEGER CHECK (score BETWEEN 0 AND 100),
    rank INTEGER,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(competition_id, student_id)
);

-- ---------------------------------------------------------------------
-- 11) إعدادات المركز (توقيت رمضان، حد التأخير، تخفيف العقوبات...)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS center_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE UNIQUE,
    session_start_time TIME DEFAULT '16:00',     -- وقت بداية الحلقة
    late_threshold_minutes INTEGER DEFAULT 10,    -- حد التأخير
    ramadan_mode BOOLEAN DEFAULT FALSE,
    ramadan_start_time TIME,                      -- توقيت رمضان
    penalty_reduction_enabled BOOLEAN DEFAULT TRUE, -- تخفيف العقوبة لأصحاب الفجر/المحاضرات
    penalty_reduction_percent INTEGER DEFAULT 50 CHECK (penalty_reduction_percent BETWEEN 0 AND 100),
    dismissal_absence_days INTEGER DEFAULT 0,     -- فصل تلقائي بعد كذا يوم غياب (0 = معطل)
    subscription_amount NUMERIC(10, 2) DEFAULT 0, -- قيمة الاشتراك الشهري للصندوق
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ---------------------------------------------------------------------
-- 11-b) التقييمات المتقدمة وتقدم المصحف للطلاب
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS homework_grades (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    halaqa_id UUID REFERENCES halaqat(id) ON DELETE CASCADE,
    surah TEXT NOT NULL,
    from_ayah INTEGER NOT NULL,
    to_ayah INTEGER NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    grade_mark TEXT NOT NULL CHECK (grade_mark IN ('excellent', 'very_good', 'good', 'needs_work', 'absent')),
    mistakes_count INTEGER DEFAULT 0,
    is_revision BOOLEAN DEFAULT FALSE,
    remark TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS mushaf_progress (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
    center_id UUID REFERENCES centers(id) ON DELETE CASCADE,
    hizb_number INTEGER NOT NULL CHECK (hizb_number BETWEEN 1 AND 60),
    thumun_number INTEGER NOT NULL CHECK (thumun_number BETWEEN 1 AND 8),
    average_grade NUMERIC(3,2) DEFAULT 0.0,
    last_graded_date DATE,
    is_pre_memorized BOOLEAN DEFAULT FALSE,
    UNIQUE(student_id, hizb_number, thumun_number)
);

-- ---------------------------------------------------------------------
-- 12) فهارس للأداء
-- ---------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_fund_tx_center_date ON fund_transactions(center_id, date);
CREATE INDEX IF NOT EXISTS idx_plans_student ON plans(student_id, status);
CREATE INDEX IF NOT EXISTS idx_recitation_errors_student ON recitation_errors(student_id, date);
CREATE INDEX IF NOT EXISTS idx_prayer_student_date ON prayer_tracking(student_id, date);
CREATE INDEX IF NOT EXISTS idx_appearance_open ON appearance_checks(center_id, status);
CREATE INDEX IF NOT EXISTS idx_absence_followups_pending ON absence_followups(center_id, status);
CREATE INDEX IF NOT EXISTS idx_notifications_center ON notifications(center_id, created_at);
CREATE INDEX IF NOT EXISTS idx_competition_entries ON competition_entries(competition_id, score);
CREATE INDEX IF NOT EXISTS idx_points_category ON points(center_id, category, date);
CREATE INDEX IF NOT EXISTS idx_attendance_student_date ON attendance(student_id, date);

-- ---------------------------------------------------------------------
-- 13) تفعيل RLS وسياسات الوصول للجداول الجديدة
-- ---------------------------------------------------------------------
ALTER TABLE fund_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE recitation_errors ENABLE ROW LEVEL SECURITY;
ALTER TABLE prayer_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE appearance_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE absence_followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE exam_questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_competitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE competition_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE center_settings ENABLE ROW LEVEL SECURITY;

-- سياسة موحدة: مالك المركز أو عضو فيه
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'fund_transactions', 'plans', 'recitation_errors', 'prayer_tracking',
    'appearance_checks', 'absence_followups', 'notifications',
    'message_templates', 'exam_templates', 'weekly_competitions', 'center_settings'
  ]
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS "Access %I by center" ON %I', t, t);
    EXECUTE format($f$
      CREATE POLICY "Access %I by center" ON %I FOR ALL USING (
        center_id IN (SELECT id FROM centers WHERE owner_id = auth.uid()) OR
        center_id IN (SELECT center_id FROM center_members WHERE user_id = auth.uid())
      )
    $f$, t, t);
  END LOOP;
END $$;

-- جداول تابعة بلا center_id مباشر (عبر الأب)
DROP POLICY IF EXISTS "Access exam_questions via template" ON exam_questions;
CREATE POLICY "Access exam_questions via template" ON exam_questions FOR ALL USING (
  template_id IN (
    SELECT id FROM exam_templates WHERE
      center_id IN (SELECT id FROM centers WHERE owner_id = auth.uid()) OR
      center_id IN (SELECT center_id FROM center_members WHERE user_id = auth.uid())
  )
);

DROP POLICY IF EXISTS "Access competition_entries via competition" ON competition_entries;
CREATE POLICY "Access competition_entries via competition" ON competition_entries FOR ALL USING (
  competition_id IN (
    SELECT id FROM weekly_competitions WHERE
      center_id IN (SELECT id FROM centers WHERE owner_id = auth.uid()) OR
      center_id IN (SELECT center_id FROM center_members WHERE user_id = auth.uid())
  )
);

-- =====================================================================
-- 14) سياسة إضافية لـ center_members لتمكين المعلمين من قراءة صفوفهم
-- =====================================================================
DROP POLICY IF EXISTS "Allow select center_members by user or email" ON center_members;
CREATE POLICY "Allow select center_members by user or email" ON center_members
  FOR SELECT USING (
    user_id = auth.uid() OR
    email = auth.jwt()->>'email'
  );

-- =====================================================================
-- 15) وظيفة آمنة للتحقق من كود دعوة المعلم دون الحاجة لتسجيل دخول مسبق
-- =====================================================================
CREATE OR REPLACE FUNCTION get_member_by_code(code_to_check TEXT)
RETURNS TABLE (
    id UUID,
    center_id UUID,
    email TEXT,
    role TEXT,
    halaqah_id UUID,
    user_id UUID,
    is_registered BOOLEAN
) SECURITY DEFINER AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.id, 
        cm.center_id, 
        cm.email, 
        cm.role, 
        cm.halaqah_id, 
        cm.user_id,
        EXISTS (SELECT 1 FROM auth.users u WHERE LOWER(u.email) = LOWER(cm.email)) AS is_registered
    FROM center_members cm
    WHERE cm.invitation_code = code_to_check
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 16) وظيفة لربط حساب مستخدم بكود دعوة المعلم عند تعيين كلمة المرور
-- =====================================================================
CREATE OR REPLACE FUNCTION activate_member_by_code(code_to_check TEXT, new_user_id UUID)
RETURNS BOOLEAN SECURITY DEFINER AS $$
DECLARE
    updated BOOLEAN := FALSE;
BEGIN
    UPDATE center_members
    SET user_id = new_user_id
    WHERE invitation_code = code_to_check AND user_id IS NULL;
    
    IF FOUND THEN
        updated := TRUE;
    END IF;
    
    RETURN updated;
END;
$$ LANGUAGE plpgsql;

-- =====================================================================
-- 17) تحديد عدد المراكز لـ 4 كحد أقصى لكل مستخدم (حساب مالك)
-- =====================================================================
CREATE OR REPLACE FUNCTION limit_centers_per_user()
RETURNS TRIGGER AS $$
DECLARE
    center_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO center_count
    FROM centers
    WHERE owner_id = NEW.owner_id;
    
    IF center_count >= 4 THEN
        RAISE EXCEPTION 'لا يمكنك إنشاء أكثر من 4 مراكز كحد أقصى للحساب الواحد. يرجى حذف أحد المراكز الحالية أولاً.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_limit_centers ON centers;
CREATE TRIGGER trigger_limit_centers
BEFORE INSERT ON centers
FOR EACH ROW
EXECUTE FUNCTION limit_centers_per_user();

-- =====================================================================
-- 18) تنظيف المراكز الفارغة المهملة (أكبر من 10 أيام وبدون أي حلقة)
-- =====================================================================
CREATE OR REPLACE FUNCTION cleanup_empty_centers()
RETURNS void SECURITY DEFINER AS $$
BEGIN
    DELETE FROM centers
    WHERE created_at < NOW() - INTERVAL '10 days'
      AND NOT EXISTS (
        SELECT 1 FROM halaqat WHERE halaqat.center_id = centers.id
      );
END;
$$ LANGUAGE plpgsql;

-- تفعيل امتداد pg_cron وجدولة الدالة يومياً الساعة 12:00 بعد منتصف الليل
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.schedule(
  'cleanup-empty-centers-daily',
  '0 0 * * *',
  'SELECT cleanup_empty_centers()'
);


