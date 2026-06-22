"use client";

import { useState, useEffect, useMemo } from "react";
import { X, RefreshCw, Bookmark, Calendar, Check, Info } from "lucide-react";
import { useStore, Student, MushafProgress } from "@/store/useStore";
import { quranService } from "@/services/quranService";

interface MushafVisualizerProps {
  student: Student;
  onClose: () => void;
}

export default function MushafVisualizer({ student, onClose }: MushafVisualizerProps) {
  const { mushafProgress, fetchMushafProgress, togglePreMemorized } = useStore();
  const [loading, setLoading] = useState(true);
  const [selectedThumun, setSelectedThumun] = useState<{ hizb: number; thumun: number } | null>(null);

  useEffect(() => {
    setLoading(true);
    fetchMushafProgress(student.id).finally(() => {
      setLoading(false);
    });
  }, [student.id, fetchMushafProgress]);

  const progressMap = useMemo(() => {
    const map = new Map<string, MushafProgress>();
    mushafProgress
      .filter(p => p.studentId === student.id)
      .forEach(p => {
        map.set(`${p.hizbNumber}_${p.thumunNumber}`, p);
      });
    return map;
  }, [mushafProgress, student.id]);

  const getThumunProgress = (hizb: number, thumun: number) => {
    return progressMap.get(`${hizb}_${thumun}`);
  };

  const getCellColor = (p: MushafProgress | undefined) => {
    if (!p) return "bg-gray-150 dark:bg-gray-800 border-gray-200 dark:border-gray-750 hover:bg-gray-250 dark:hover:bg-gray-700";
    if (p.isPreMemorized) return "bg-sky-100 dark:bg-sky-950/40 border-sky-300 dark:border-sky-800 text-sky-800 dark:text-sky-400 hover:bg-sky-200 dark:hover:bg-sky-900/40";
    if (!p.lastGradedDate) return "bg-gray-150 dark:bg-gray-800 border-gray-200 dark:border-gray-750 hover:bg-gray-250 dark:hover:bg-gray-700";

    const days = Math.floor((new Date().getTime() - new Date(p.lastGradedDate).getTime()) / (1000 * 60 * 60 * 24));
    if (days < 14) {
      return "bg-emerald-500 border-emerald-600 hover:bg-emerald-600 text-white";
    } else if (days <= 30) {
      return "bg-amber-500 border-amber-600 hover:bg-amber-600 text-white";
    } else {
      return "bg-rose-500 border-rose-600 hover:bg-rose-600 text-white";
    }
  };

  const thumunRangeDetails = useMemo(() => {
    if (!selectedThumun) return null;
    const { hizb, thumun } = selectedThumun;
    const quarterInHizb = Math.floor((thumun - 1) / 2) + 1;
    const surahs = quranService.getSurahs();
    const matchingAyahs: any[] = [];
    
    for (const surah of surahs) {
      for (const ayah of surah.ayahs) {
        if (ayah.hizb === hizb && ayah.quarter != null && ((ayah.quarter - 1) % 4) + 1 === quarterInHizb) {
          matchingAyahs.push({
            ...ayah,
            surahNumber: surah.number,
            surahName: surah.name
          });
        }
      }
    }

    if (matchingAyahs.length === 0) return { text: "غير محدد", surahName: "", fromAyah: 0, toAyah: 0 };

    const first = matchingAyahs[0];
    const last = matchingAyahs[matchingAyahs.length - 1];

    return {
      text: first.surahNumber === last.surahNumber
        ? `سورة ${first.surahName} (الآيات ${first.number} - ${last.number})`
        : `من سورة ${first.surahName} (${first.number}) إلى سورة ${last.surahName} (${last.number})`,
      surahName: first.surahName,
      fromAyah: first.number,
      toAyah: last.number,
    };
  }, [selectedThumun]);

  const stats = useMemo(() => {
    let memorized = 0;
    let fresh = 0;
    let aging = 0;
    let stale = 0;
    let preMemorized = 0;

    for (let h = 1; h <= 60; h++) {
      for (let t = 1; t <= 8; t++) {
        const p = progressMap.get(`${h}_${t}`);
        if (p) {
          if (p.isPreMemorized) {
            preMemorized++;
            memorized++;
          } else if (p.lastGradedDate) {
            memorized++;
            const days = Math.floor((new Date().getTime() - new Date(p.lastGradedDate).getTime()) / (1000 * 60 * 60 * 24));
            if (days < 14) fresh++;
            else if (days <= 30) aging++;
            else stale++;
          }
        }
      }
    }

    const percentage = ((memorized / 480) * 100).toFixed(1);
    return { memorized, percentage, fresh, aging, stale, preMemorized };
  }, [progressMap]);

  const getGradeArabic = (grade: number) => {
    if (grade >= 4.5) return "ممتاز ⭐⭐⭐⭐⭐";
    if (grade >= 3.5) return "جيد جداً ⭐⭐⭐⭐";
    if (grade >= 2.5) return "جيد ⭐⭐⭐";
    if (grade >= 1.5) return "مقبول ⭐⭐";
    return "لم يحدد بعد";
  };

  return (
    <div className="fixed inset-0 bg-gray-900/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
      <div className="bg-white dark:bg-gray-950 rounded-[2.5rem] w-full max-w-5xl shadow-2xl border border-gray-100 dark:border-gray-850 overflow-hidden flex flex-col h-[90vh]">
        {/* Header */}
        <div className="p-8 border-b border-gray-100 dark:border-gray-850 flex items-center justify-between bg-gray-50/50 dark:bg-gray-900/30">
          <div>
            <h3 className="text-xl font-black text-gray-900 dark:text-white flex items-center gap-2">
              <span>خريطة المصحف التفاعلية 🗺️</span>
              <span className="text-sm font-bold text-teal-600 dark:text-teal-400 bg-teal-50 dark:bg-teal-950/40 px-3 py-1 rounded-full">
                {student.name}
              </span>
            </h3>
            <p className="text-xs text-gray-500 dark:text-gray-400 mt-1">
              رسم تخطيطي تفاعلي لـ 60 حزباً (480 ثُمناً) مع تتبع جودة الحفظ ومستوى النسيان.
            </p>
          </div>
          <div className="flex items-center gap-2">
            <button 
              onClick={() => fetchMushafProgress(student.id)}
              className="p-3 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-all text-gray-400 hover:text-gray-600"
              title="تحديث البيانات"
            >
              <RefreshCw className="w-5 h-5" />
            </button>
            <button 
              onClick={onClose} 
              className="p-3 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-all text-gray-400 hover:text-gray-600"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        {/* Stats & Legend */}
        <div className="p-8 border-b border-gray-100 dark:border-gray-850 bg-white dark:bg-gray-950 grid grid-cols-1 md:grid-cols-5 gap-6">
          {/* Progress Card */}
          <div className="bg-gradient-to-br from-teal-600 to-teal-400 rounded-3xl p-5 text-white flex flex-col justify-between shadow-lg md:col-span-2">
            <div>
              <p className="text-xs font-black uppercase text-teal-100">إجمالي المحفوظ</p>
              <h4 className="text-2xl font-black mt-1">{stats.memorized} من 480 ثُمن</h4>
            </div>
            <div className="mt-4 flex items-center justify-between">
              <span className="text-sm font-bold">{stats.percentage}% من المصحف</span>
              <div className="w-2/3 bg-white/20 h-2 rounded-full overflow-hidden">
                <div className="bg-white h-full" style={{ width: `${stats.percentage}%` }}></div>
              </div>
            </div>
          </div>

          {/* Color coding legend */}
          <div className="md:col-span-3 grid grid-cols-2 sm:grid-cols-3 gap-4">
            <div className="bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-100 dark:border-emerald-900/30 rounded-2xl p-3 flex flex-col justify-between">
              <span className="text-[10px] font-black text-emerald-800 dark:text-emerald-400">ممتاز (حديث)</span>
              <span className="text-base font-black text-emerald-700 dark:text-emerald-300 mt-1">{stats.fresh} ثمن <span className="text-[10px] text-emerald-600 font-medium">(أقل من 14 يوم)</span></span>
            </div>
            <div className="bg-amber-50 dark:bg-amber-950/20 border border-amber-100 dark:border-amber-900/30 rounded-2xl p-3 flex flex-col justify-between">
              <span className="text-[10px] font-black text-amber-800 dark:text-amber-400">متوسط (آمن)</span>
              <span className="text-base font-black text-amber-700 dark:text-amber-300 mt-1">{stats.aging} ثمن <span className="text-[10px] text-amber-600 font-medium">(14 - 30 يوم)</span></span>
            </div>
            <div className="bg-rose-50 dark:bg-rose-950/20 border border-rose-100 dark:border-rose-900/30 rounded-2xl p-3 flex flex-col justify-between">
              <span className="text-[10px] font-black text-rose-800 dark:text-rose-400">يحتاج مراجعة (ضعيف)</span>
              <span className="text-base font-black text-rose-700 dark:text-rose-300 mt-1">{stats.stale} ثمن <span className="text-[10px] text-rose-600 font-medium">(أكثر من 30 يوم)</span></span>
            </div>
            <div className="bg-sky-50 dark:bg-sky-950/20 border border-sky-100 dark:border-sky-900/30 rounded-2xl p-3 flex flex-col justify-between col-span-2 sm:col-span-1">
              <span className="text-[10px] font-black text-sky-800 dark:text-sky-400">محفوظ مسبقاً</span>
              <span className="text-base font-black text-sky-700 dark:text-sky-300 mt-1">{stats.preMemorized} ثمن <span className="text-[10px] text-sky-600 font-medium">(دون تقييم)</span></span>
            </div>
          </div>
        </div>

        {/* Visualizer Grid */}
        <div className="flex-1 overflow-y-auto p-8 bg-gray-50/30 dark:bg-gray-900/10">
          {loading ? (
            <div className="h-full flex flex-col items-center justify-center gap-4">
              <RefreshCw className="w-8 h-8 animate-spin text-teal-600" />
              <span className="text-xs font-bold text-gray-500">جاري تحميل خريطة الحفظ...</span>
            </div>
          ) : (
            <div className="space-y-4">
              {Array.from({ length: 60 }, (_, i) => {
                const hizb = i + 1;
                return (
                  <div 
                    key={hizb} 
                    className="flex flex-col sm:flex-row sm:items-center bg-white dark:bg-gray-900 p-4 rounded-2xl border border-gray-100 dark:border-gray-850 gap-4"
                  >
                    <div className="w-20 font-black text-xs text-gray-700 dark:text-gray-300 shrink-0">
                      الحزب {hizb}
                    </div>
                    <div className="flex-1 grid grid-cols-8 gap-2">
                      {Array.from({ length: 8 }, (_, tIdx) => {
                        const thumun = tIdx + 1;
                        const p = getThumunProgress(hizb, thumun);
                        const cellColor = getCellColor(p);
                        return (
                          <button
                            key={thumun}
                            onClick={() => setSelectedThumun({ hizb, thumun })}
                            className={`aspect-square sm:h-10 rounded-xl transition-all border flex items-center justify-center text-[10px] font-black ${cellColor}`}
                            title={`الحزب ${hizb} - الثمن ${thumun}`}
                          >
                            {thumun}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Thumun Details Sub-modal */}
      {selectedThumun && (
        <div className="fixed inset-0 bg-gray-950/40 backdrop-blur-xs flex items-center justify-center z-[60] p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] w-full max-w-md p-8 shadow-2xl border border-gray-100 dark:border-gray-800 space-y-6">
            <div className="flex items-center justify-between border-b border-gray-50 dark:border-gray-800 pb-4">
              <h4 className="text-base font-black text-gray-900 dark:text-white">
                تفاصيل الثمن {selectedThumun.thumun} - الحزب {selectedThumun.hizb}
              </h4>
              <button 
                onClick={() => setSelectedThumun(null)}
                className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full text-gray-400 hover:text-gray-600"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {/* Position range details */}
            {thumunRangeDetails && (
              <div className="bg-teal-50/50 dark:bg-teal-950/10 border border-teal-100 dark:border-teal-900/30 rounded-2xl p-4 flex gap-3 items-start">
                <Bookmark className="w-5 h-5 text-teal-600 shrink-0 mt-0.5" />
                <div>
                  <h5 className="text-xs font-black text-teal-900 dark:text-teal-400">النطاق في المصحف</h5>
                  <p className="text-xs text-teal-700 dark:text-teal-300 font-bold mt-1 leading-relaxed">
                    {thumunRangeDetails.text}
                  </p>
                </div>
              </div>
            )}

            {/* Progress status */}
            <div className="space-y-4">
              {(() => {
                const p = getThumunProgress(selectedThumun.hizb, selectedThumun.thumun);
                const isPre = p?.isPreMemorized || false;
                
                return (
                  <>
                    {/* Graded Details */}
                    {p && (p.lastGradedDate || p.averageGrade > 0) ? (
                      <div className="bg-gray-50 dark:bg-gray-850 rounded-2xl p-4 space-y-3">
                        <div className="flex justify-between items-center text-xs">
                          <span className="font-bold text-gray-400">متوسط التقييم:</span>
                          <span className="font-black text-gray-900 dark:text-white">
                            {getGradeArabic(p.averageGrade)}
                          </span>
                        </div>
                        {p.lastGradedDate && (
                          <div className="flex justify-between items-center text-xs">
                            <span className="font-bold text-gray-400">آخر تسميع:</span>
                            <span className="font-black text-gray-900 dark:text-white flex items-center gap-1.5">
                              <Calendar className="w-3.5 h-3.5 text-gray-400" />
                              {p.lastGradedDate}
                            </span>
                          </div>
                        )}
                      </div>
                    ) : (
                      <div className="bg-gray-50 dark:bg-gray-850 rounded-2xl p-4 flex gap-3 items-center text-xs text-gray-500 font-bold">
                        <Info className="w-4 h-4" />
                        <span>لم يتم تقييم هذا الثمن رسمياً بعد.</span>
                      </div>
                    )}

                    {/* Pre-memorized Checkbox toggle */}
                    <div className="flex items-center justify-between p-4 bg-gray-50 dark:bg-gray-850 rounded-2xl">
                      <div className="space-y-0.5">
                        <span className="text-xs font-black text-gray-900 dark:text-white">حفظ مسبق</span>
                        <p className="text-[10px] text-gray-400 font-medium">تحديد كـ "محفوظ مسبقاً" دون خوض جلسة تسميع.</p>
                      </div>
                      <button
                        type="button"
                        onClick={() => {
                          togglePreMemorized(student.id, selectedThumun.hizb, selectedThumun.thumun, !isPre);
                        }}
                        className={`w-12 h-6 rounded-full transition-colors relative outline-none flex items-center ${
                          isPre ? "bg-teal-600" : "bg-gray-200 dark:bg-gray-700"
                        }`}
                      >
                        <span 
                          className={`w-5 h-5 bg-white rounded-full transition-transform shadow-md absolute ${
                            isPre ? "translate-x-6 mr-1" : "translate-x-1 mr-1"
                          }`}
                        />
                      </button>
                    </div>
                  </>
                );
              })()}
            </div>
            
            <button
              onClick={() => setSelectedThumun(null)}
              className="w-full bg-teal-600 hover:bg-teal-700 text-white font-black text-xs py-4 rounded-2xl transition-colors"
            >
              موافق
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
