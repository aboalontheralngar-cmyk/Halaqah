import {
  Archive,
  Database,
  FileCheck2,
  LockKeyhole,
  ShieldCheck,
  Users,
} from "lucide-react";

const sections = [
  {
    icon: Database,
    title: "البيانات التي يعالجها التطبيق",
    body: "بيانات تعريف الطالب وولي الأمر، الحضور والإجازات، الحفظ والمراجعة والخطط والاختبارات، النقاط والملاحظات، وبيانات التشغيل اللازمة للمزامنة والنسخ الاحتياطي.",
  },
  {
    icon: FileCheck2,
    title: "الغرض من المعالجة",
    body: "إدارة الحلقة ومتابعة تقدم الطالب وإصدار التقارير والتواصل مع ولي الأمر وحماية السجلات من الفقد. لا تُباع البيانات ولا تُستخدم لبناء ملفات إعلانية.",
  },
  {
    icon: LockKeyhole,
    title: "الحماية والنسخ الاحتياطي",
    body: "تُشفّر النسخ الجديدة قبل رفعها إلى مساحة التخزين الخاصة بالحساب. لا تُسجّل كلمات المرور أو عبارات حماية النسخ أو الرموز السرية في سجل التدقيق.",
  },
  {
    icon: Archive,
    title: "الاحتفاظ والأرشفة",
    body: "تُؤرشف بيانات الطالب قبل الحذف لحماية تاريخه وتقاريره. يحتفظ المركز بالسجلات والنسخ للمدة التي يعتمدها وفق الأنظمة المحلية، ثم يحذفها بصلاحية إدارية موثقة.",
  },
  {
    icon: Users,
    title: "المشاركة وحقوق ولي الأمر",
    body: "تُشارك التقارير فقط مع ولي الأمر أو الجهة المخولة. يمكن طلب تصحيح البيانات أو تصديرها، وعلى مدير المركز التحقق من هوية مقدم الطلب قبل الإفصاح أو الحذف.",
  },
  {
    icon: ShieldCheck,
    title: "المسؤولية والاستجابة للحوادث",
    body: "مدير المركز مسؤول عن إدارة حسابات المعلمين والصلاحيات. عند الاشتباه بفقد البيانات تُوقف الجلسة المتأثرة، وتُغيّر بيانات الدخول، ويُراجع سجل التدقيق قبل الاستعادة على بيئة تجريبية.",
  },
];

export default function PrivacyPage() {
  return (
    <main className="max-w-5xl mx-auto space-y-8 pb-20" dir="rtl">
      <header className="rounded-[2.5rem] bg-gradient-to-l from-teal-700 to-teal-500 p-8 md:p-10 text-white shadow-xl">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-white/15 flex items-center justify-center">
            <ShieldCheck className="w-8 h-8" />
          </div>
          <div>
            <h1 className="text-2xl md:text-3xl font-black">سياسة الخصوصية وإدارة البيانات</h1>
            <p className="text-teal-50 mt-2 text-sm">بيان تشغيلي واضح لحماية بيانات طلاب حلقات القرآن الكريم.</p>
          </div>
        </div>
      </header>

      <div className="rounded-3xl border border-amber-200 bg-amber-50 dark:bg-amber-950/20 dark:border-amber-900 p-6 text-amber-950 dark:text-amber-100 leading-8">
        مدير المركز هو المسؤول عن إبلاغ أولياء الأمور واعتماد مدد الاحتفاظ والحذف المناسبة وفق الأنظمة المعمول بها في بلده.
      </div>

      <section className="grid md:grid-cols-2 gap-5">
        {sections.map(({ icon: Icon, title, body }) => (
          <article key={title} className="rounded-[2rem] bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-7 shadow-sm">
            <div className="w-12 h-12 rounded-2xl bg-teal-50 dark:bg-teal-900/20 flex items-center justify-center mb-5">
              <Icon className="w-6 h-6 text-teal-600 dark:text-teal-400" />
            </div>
            <h2 className="font-black text-gray-900 dark:text-white mb-3">{title}</h2>
            <p className="text-sm text-gray-600 dark:text-gray-300 leading-7">{body}</p>
          </article>
        ))}
      </section>

      <p className="text-center text-xs text-gray-400">آخر تحديث: 13 يوليو 2026</p>
    </main>
  );
}
