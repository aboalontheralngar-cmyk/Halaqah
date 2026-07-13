"use client";

import { useState, useMemo } from "react";
import {
  Trophy,
  Calendar,
  Award,
  BookOpen,
  Heart,
  Crown,
} from "lucide-react";
import { useStore, type Student } from "@/store/useStore";

export default function HonorBoardPage() {
  const { students, attendance, memorization, points, exams } = useStore();
  const [selectedCategory, setSelectedCategory] = useState<
    "overall" | "memorization" | "attendance" | "behavior" | "exams"
  >("overall");

  const rankings = useMemo(() => {
    const getStudentData = (student: Student) => {
      const studentId = student.id;

      // حساب كل فئة
      const memStats = memorization
        .filter((m) => m.studentId === studentId)
        .slice(-30);
      const avgMemorization =
        memStats.length > 0
          ? memStats.reduce((sum, m) => sum + (m.degree || 0), 0) / memStats.length
          : 0;

      const attendanceRecords = attendance.filter(
        (a) => a.studentId === studentId
      );
      const presentDays = attendanceRecords.filter(
        (a) => a.status === "present" || a.status === "late"
      ).length;
      const attendanceRate =
        attendanceRecords.length > 0
          ? (presentDays / attendanceRecords.length) * 100
          : 0;

      const positiveBehavior = points.filter(
        (p) => p.studentId === studentId && p.type === "positive"
      ).length;
      const negativeBehavior = points.filter(
        (p) => p.studentId === studentId && p.type === "negative"
      ).length;
      const behaviorScore = Math.max(
        0,
        (positiveBehavior - negativeBehavior) * 10
      );

      const studentExams = exams.flatMap((e) =>
        e.studentScores
          .filter((s) => s.studentId === studentId)
          .map((s) => ({ ...s, maxDegree: e.maxDegree }))
      );
      const avgExamScore =
        studentExams.length > 0
          ? (studentExams.reduce((sum, e) => sum + (e.degree / e.maxDegree) * 100, 0) /
              studentExams.length)
          : 0;

      // الدرجة الإجمالية
      const overallScore =
        (avgMemorization / 100) * 25 +
        (attendanceRate / 100) * 25 +
        (behaviorScore / 100) * 25 +
        (avgExamScore / 100) * 25;

      return {
        studentId,
        name: student.name,
        memorization: avgMemorization,
        attendance: attendanceRate,
        behavior: behaviorScore,
        exams: avgExamScore,
        overall: overallScore,
      };
    };

    const data = students.map(getStudentData);

    // ترتيب حسب الفئة المختارة
    const sorted = [...data].sort((a, b) => {
      const scoreA = a[selectedCategory];
      const scoreB = b[selectedCategory];
      return scoreB - scoreA;
    });

    return sorted.slice(0, 20).map((s, index) => ({
      rank: index + 1,
      ...s,
    }));
  }, [students, attendance, memorization, points, exams, selectedCategory]);

  const getCategoryLabel = (category: typeof selectedCategory) => {
    const labels: Record<typeof selectedCategory, string> = {
      overall: "الترتيب العام",
      memorization: "الحفظ والمراجعة",
      attendance: "الحضور والالتزام",
      behavior: "السلوك والتربية",
      exams: "الاختبارات والامتحانات",
    };
    return labels[category];
  };

  const getCategoryIcon = (category: typeof selectedCategory) => {
    switch (category) {
      case "overall":
        return <Crown className="w-5 h-5" />;
      case "memorization":
        return <BookOpen className="w-5 h-5" />;
      case "attendance":
        return <Calendar className="w-5 h-5" />;
      case "behavior":
        return <Heart className="w-5 h-5" />;
      case "exams":
        return <Award className="w-5 h-5" />;
    }
  };

  const getRankBadge = (rank: number) => {
    switch (rank) {
      case 1:
        return "🥇";
      case 2:
        return "🥈";
      case 3:
        return "🥉";
      default:
        return `#${rank}`;
    }
  };

  const getScoreColor = (score: number) => {
    if (score >= 85) return "text-green-600 dark:text-green-400";
    if (score >= 70) return "text-blue-600 dark:text-blue-400";
    if (score >= 50) return "text-yellow-600 dark:text-yellow-400";
    return "text-red-600 dark:text-red-400";
  };

  const getScoreBgColor = (score: number) => {
    if (score >= 85) return "bg-green-50 dark:bg-green-900/20";
    if (score >= 70) return "bg-blue-50 dark:bg-blue-900/20";
    if (score >= 50) return "bg-yellow-50 dark:bg-yellow-900/20";
    return "bg-red-50 dark:bg-red-900/20";
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight flex items-center gap-4">
            <Trophy className="w-8 h-8" />
            لوحة الشرف
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">
            احتفاء بأفضل الطلاب المتفوقين في مختلف الفئات
          </p>
        </div>
      </div>

      {/* Category Tabs */}
      <div className="flex flex-wrap items-center gap-3">
        {(["overall", "memorization", "attendance", "behavior", "exams"] as const).map(
          (cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`px-6 py-3 rounded-full font-bold text-sm transition-all flex items-center gap-2 whitespace-nowrap ${
                selectedCategory === cat
                  ? "bg-gradient-to-r from-teal-600 to-teal-500 text-white shadow-lg"
                  : "bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 text-gray-700 dark:text-gray-300 hover:border-teal-300"
              }`}
            >
              {getCategoryIcon(cat)}
              {getCategoryLabel(cat)}
            </button>
          )
        )}
      </div>

      {/* Top 3 Highlights */}
      <div className="grid md:grid-cols-3 gap-6">
        {rankings.slice(0, 3).map((student, index) => {
          const score =
            selectedCategory === "overall"
              ? student.overall
              : student[selectedCategory as keyof typeof student];

          return (
            <div
              key={student.studentId}
              className={`rounded-3xl p-8 border-2 transition-all hover:shadow-xl ${
                index === 0
                  ? "col-span-full md:col-span-1 bg-gradient-to-br from-yellow-50 to-amber-50 dark:from-yellow-900/20 dark:to-amber-900/20 border-yellow-300 dark:border-yellow-700 md:scale-105 md:row-span-2"
                  : index === 1
                  ? "bg-gradient-to-br from-gray-100 to-gray-50 dark:from-gray-800 dark:to-gray-900 border-gray-300 dark:border-gray-700"
                  : "bg-gradient-to-br from-orange-50 to-red-50 dark:from-orange-900/20 dark:to-red-900/20 border-orange-300 dark:border-orange-700"
              }`}
            >
              <div className="text-center">
                <div className="text-6xl mb-4">{getRankBadge(student.rank)}</div>
                <div className="w-20 h-20 rounded-full bg-white dark:bg-gray-800 flex items-center justify-center text-2xl font-black mx-auto mb-4 shadow-lg">
                  {student.name[0]}
                </div>
                <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-6">
                  {student.name}
                </h3>
                <div
                  className={`inline-block px-6 py-3 rounded-2xl font-black text-3xl ${getScoreBgColor(
                    typeof score === "number" ? score : 0
                  )} ${getScoreColor(typeof score === "number" ? score : 0)}`}
                >
                  {typeof score === "number" ? Math.round(score) : 0}%
                </div>
              </div>
            </div>
          );
        })}
      </div>

      {/* Full Rankings Table */}
      <div className="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-800 overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-right">
            <thead>
              <tr className="bg-gray-50 dark:bg-gray-800/50 border-b border-gray-200 dark:border-gray-800">
                <th className="px-6 py-4 text-sm font-black text-gray-500 uppercase">الترتيب</th>
                <th className="px-6 py-4 text-sm font-black text-gray-500 uppercase">الطالب</th>
                <th className="px-6 py-4 text-sm font-black text-gray-500 uppercase text-center">
                  الحفظ
                </th>
                <th className="px-6 py-4 text-sm font-black text-gray-500 uppercase text-center">
                  الحضور
                </th>
                <th className="px-6 py-4 text-sm font-black text-gray-500 uppercase text-center">
                  السلوك
                </th>
                <th className="px-6 py-4 text-sm font-black text-gray-500 uppercase text-center">
                  الامتحانات
                </th>
                <th className="px-6 py-4 text-sm font-black text-gray-500 uppercase text-center">
                  {getCategoryLabel(selectedCategory)}
                </th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-100 dark:divide-gray-800">
              {rankings.map((student) => {
                const score =
                  selectedCategory === "overall"
                    ? student.overall
                    : student[selectedCategory as keyof typeof student];
                const scoreNum = typeof score === "number" ? score : 0;

                return (
                  <tr
                    key={student.studentId}
                    className="hover:bg-teal-50/50 dark:hover:bg-teal-900/10 transition-colors group"
                  >
                    <td className="px-6 py-4 font-black text-lg text-teal-600 dark:text-teal-400">
                      {getRankBadge(student.rank)}
                    </td>
                    <td className="px-6 py-4">
                      <div className="flex items-center gap-3">
                        <div className="w-10 h-10 rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center font-bold text-gray-600 dark:text-gray-400 group-hover:bg-teal-600 group-hover:text-white transition-all">
                          {student.name[0]}
                        </div>
                        <span className="font-bold text-gray-900 dark:text-white">
                          {student.name}
                        </span>
                      </div>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="inline-block px-3 py-1 rounded-lg bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 font-bold text-sm">
                        {Math.round(student.memorization)}%
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="inline-block px-3 py-1 rounded-lg bg-green-50 dark:bg-green-900/20 text-green-600 dark:text-green-400 font-bold text-sm">
                        {Math.round(student.attendance)}%
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="inline-block px-3 py-1 rounded-lg bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400 font-bold text-sm">
                        {Math.round(student.behavior)}%
                      </span>
                    </td>
                    <td className="px-6 py-4 text-center">
                      <span className="inline-block px-3 py-1 rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-600 dark:text-amber-400 font-bold text-sm">
                        {Math.round(student.exams)}%
                      </span>
                    </td>
                    <td className={`px-6 py-4 text-center`}>
                      <div className={`inline-block px-4 py-2 rounded-xl font-black text-lg ${getScoreBgColor(scoreNum)} ${getScoreColor(scoreNum)}`}>
                        {Math.round(scoreNum)}%
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Achievement Stats */}
      <div className="grid md:grid-cols-4 gap-4">
        <div className="bg-gradient-to-br from-blue-50 to-blue-100 dark:from-blue-900/20 dark:to-blue-900/10 border border-blue-200 dark:border-blue-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-blue-600 uppercase mb-3">ممتازون (85%+)</p>
          <p className="text-3xl font-black text-blue-600">
            {rankings.filter((s) => {
              const score =
                selectedCategory === "overall"
                  ? s.overall
                  : s[selectedCategory as keyof typeof s];
              return (typeof score === "number" ? score : 0) >= 85;
            }).length}
          </p>
        </div>
        <div className="bg-gradient-to-br from-green-50 to-green-100 dark:from-green-900/20 dark:to-green-900/10 border border-green-200 dark:border-green-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-green-600 uppercase mb-3">جيدون (70-84%)</p>
          <p className="text-3xl font-black text-green-600">
            {rankings.filter((s) => {
              const score =
                selectedCategory === "overall"
                  ? s.overall
                  : s[selectedCategory as keyof typeof s];
              const scoreNum = typeof score === "number" ? score : 0;
              return scoreNum >= 70 && scoreNum < 85;
            }).length}
          </p>
        </div>
        <div className="bg-gradient-to-br from-yellow-50 to-yellow-100 dark:from-yellow-900/20 dark:to-yellow-900/10 border border-yellow-200 dark:border-yellow-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-yellow-600 uppercase mb-3">مقبولون (50-69%)</p>
          <p className="text-3xl font-black text-yellow-600">
            {rankings.filter((s) => {
              const score =
                selectedCategory === "overall"
                  ? s.overall
                  : s[selectedCategory as keyof typeof s];
              const scoreNum = typeof score === "number" ? score : 0;
              return scoreNum >= 50 && scoreNum < 70;
            }).length}
          </p>
        </div>
        <div className="bg-gradient-to-br from-red-50 to-red-100 dark:from-red-900/20 dark:to-red-900/10 border border-red-200 dark:border-red-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-red-600 uppercase mb-3">متابعة (أقل من 50%)</p>
          <p className="text-3xl font-black text-red-600">
            {rankings.filter((s) => {
              const score =
                selectedCategory === "overall"
                  ? s.overall
                  : s[selectedCategory as keyof typeof s];
              return (typeof score === "number" ? score : 0) < 50;
            }).length}
          </p>
        </div>
      </div>
    </div>
  );
}
