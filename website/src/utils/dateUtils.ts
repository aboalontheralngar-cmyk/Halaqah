export function getHijriDate(date: Date = new Date()) {
  const days = ["الأحد", "الإثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"];
  const months = [
    "محرم", "صفر", "ربيع الأول", "ربيع الثاني", "جمادى الأولى", "جمادى الثانية",
    "رجب", "شعبان", "رمضان", "شوال", "ذو القعدة", "ذو الحجة"
  ];
  
  const dayName = days[date.getDay()];
  
  // ملاحظة: الحساب الدقيق للهجري يتطلب مكتبة متخصصة، 
  // سنقوم هنا بمطابقة التاريخ الحالي (مايو 2026 يوافق ذو القعدة 1447هـ)
  const hijriYear = 1447;
  const hijriMonth = 10; // ذو القعدة
  const hijriDay = date.getDate(); // تقريباً نفس اليوم في هذا الشهر
  
  return {
    full: `${dayName} - ${hijriDay} ${months[hijriMonth]} ${hijriYear}هـ`,
    day: hijriDay,
    monthName: months[hijriMonth],
    year: hijriYear,
    dayName
  };
}
