const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

function proportionalPoints(actual, plan, reward = 5, mode = 'exact') {
  const ratio = Math.max(0, Math.min(1, actual / (plan <= 0 ? 1 : plan)));
  const raw = reward * ratio;
  if (mode === 'floor') return Math.floor(raw);
  if (mode === 'ceil') return Math.ceil(raw);
  if (mode === 'nearest') return Math.round(raw);
  return Math.round(raw * 100) / 100;
}
assert(proportionalPoints(10, 20, 5) === 2.5, 'exact point ratio must preserve 2.5');
assert(proportionalPoints(1, 100, 5) === 0.05, 'small achievement must preserve its real fraction');
assert(proportionalPoints(10, 20, 5, 'floor') === 2, 'floor compatibility mismatch');
assert(proportionalPoints(10, 20, 5, 'ceil') === 3, 'ceil compatibility mismatch');

function batchStudents(students, excluded) {
  return students.filter((student) => !excluded.has(student.id));
}
const batch = batchStudents(
  [{ id: 'old' }, { id: 'new' }, { id: 'other' }],
  new Set(['new']),
);
assert(batch.length === 2 && !batch.some((item) => item.id === 'new'), 'batch PDF exclusion must remove page generation for excluded student');

function payments(rows) {
  return rows.filter((row) => row.type !== 'expense' && row.amount > 0);
}
const paid = payments([
  { type: 'subscription', amount: 50 },
  { type: 'penalty', amount: 10 },
  { type: 'expense', amount: 20 },
]);
assert(paid.reduce((sum, row) => sum + row.amount, 0) === 60, 'student payment total must exclude fund expenses');

function friday(mode) {
  if (mode === 'holiday') return { study: false, mem: false, review: false, sard: false };
  if (mode === 'full_plan') return { study: true, mem: true, review: true, sard: true };
  return { study: true, mem: false, review: false, sard: true, catchup: true };
}
assert(friday('catchup_recitation').catchup && friday('catchup_recitation').sard, 'Friday catch-up mode must retain sard');
assert(!friday('catchup_recitation').mem && !friday('catchup_recitation').review, 'Friday catch-up must pause new memorization/review');
assert(friday('full_plan').mem && friday('full_plan').review, 'Friday full-plan mode mismatch');

function attendanceGuard(status) {
  return status === 'absent' || status === 'excused' ? 'confirm_present' : 'continue';
}
assert(attendanceGuard('excused') === 'confirm_present', 'excused recitation must require attendance correction');
assert(attendanceGuard('present') === 'continue', 'present student must not be blocked');

console.log('Build 78 runtime parity checks passed.');
