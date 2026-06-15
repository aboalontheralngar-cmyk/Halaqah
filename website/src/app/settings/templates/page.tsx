"use client";

import { useState, useEffect, useMemo } from "react";
import { 
  ArrowRight, 
  Save, 
  HelpCircle, 
  CheckCircle, 
  AlertCircle,
  MessageSquare,
  Sparkles,
  Info
} from "lucide-react";
import Link from "next/link";
import { useStore } from "@/store/useStore";

const DEFAULT_GRADING_TEMPLATE = "السلام عليكم ورحمة الله وبركاته، تسميع الطالب {اسم_الطالب} اليوم في سورة {السورة} من آية {من} إلى آية {إلى}:\n- التقييم: {التقييم}\n- الأخطاء: {الأخطاء}\n- ملاحظة: {الملاحظة}";
const DEFAULT_ASSIGNMENT_TEMPLATE = "السلام عليكم ورحمة الله وبركاته، تم تكليف الطالب {اسم_الطالب} بواجب حفظ جديد: من سورة {السورة} آية {من} إلى آية {إلى}. نسأل الله له التوفيق.";

export default function MessageTemplatesPage() {
  const { messageTemplates, fetchMessageTemplates, saveMessageTemplate, loading } = useStore();
  const [activeTab, setActiveTab] = useState<"grading" | "assignment">("grading");
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const [gradingContent, setGradingContent] = useState("");
  const [assignmentContent, setAssignmentContent] = useState("");

  useEffect(() => {
    fetchMessageTemplates();
  }, [fetchMessageTemplates]);

  useEffect(() => {
    const gradingTpl = messageTemplates.find(t => t.type === "grading");
    const assignmentTpl = messageTemplates.find(t => t.type === "assignment");

    setGradingContent(gradingTpl ? gradingTpl.content : DEFAULT_GRADING_TEMPLATE);
    setAssignmentContent(assignmentTpl ? assignmentTpl.content : DEFAULT_ASSIGNMENT_TEMPLATE);
  }, [messageTemplates]);

  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  const handleSave = async () => {
    try {
      if (activeTab === "grading") {
        await saveMessageTemplate("grading", gradingContent);
      } else {
        await saveMessageTemplate("assignment", assignmentContent);
      }
      showToast("تم حفظ قالب الرسالة بنجاح");
    } catch (error) {
      console.error(error);
      showToast("حدث خطأ أثناء حفظ القالب");
    }
  };

  const activeContent = activeTab === "grading" ? gradingContent : assignmentContent;
  const setActiveContent = activeTab === "grading" ? setGradingContent : setAssignmentContent;

  const insertPlaceholder = (placeholder: string) => {
    setActiveContent(prev => prev + placeholder);
  };

  // Preview formatting
  const previewMessage = useMemo(() => {
    const sampleData = {
      studentName: "عبدالرحمن بن خالد",
      surah: "النبأ",
      from: 1,
      to: 10,
      grade: "ممتاز ⭐⭐⭐⭐⭐",
      mistakes: 0,
      note: "تلاوة خاشعة ومخارج حروف سليمة."
    };

    return activeContent
      .replace(/{اسم_الطالب}/g, sampleData.studentName)
      .replace(/{السورة}/g, sampleData.surah)
      .replace(/{من}/g, String(sampleData.from))
      .replace(/{إلى}/g, String(sampleData.to))
      .replace(/{التقييم}/g, sampleData.grade)
      .replace(/{الأخطاء}/g, String(sampleData.mistakes))
      .replace(/{الملاحظة}/g, sampleData.note);
  }, [activeContent]);

  const availablePlaceholders = useMemo(() => {
    const base = [
      { key: "{اسم_الطالب}", label: "اسم الطالب" },
      { key: "{السورة}", label: "السورة" },
      { key: "{من}", label: "من آية" },
      { key: "{إلى}", label: "إلى آية" },
    ];
    if (activeTab === "grading") {
      return [
        ...base,
        { key: "{التقييم}", label: "التقييم المكتوب" },
        { key: "{الأخطاء}", label: "عدد الأخطاء" },
        { key: "{الملاحظة}", label: "الملاحظة" },
      ];
    }
    return base;
  }, [activeTab]);

  return (
    <div className="max-w-5xl mx-auto space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20 relative">
      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed bottom-10 left-10 z-50 bg-gray-900 text-white px-6 py-4 rounded-2xl shadow-2xl flex items-center gap-3 animate-in fade-in slide-in-from-left-4">
          <CheckCircle className="w-5 h-5 text-emerald-400" />
          <span className="font-bold text-xs">{toastMessage}</span>
        </div>
      )}

      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <Link 
            href="/settings" 
            className="inline-flex items-center gap-2 text-xs font-black text-teal-600 dark:text-teal-400 hover:gap-3 transition-all mb-2"
          >
            <ArrowRight className="w-4 h-4" />
            <span>العودة للإعدادات</span>
          </Link>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">قوالب الرسائل لولي الأمر 💬</h1>
          <p className="text-gray-500 dark:text-gray-400 font-medium">قم بصياغة نص الرسالة التي ترسلها لأولياء الأمور عبر واتساب بنقرة واحدة.</p>
        </div>
      </div>

      {/* Tabs */}
      <div className="flex bg-white dark:bg-gray-900 p-2 rounded-[2rem] border border-gray-100 dark:border-gray-800 w-fit mx-auto shadow-sm">
        <button 
          onClick={() => setActiveTab("grading")} 
          className={`px-8 py-3 rounded-2xl text-xs font-black transition-all ${activeTab === "grading" ? "bg-teal-600 text-white shadow-lg" : "text-gray-400"}`}
        >
          تقرير التسميع والتقييم
        </button>
        <button 
          onClick={() => setActiveTab("assignment")} 
          className={`px-8 py-3 rounded-2xl text-xs font-black transition-all ${activeTab === "assignment" ? "bg-teal-600 text-white shadow-lg" : "text-gray-400"}`}
        >
          واجب الحفظ الجديد
        </button>
      </div>

      <div className="grid lg:grid-cols-3 gap-10">
        {/* Editor (2 Columns) */}
        <div className="lg:col-span-2 bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm space-y-6">
          <div>
            <h3 className="text-lg font-black text-gray-900 dark:text-white">تعديل صيغة الرسالة</h3>
            <p className="text-xs text-gray-400 font-bold mt-1">اكتب الرسالة وأدرج المتغيرات الديناميكية لملء البيانات تلقائياً لكل طالب.</p>
          </div>

          {/* Placeholders chips */}
          <div className="space-y-2">
            <span className="block text-[10px] font-black text-gray-400 uppercase tracking-wider">انقر لإدراج المتغيرات:</span>
            <div className="flex flex-wrap gap-2">
              {availablePlaceholders.map(p => (
                <button
                  key={p.key}
                  type="button"
                  onClick={() => insertPlaceholder(p.key)}
                  className="bg-teal-50 hover:bg-teal-100 text-teal-800 dark:bg-teal-950/40 dark:hover:bg-teal-950/70 dark:text-teal-400 border border-teal-100/50 dark:border-teal-900/50 px-3.5 py-2 rounded-xl text-xs font-bold transition-all hover:scale-[1.02]"
                >
                  {p.label} <span className="text-[10px] text-teal-600 font-mono font-medium">{p.key}</span>
                </button>
              ))}
            </div>
          </div>

          {/* Text Area */}
          <div>
            <textarea
              rows={8}
              value={activeContent}
              onChange={e => setActiveContent(e.target.value)}
              className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-5 text-sm font-bold leading-relaxed outline-none focus:ring-2 ring-teal-500/20 text-gray-800 dark:text-gray-200"
              placeholder="اكتب نص الرسالة هنا..."
            />
          </div>

          <div className="flex items-center justify-between pt-4 border-t border-gray-50 dark:border-gray-800">
            <button
              onClick={() => {
                if (activeTab === "grading") {
                  setGradingContent(DEFAULT_GRADING_TEMPLATE);
                } else {
                  setAssignmentContent(DEFAULT_ASSIGNMENT_TEMPLATE);
                }
                showToast("تم استعادة القالب الافتراضي");
              }}
              className="text-xs font-bold text-gray-400 hover:text-gray-600 dark:hover:text-gray-200 transition-colors"
            >
              استعادة الافتراضي
            </button>
            <button
              onClick={handleSave}
              disabled={loading}
              className="bg-teal-600 hover:bg-teal-700 text-white px-8 py-4 rounded-2xl font-black text-xs transition-all flex items-center gap-2 shadow-lg shadow-teal-100 dark:shadow-none"
            >
              <Save className="w-4 h-4" />
              <span>حفظ القالب</span>
            </button>
          </div>
        </div>

        {/* Live Preview (1 Column) */}
        <div className="space-y-6">
          <div className="bg-gradient-to-br from-teal-500 to-emerald-600 rounded-[2.5rem] p-8 text-white shadow-xl space-y-4">
            <div className="flex items-center gap-3">
              <Sparkles className="w-6 h-6 text-teal-100" />
              <h3 className="text-base font-black">معاينة حية للرسالة ✨</h3>
            </div>
            <p className="text-xs text-teal-50 font-bold leading-relaxed">
              هذا مثال لمعاينة كيفية إرسال الرسالة إلى ولي الأمر ببيانات افتراضية:
            </p>
          </div>

          {/* Chat Bubble Container */}
          <div className="bg-gray-100 dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-[3rem] p-6 shadow-inner min-h-[200px] flex flex-col justify-end">
            <div className="bg-white dark:bg-teal-950/20 text-gray-800 dark:text-gray-200 border border-gray-100 dark:border-teal-900/30 rounded-2xl p-5 rounded-tr-none text-xs font-bold leading-relaxed self-start shadow-sm whitespace-pre-wrap max-w-[90%] select-none relative">
              {previewMessage}
              <div className="absolute top-0 -right-2.5 w-3 h-3 bg-white dark:bg-gray-900 [clip-path:polygon(0_0,100%_0,0_100%)]"></div>
            </div>
            <span className="text-[10px] text-gray-400 font-bold mt-3 self-start mr-2">منذ قليل • تقرير تلقائي</span>
          </div>

          <div className="bg-cyan-50/50 dark:bg-cyan-900/10 border border-cyan-100 dark:border-cyan-800 rounded-3xl p-6 flex gap-3 items-start">
            <Info className="w-5 h-5 text-cyan-600 shrink-0 mt-0.5" />
            <div className="space-y-1">
              <h4 className="text-xs font-black text-cyan-950 dark:text-cyan-400">تنبيه حول المتغيرات</h4>
              <p className="text-[11px] text-gray-500 dark:text-gray-400 leading-relaxed font-bold">
                تأكد من عدم تعديل أو حذف الأقواس المحيطة بالمتغيرات مثل <span className="font-mono">{`{اسم_الطالب}`}</span> لتجنب فشل تعبئة البيانات تلقائياً.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
