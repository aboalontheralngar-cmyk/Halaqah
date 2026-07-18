import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const requireAll = (source, fragments, label) => {
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`${label} is missing: ${fragment}`);
    }
  }
};

requireAll(read('lib/models/student.dart'), [
  'String studentCode',
  'int reviewPlanAmount',
  "'student_code': studentCode",
  "return 'HAL-${chunks.join('-')}';",
], 'Student identity');

requireAll(read('lib/services/database_service.dart'), [
  'version: 18',
  'recalculateDailyRecitationPoints',
  'idx_students_student_code',
  'behavior_point_id TEXT',
  'review_plan_amount INTEGER',
], 'SQLite P7 contract');

requireAll(read('lib/services/pdf_service.dart'), [
  'generateStudentQrCards',
  'generateHalaqahManagementSummary',
  'generateAllSmartPlans',
  'QrService.generateQrData(report.student.qrCode)',
], 'P7 print contract');

requireAll(read('lib/services/recitation_points_policy.dart'), [
  'fullPlanPoints = 5',
  'maximumDailyPoints = 10',
  'ratio >= 2',
  'ratio >= 1.5',
  'ratio >= 1.25',
], 'Recitation points policy');

requireAll(read('lib/screens/plans/plans_screen.dart'), [
  '_createAndPrintAllPlans',
  'student.reviewPlanAmount',
  'getSmartPlanGateReason',
], 'Bulk plan UI');

requireAll(read('lib/screens/students/student_raffle_screen.dart'), [
  '_excludeAbsent',
  '_excludeExcused',
  'raffle_exclude_excused',
], 'Raffle attendance filters');

requireAll(read('website/supabase/migrations/20260714000100_p7_student_identity_foundation.sql'), [
  'create unique index if not exists uq_students_student_code',
  'generate_student_code',
  'not an authentication secret',
], 'Cloud student identity');

requireAll(read('website/supabase/migrations/20260714000200_p7_fund_penalty_link.sql'), [
  'behavior_point_id',
  'references public.points(id)',
], 'Fund penalty link');

requireAll(read('website/supabase/migrations/20260714000300_p7_student_review_plan.sql'), [
  'review_plan_amount',
  'between 1 and 999',
], 'Student review plan');

requireAll(read('website/database_schema.sql'), [
  'student_code TEXT UNIQUE NOT NULL',
  'review_plan_amount INTEGER NOT NULL DEFAULT 10',
], 'Fresh database student identity');

requireAll(read('website/database_schema_extensions.sql'), [
  'behavior_point_id UUID REFERENCES points(id)',
  'idx_fund_transactions_behavior_point',
], 'Fresh database fund link');

requireAll(read('website/src/store/useStore.ts'), [
  'studentCode?: string',
  'reviewPlanAmount: number',
  'review_plan_amount: student.reviewPlanAmount',
], 'Web student profile parity');

console.log('P7.1 contract passed: identity, QR, fair points, reports, fund links, and bulk plans.');
