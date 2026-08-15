const DAY_NAMES = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];

const HIJRI_MONTHS = [
  "محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الثانية",
  "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة",
];
/**
 * Returns a YYYY-MM-DD key using the browser/device local calendar date.
 * Never use toISOString() for business date fields: it converts to UTC first
 * and can move users in UTC+ time zones to the previous calendar day.
 */
export function localDateKey(date: Date = new Date()): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

/** Creates a local calendar date from a YYYY-MM-DD key without UTC parsing. */
export function localDateFromKey(value: string): Date {
  const [year, month, day] = value.split("-").map(Number);
  if (!year || !month || !day) return new Date(NaN);
  return new Date(year, month - 1, day);
}

/** Returns a local YYYY-MM-DD key offset by whole calendar days. */
export function localDateKeyOffset(days: number, from: Date = new Date()): string {
  const date = new Date(from.getFullYear(), from.getMonth(), from.getDate());
  date.setDate(date.getDate() + days);
  return localDateKey(date);
}


/**
 * حساب التاريخ الهجري الحقيقي بتقويم أم القرى عبر Intl API
 * (مدمج في كل المتصفحات الحديثة، لا يحتاج مكتبة خارجية)
 */
export function getHijriDate(date: Date = new Date()) {
  const dayName = DAY_NAMES[date.getDay()];

  try {
    const formatter = new Intl.DateTimeFormat("en-u-ca-islamic-umalqura", {
      day: "numeric",
      month: "numeric",
      year: "numeric",
    });
    const parts = formatter.formatToParts(date);
    const day = Number(parts.find((p) => p.type === "day")?.value || 1);
    const month = Number(parts.find((p) => p.type === "month")?.value || 1);
    // قيمة السنة قد تأتي بصيغة "1447 AH" حسب المتصفح
    const yearRaw = parts.find((p) => p.type === "year")?.value || "1447";
    const year = Number(yearRaw.replace(/\D/g, "")) || 1447;
    const monthName = HIJRI_MONTHS[month - 1] || "";

    return {
      full: `${dayName} - ${day} ${monthName} ${year}هـ`,
      day,
      month,
      monthName,
      year,
      dayName,
      isRamadan: month === 9,
    };
  } catch {
    // احتياط في حال عدم دعم التقويم
    return {
      full: dayName,
      day: date.getDate(),
      month: 0,
      monthName: "",
      year: 0,
      dayName,
      isRamadan: false,
    };
  }
}

/** تنسيق تاريخ ميلادي + هجري معاً للعرض في التقارير */
export function getDualDate(date: Date = new Date()) {
  const hijri = getHijriDate(date);
  const gregorian = date.toLocaleDateString("ar-SA-u-ca-gregory", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
  return { hijri: hijri.full, gregorian };
}
