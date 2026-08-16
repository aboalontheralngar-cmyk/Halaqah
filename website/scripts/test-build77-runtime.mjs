const assert = (condition, message) => {
  if (!condition) throw new Error(message);
};

function topStudents(students, excluded) {
  return students
    .filter((student) => !excluded.has(student.id))
    .filter((student) => student.hasData)
    .sort((a, b) =>
      b.performance - a.performance ||
      b.memorized - a.memorized ||
      a.name.localeCompare(b.name, 'ar'),
    )
    .slice(0, 5);
}

const students = [
  { id: 'new', name: 'طالب مستجد', performance: 99, memorized: 310, hasData: true },
  { id: 'steady', name: 'طالب منتظم', performance: 91, memorized: 1200, hasData: true },
  { id: 'third', name: 'طالب ثالث', performance: 84, memorized: 900, hasData: true },
];
const ranked = topStudents(students, new Set(['new']));
assert(students.length === 3, 'ranking exclusion must not remove the student from report totals');
assert(ranked.length === 2 && ranked[0].id === 'steady', 'excluded newcomer must not occupy first place');

function quranRangeTitle(groupIndex, rows) {
  const positioned = rows.filter((row) => row.surahId != null).sort((a, b) => a.surahId - b.surahId);
  if (!positioned.length) return `مجموعة المستوى ${groupIndex}`;
  const first = positioned[0];
  const last = positioned.at(-1);
  if (first.surahId === last.surahId && first.name) return `مجموعة سورة ${first.name}`;
  if (first.name && last.name) return `من سورة ${first.name} إلى سورة ${last.name}`;
  return `مجموعة المستوى ${groupIndex}`;
}
assert(quranRangeTitle(1, [{ surahId: 2, name: 'البقرة' }, { surahId: 2, name: 'البقرة' }]) === 'مجموعة سورة البقرة', 'single-surah label mismatch');
assert(quranRangeTitle(2, [{ surahId: 2, name: 'البقرة' }, { surahId: 4, name: 'النساء' }]) === 'من سورة البقرة إلى سورة النساء', 'multi-surah label mismatch');

function juzRange(minJuz, maxJuz) {
  if (minJuz === maxJuz) return `الجزء ${minJuz}`;
  const bandStart = Math.floor((minJuz - 1) / 5) * 5 + 1;
  const maxBandStart = Math.floor((maxJuz - 1) / 5) * 5 + 1;
  const bandEnd = Math.min(30, Math.floor((maxJuz - 1) / 5) * 5 + 5);
  if (bandStart === maxBandStart) return `نطاق الأجزاء ${bandStart}–${bandEnd}`;
  return `من الجزء ${minJuz} إلى الجزء ${maxJuz}`;
}
assert(juzRange(6, 9) === 'نطاق الأجزاء 6–10', 'five-juz band label mismatch');
assert(juzRange(4, 12) === 'من الجزء 4 إلى الجزء 12', 'cross-band label mismatch');

console.log('Build 77 runtime parity checks passed.');
