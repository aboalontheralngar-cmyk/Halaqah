"use client";

import { useState, useEffect, useRef } from "react";
import { useRouter } from "next/navigation";
import { 
  Dices, 
  User, 
  Users, 
  HelpCircle, 
  Star, 
  ArrowLeft, 
  UserCheck, 
  UserX, 
  RotateCcw,
  BookOpen,
  ClipboardList
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function StudentRafflePage() {
  const router = useRouter();
  const { students = [], fetchStudents } = useStore();
  
  const [activeStudents, setActiveStudents] = useState<any[]>([]);
  const [excludedStudents, setExcludedStudents] = useState<any[]>([]);
  const [selectedStudent, setSelectedStudent] = useState<any | null>(null);
  const [isDrawing, setIsDrawing] = useState(false);
  const [loading, setLoading] = useState(true);

  // Load initial raffle state from localStorage
  useEffect(() => {
    if (typeof window !== "undefined") {
      const savedExclusions = localStorage.getItem("raffle_excluded_students");
      if (savedExclusions) {
        try {
          setExcludedStudents(JSON.parse(savedExclusions));
        } catch (e) {
          console.error(e);
        }
      }
      const savedSelected = localStorage.getItem("raffle_selected_student");
      if (savedSelected) {
        try {
          setSelectedStudent(JSON.parse(savedSelected));
        } catch (e) {
          console.error(e);
        }
      }
    }
  }, []);

  // Save raffle state changes to localStorage
  useEffect(() => {
    if (typeof window !== "undefined") {
      localStorage.setItem("raffle_excluded_students", JSON.stringify(excludedStudents));
    }
  }, [excludedStudents]);

  useEffect(() => {
    if (typeof window !== "undefined") {
      if (selectedStudent) {
        localStorage.setItem("raffle_selected_student", JSON.stringify(selectedStudent));
      } else {
        localStorage.removeItem("raffle_selected_student");
      }
    }
  }, [selectedStudent]);

  // Load students if not loaded
  useEffect(() => {
    const load = async () => {
      await fetchStudents();
      setLoading(false);
    };
    load();
  }, [fetchStudents]);

  // Sync active students
  useEffect(() => {
    if (students && students.length > 0) {
      const active = students.filter((s: any) => s.status === "active");
      setActiveStudents(active);
    }
  }, [students]);

  const availableStudents = activeStudents.filter(
    (s) => !excludedStudents.some((ex) => ex.id === s.id)
  );

  const startDraw = async () => {
    if (availableStudents.length === 0) {
      alert(
        activeStudents.length === 0
          ? "الرجاء إضافة طلاب نشطين أولاً لإجراء القرعة!"
          : "تم استبعاد جميع الطلاب، يرجى إعادة تعيين المستبعدين للبدء من جديد!"
      );
      return;
    }

    setIsDrawing(true);
    setSelectedStudent(null);

    // Ticking delays sequence in ms (starts fast, gradually decelerates)
    const delays = [
      40, 40, 40, 40, 40, 45, 45, 45, 50, 50, 60, 70, 80, 95, 110, 130, 155, 185, 225, 275, 335, 405, 495, 605, 755, 955
    ];

    let lastIndex = -1;

    for (let i = 0; i < delays.length; i++) {
      const delay = delays[i];
      
      let randIndex;
      do {
        randIndex = Math.floor(Math.random() * availableStudents.length);
      } while (availableStudents.length > 1 && randIndex === lastIndex);

      lastIndex = randIndex;
      setSelectedStudent(availableStudents[randIndex]);

      // Vibrate if browser supports it
      if (typeof navigator !== "undefined" && navigator.vibrate) {
        navigator.vibrate(20);
      }

      await new Promise((resolve) => setTimeout(resolve, delay));
    }

    if (typeof navigator !== "undefined" && navigator.vibrate) {
      navigator.vibrate([100, 50, 100]);
    }
    
    setIsDrawing(false);
  };

  const excludeCurrentStudent = (student: any) => {
    if (student && !excludedStudents.some((s) => s.id === student.id)) {
      setExcludedStudents([...excludedStudents, student]);
      setSelectedStudent(null);
    }
  };

  const includeStudent = (student: any) => {
    setExcludedStudents(excludedStudents.filter((s) => s.id !== student.id));
  };

  const resetExclusions = () => {
    setExcludedStudents([]);
    setSelectedStudent(null);
  };

  if (loading) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-teal-500 border-t-transparent rounded-full animate-spin"></div>
      </div>
    );
  }

  return (
    <div className="max-w-4xl mx-auto space-y-8 pb-16 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Back Link & Header */}
      <div className="flex items-center justify-between border-b border-gray-100 dark:border-gray-800 pb-6">
        <div className="space-y-1">
          <h1 className="text-3xl font-black text-gray-900 dark:text-white flex items-center gap-3">
            <Dices className="w-8 h-8 text-teal-600 dark:text-teal-400" />
            قرعة الطلاب العشوائية 🎲
          </h1>
          <p className="text-gray-500 dark:text-gray-400 text-sm font-medium">
            سحب أسماء الطلاب عشوائياً وتوجيههم للتسميع المباشر دون تكرار.
          </p>
        </div>
        <div className="flex items-center gap-3">
          <button 
            onClick={() => {
              if (confirm("هل تريد تصفير القرعة وإعادة إدراج جميع الطلاب؟")) {
                resetExclusions();
              }
            }}
            className="flex items-center gap-2 px-5 py-3 text-xs font-black bg-rose-50 dark:bg-rose-950/20 border border-rose-150 dark:border-rose-900/30 rounded-2xl text-rose-600 dark:text-rose-400 hover:scale-105 transition-all shadow-sm"
          >
            <RotateCcw className="w-4 h-4 animate-spin-hover" /> إعادة تصفير القرعة 🔄
          </button>
          <button 
            onClick={() => router.push("/")}
            className="flex items-center gap-2 px-5 py-3 text-xs font-black bg-white dark:bg-gray-900 border border-gray-150 dark:border-gray-800 rounded-2xl text-gray-500 dark:text-gray-300 hover:bg-gray-50 hover:scale-105 transition-all shadow-sm"
          >
            <ArrowLeft className="w-4 h-4" /> العودة للرئيسية
          </button>
        </div>
      </div>

      {/* Stats Badges */}
      <div className="flex flex-wrap gap-4">
        <span className="inline-flex items-center gap-2 px-4 py-2 bg-teal-50 dark:bg-teal-950/30 border border-teal-150 dark:border-teal-900 rounded-full text-xs font-black text-teal-700 dark:text-teal-400">
          <Users className="w-4 h-4" />
          المتاحون للسحب: {availableStudents.length} / {activeStudents.length}
        </span>
        <span className="inline-flex items-center gap-2 px-4 py-2 bg-orange-50 dark:bg-orange-950/30 border border-orange-150 dark:border-orange-900 rounded-full text-xs font-black text-orange-700 dark:text-orange-400">
          <UserX className="w-4 h-4" />
          المستبعدون مؤقتاً: {excludedStudents.length}
        </span>
      </div>

      {/* Main Spinner Board */}
      <div className="flex flex-col items-center justify-center py-12 px-6 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-[3rem] shadow-xl relative overflow-hidden min-h-[350px]">
        {/* Decorative Background grid pattern */}
        <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/islamic-art.png')] opacity-[0.02] pointer-events-none" />

        {!selectedStudent && !isDrawing ? (
          // Idle State
          <div className="text-center space-y-6 relative z-10 max-w-sm">
            <div className="w-24 h-24 bg-teal-50 dark:bg-teal-900/20 rounded-[2.2rem] flex items-center justify-center mx-auto shadow-md border border-teal-100/50 dark:border-teal-800/30">
              <HelpCircle className="w-12 h-12 text-teal-600 dark:text-teal-400" />
            </div>
            <div className="space-y-2">
              <h2 className="text-2xl font-black text-gray-800 dark:text-white">من هو الطالب المحظوظ؟</h2>
              <p className="text-gray-400 text-xs leading-relaxed font-bold">
                اضغط على زر السحب بالأعفل أو الزر بالأسفل لبدء خلط الأسماء وتحديد الطالب التالي.
              </p>
            </div>
          </div>
        ) : (
          // Drawing / Winner State
          <div className="text-center space-y-8 relative z-10 w-full max-w-md animate-in zoom-in-95 duration-300">
            {!isDrawing && (
              <div className="mx-auto bg-amber-500 text-white text-[10px] font-black px-4 py-1.5 rounded-full w-fit shadow-md flex items-center gap-1.5 animate-bounce">
                <Star className="w-3.5 h-3.5 fill-white" />
                تم الاختيار!
              </div>
            )}
            
            <div className={`p-8 rounded-[2.5rem] border-2 mx-auto w-full transition-all duration-300 ${
              isDrawing 
                ? "border-teal-500/30 bg-teal-50/20 dark:bg-teal-950/10" 
                : "border-amber-400 bg-amber-50/20 dark:bg-amber-950/10 shadow-2xl shadow-amber-500/10 scale-105"
            }`}>
              <div className={`w-20 h-20 rounded-full flex items-center justify-center mx-auto mb-6 text-2xl font-black transition-colors ${
                isDrawing 
                  ? "bg-teal-600 text-white" 
                  : "bg-amber-500 text-white shadow-lg shadow-amber-500/20"
              }`}>
                {selectedStudent?.name ? selectedStudent.name[0] : "؟"}
              </div>
              <h3 className="text-3xl font-black text-gray-800 dark:text-white tracking-tight leading-normal">
                {selectedStudent?.name}
              </h3>
            </div>
          </div>
        )}
      </div>

      {/* Drawer Action Bar */}
      {selectedStudent && !isDrawing && (
        <div className="grid md:grid-cols-3 gap-4 animate-in fade-in duration-300">
          <button
            onClick={() => router.push("/memorization")}
            className="flex items-center justify-center gap-2 p-5 bg-teal-600 hover:bg-teal-700 text-white rounded-2xl text-xs font-black shadow-lg transition-all"
          >
            <BookOpen className="w-5 h-5" /> تسميع ومراجعة الطالب
          </button>
          
          <button
            onClick={() => router.push("/students")}
            className="flex items-center justify-center gap-2 p-5 bg-gray-900 dark:bg-white dark:text-gray-900 text-white rounded-2xl text-xs font-black shadow-lg transition-all"
          >
            <ClipboardList className="w-5 h-5" /> ملف الطالب وسجلاته
          </button>

          <button
            onClick={() => excludeCurrentStudent(selectedStudent)}
            className="flex items-center justify-center gap-2 p-5 bg-orange-50 dark:bg-orange-900/10 hover:bg-orange-100 text-orange-700 dark:text-orange-400 rounded-2xl text-xs font-black transition-all border border-orange-100 dark:border-orange-900/30"
          >
            <UserX className="w-5 h-5" /> استبعاد مؤقت من السحب
          </button>
        </div>
      )}

      {/* Main Trigger Button */}
      <button
        onClick={startDraw}
        disabled={isDrawing || availableStudents.length === 0}
        className={`w-full py-5 rounded-[2rem] text-sm font-black shadow-xl flex items-center justify-center gap-3 transition-all ${
          isDrawing 
            ? "bg-gray-100 dark:bg-gray-800 text-gray-400 cursor-not-allowed" 
            : availableStudents.length === 0
            ? "bg-gray-200 dark:bg-gray-800 text-gray-400 cursor-not-allowed"
            : "bg-gray-900 dark:bg-white dark:text-gray-900 text-white hover:scale-[1.01] hover:shadow-2xl hover:bg-teal-600 hover:text-white"
        }`}
      >
        <Dices className="w-5 h-5 text-teal-400" />
        {isDrawing ? "جاري إجراء السحب العشوائي..." : "🎲 إجراء سحب قرعة للطلاب"}
      </button>

      {/* Excluded List Bar */}
      {excludedStudents.length > 0 && (
        <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-[2.5rem] p-8 space-y-4 shadow-sm">
          <div className="flex items-center justify-between">
            <h4 className="text-sm font-black text-gray-800 dark:text-white flex items-center gap-2">
              <UserX className="w-4 h-4 text-orange-500" />
              الطلاب المستبعدون مؤقتاً ({excludedStudents.length})
            </h4>
            <button 
              onClick={resetExclusions}
              className="text-xs font-black text-teal-600 hover:text-teal-700 flex items-center gap-1 transition-colors"
            >
              <RotateCcw className="w-3.5 h-3.5" /> إعادة إدراج الجميع
            </button>
          </div>
          <div className="flex flex-wrap gap-3">
            {excludedStudents.map((s) => (
              <div 
                key={s.id} 
                className="flex items-center gap-2 bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-750 px-4 py-2 rounded-xl text-xs font-bold text-gray-600 dark:text-gray-300"
              >
                <span>{s.name.split(" ")[0]}</span>
                <button 
                  onClick={() => includeStudent(s)}
                  className="w-4 h-4 bg-gray-200 dark:bg-gray-700 hover:bg-red-50 hover:text-red-500 rounded-full flex items-center justify-center text-[8px] font-black transition-colors"
                >
                  ✕
                </button>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
