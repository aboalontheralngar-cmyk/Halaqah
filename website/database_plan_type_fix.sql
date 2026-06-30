-- 1. Drop existing constraints
ALTER TABLE students DROP CONSTRAINT IF EXISTS students_plan_type_check;
ALTER TABLE students DROP CONSTRAINT IF EXISTS students_status_check;

-- 2. Re-create constraints with expanded allowed values
ALTER TABLE students ADD CONSTRAINT students_plan_type_check CHECK (plan_type IN ('ayahs', 'pages', 'lines'));
ALTER TABLE students ADD CONSTRAINT students_status_check CHECK (status IN ('active', 'inactive', 'suspended', 'expelled', 'graduated'));
