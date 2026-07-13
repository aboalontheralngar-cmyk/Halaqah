"use client";

import { useState, useMemo } from "react";
import {
  AlertTriangle,
  TrendingDown,
  Clock,
  MessageSquare,
  Send,
  X,
  CheckCircle,
  XCircle,
  AlertCircle,
  Smartphone,
} from "lucide-react";
import { useStore } from "@/store/useStore";

interface DisciplineAlert {
  id: string;
  studentId: string;
  type: "frequent_absence" | "late_pattern" | "low_attendance" | "behavior";
  severity: "low" | "medium" | "high";
  count: number;
  lastDate: string;
  notes: string;
}

export default function DisciplinePage() {
  const { students, attendance, points } = useStore();

  // حساب تنبيهات الانضباط
  const disciplineAlerts = useMemo(() => {
    const alerts: DisciplineAlert[] = [];
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    const thirtyDaysAgoStr = thirtyDaysAgo.toISOString().split("T")[0];

    students.forEach((student) => {
      // عد الغيابات في آخر 30 يوم
      const recentAbsences = attendance.filter(
        (a) =>
          a.studentId === student.id &&
          a.status === "absent" &&
          a.date >= thirtyDaysAgoStr
      ).length;

      if (recentAbsences >= 3) {
        alerts.push({
          id: `absence-${student.id}`,
          studentId: student.id,
          type: "frequent_absence",
          severity: recentAbsences >= 5 ? "high" : "medium",
          count: recentAbsences,
          lastDate: attendance
            .filter((a) => a.studentId === student.id && a.status === "absent")
            .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())[0]?.date ||
            new Date().toISOString().split("T")[0],
          notes: `${recentAbsences} غيابات في آخر 30 يوم`,
        });
      }

      // عد التأخيرات
      const lateDays = attendance.filter(
        (a) =>
          a.studentId === student.id &&
          a.status === "late" &&
          a.date >= thirtyDaysAgoStr
      ).length;

      if (lateDays >= 3) {
        alerts.push({
          id: `late-${student.id}`,
          studentId: student.id,
          type: "late_pattern",
          severity: lateDays >= 5 ? "high" : "low",
          count: lateDays,
          lastDate: attendance
            .filter((a) => a.studentId === student.id && a.status === "late")
            .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())[0]?.date ||
            new Date().toISOString().split("T")[0],
          notes: `${lateDays} مرات تأخير في آخر 30 يوم`,
        });
      }

      // معدل الحضور المنخفض
      const totalRecords = attendance.filter(
        (a) =>
          a.studentId === student.id &&
          a.date >= thirtyDaysAgoStr
      ).length;
      const presentOrLate = attendance.filter(
        (a) =>
          a.studentId === student.id &&
          (a.status === "present" || a.status === "late") &&
          a.date >= thirtyDaysAgoStr
      ).length;

      if (totalRecords > 0) {
        const attendanceRate = (presentOrLate / totalRecords) * 100;
        if (attendanceRate < 50) {
          alerts.push({
            id: `rate-${student.id}`,
            studentId: student.id,
            type: "low_attendance",
            severity: "high",
            count: Math.round(attendanceRate),
            lastDate: new Date().toISOString().split("T")[0],
            notes: `معدل حضور: ${Math.round(attendanceRate)}% فقط`,
          });
        }
      }

      // نقاط سلوك سلبية كثيرة
      const negativePoints = points.filter(
        (p) =>
          p.studentId === student.id &&
          p.type === "negative" &&
          p.date >= thirtyDaysAgoStr
      ).length;

      if (negativePoints >= 3) {
        alerts.push({
          id: `behavior-${student.id}`,
          studentId: student.id,
          type: "behavior",
          severity: negativePoints >= 5 ? "high" : "medium",
          count: negativePoints,
          lastDate: points
            .filter((p) => p.studentId === student.id && p.type === "negative")
            .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime())[0]?.date ||
            new Date().toISOString().split("T")[0],
          notes: `${negativePoints} نقاط سلوك سلبية`,
        });
      }
    });

    return alerts.sort((a, b) => {
      const severityOrder = { high: 0, medium: 1, low: 2 };
      return severityOrder[a.severity] - severityOrder[b.severity];
    });
  }, [students, attendance, points]);

  const [filterType, setFilterType] = useState<"all" | DisciplineAlert["type"]>("all");
  const [selectedAlert, setSelectedAlert] = useState<DisciplineAlert | null>(null);
  const [followupMessage, setFollowupMessage] = useState("");
  const [showFollowupForm, setShowFollowupForm] = useState(false);

  const filteredAlerts = useMemo(() => {
    return filterType === "all"
      ? disciplineAlerts
      : disciplineAlerts.filter((a) => a.type === filterType);
  }, [disciplineAlerts, filterType]);

  const stats = useMemo(() => {
    return {
      totalAlerts: disciplineAlerts.length,
      highSeverity: disciplineAlerts.filter((a) => a.severity === "high").length,
      mediumSeverity: disciplineAlerts.filter((a) => a.severity === "medium")
        .length,
      lowSeverity: disciplineAlerts.filter((a) => a.severity === "low").length,
    };
  }, [disciplineAlerts]);

  const getAlertIcon = (type: DisciplineAlert["type"]) => {
    switch (type) {
      case "frequent_absence":
        return <XCircle className="w-5 h-5" />;
      case "late_pattern":
        return <Clock className="w-5 h-5" />;
      case "low_attendance":
        return <TrendingDown className="w-5 h-5" />;
      case "behavior":
        return <AlertCircle className="w-5 h-5" />;
    }
  };

  const getAlertLabel = (type: DisciplineAlert["type"]) => {
    switch (type) {
      case "frequent_absence":
        return "غيابات متكررة";
      case "late_pattern":
        return "نمط تأخير";
      case "low_attendance":
        return "معدل حضور منخفض";
      case "behavior":
        return "سلوك سلبي";
    }
  };

  const getAlertColor = (severity: DisciplineAlert["severity"]) => {
    switch (severity) {
      case "high":
        return "bg-red-50 border-red-200 text-red-900";
      case "medium":
        return "bg-orange-50 border-orange-200 text-orange-900";
      case "low":
        return "bg-yellow-50 border-yellow-200 text-yellow-900";
    }
  };

  const getSeverityLabel = (severity: DisciplineAlert["severity"]) => {
    switch (severity) {
      case "high":
        return "خطير";
      case "medium":
        return "متوسط";
      case "low":
        return "منخفض";
    }
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight flex items-center gap-4">
            <AlertTriangle className="w-8 h-8" />
            متابعة الانضباط والتنبيهات
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">
            تتبع الغيابات المتكررة والتأخير والسلوك السلبي مع إمكانية التواصل مع أولياء الأمور
          </p>
        </div>
      </div>

      {/* Stats Cards */}
      <div className="grid md:grid-cols-4 gap-4">
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">إجمالي التنبيهات</p>
          <p className="text-3xl font-black text-teal-600">{stats.totalAlerts}</p>
        </div>
        <div className="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-red-600 uppercase mb-3">خطير</p>
          <p className="text-3xl font-black text-red-600">{stats.highSeverity}</p>
        </div>
        <div className="bg-orange-50 dark:bg-orange-900/20 border border-orange-200 dark:border-orange-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-orange-600 uppercase mb-3">متوسط</p>
          <p className="text-3xl font-black text-orange-600">
            {stats.mediumSeverity}
          </p>
        </div>
        <div className="bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-yellow-600 uppercase mb-3">منخفض</p>
          <p className="text-3xl font-black text-yellow-600">{stats.lowSeverity}</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex items-center gap-4 overflow-x-auto pb-2">
        {(["all", "frequent_absence", "late_pattern", "low_attendance", "behavior"] as const).map(
          (type) => (
            <button
              key={type}
              onClick={() => setFilterType(type)}
              className={`px-6 py-2 rounded-full font-bold text-sm transition-all whitespace-nowrap ${
                filterType === type
                  ? "bg-gray-900 text-white dark:bg-white dark:text-gray-900"
                  : "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              }`}
            >
              {type === "all"
                ? "الكل"
                : getAlertLabel(type as DisciplineAlert["type"])}
            </button>
          )
        )}
      </div>

      {/* Alerts List */}
      <div className="space-y-4">
        {filteredAlerts.length === 0 ? (
          <div className="text-center py-12 bg-green-50 dark:bg-green-900/20 rounded-2xl border-2 border-dashed border-green-300 dark:border-green-800">
            <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
            <p className="text-green-700 dark:text-green-300 font-bold text-lg">
              ممتاز! لا توجد تنبيهات
            </p>
            <p className="text-sm text-green-600 dark:text-green-400 mt-2">
              جميع الطلاب في حالة انضباط ممتازة
            </p>
          </div>
        ) : (
          filteredAlerts.map((alert) => {
            const student = students.find((s) => s.id === alert.studentId);
            if (!student) return null;

            return (
              <div
                key={alert.id}
                className={`border-2 rounded-2xl p-6 transition-all hover:shadow-lg ${getAlertColor(
                  alert.severity
                )}`}
              >
                <div className="flex items-start justify-between gap-4 mb-4">
                  <div className="flex items-start gap-4 flex-1">
                    <div className="w-12 h-12 rounded-xl bg-white/50 flex items-center justify-center text-lg font-black">
                      {student.name[0]}
                    </div>
                    <div className="flex-1">
                      <div className="flex items-center gap-3">
                        <h3 className="font-black text-lg">{student.name}</h3>
                        <div className="flex items-center gap-2 px-3 py-1 bg-white/60 rounded-lg">
                          {getAlertIcon(alert.type)}
                          <span className="text-xs font-bold">
                            {getAlertLabel(alert.type)}
                          </span>
                        </div>
                      </div>
                      <p className="text-sm font-bold opacity-75 mt-1">
                        {alert.notes}
                      </p>
                      <p className="text-xs opacity-60 mt-1">آخر تسجيل: {alert.lastDate}</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <div className="inline-block px-4 py-2 bg-white/60 rounded-lg font-bold text-lg">
                      {alert.count}
                    </div>
                    <p className="text-xs font-bold mt-1 opacity-60">
                      {getSeverityLabel(alert.severity)}
                    </p>
                  </div>
                </div>

                <div className="flex gap-3">
                  <button
                    onClick={() => {
                      setSelectedAlert(alert);
                      setShowFollowupForm(true);
                    }}
                    className="flex-1 px-4 py-2 bg-white/60 hover:bg-white rounded-lg font-bold text-sm transition-all flex items-center justify-center gap-2"
                  >
                    <MessageSquare className="w-4 h-4" />
                    تواصل مع ولي الأمر
                  </button>
                  {alert.severity === "high" && (
                    <button className="px-4 py-2 bg-white/60 hover:bg-red-100 rounded-lg font-bold text-sm text-red-600 transition-all">
                      إجراء فوري
                    </button>
                  )}
                </div>
              </div>
            );
          })
        )}
      </div>

      {/* Follow-up Modal */}
      {showFollowupForm && selectedAlert && (
        <div className="fixed inset-0 bg-black/50 flex items-end md:items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-3xl p-8 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-black">تواصل مع ولي الأمر</h2>
              <button
                onClick={() => setShowFollowupForm(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            {(() => {
              const student = students.find(
                (s) => s.id === selectedAlert.studentId
              );
              return (
                <>
                  <div className="mb-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-xl">
                    <p className="text-sm font-bold text-gray-500 mb-2">الطالب</p>
                    <p className="font-black text-lg">{student?.name}</p>
                    <p className="text-sm text-gray-500 mt-2">{selectedAlert.notes}</p>
                  </div>

                  <div className="mb-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-xl">
                    <p className="text-sm font-bold text-gray-500 mb-2">بيانات ولي الأمر</p>
                    <div className="space-y-2">
                      <div className="flex items-center gap-3">
                        <Smartphone className="w-4 h-4 text-teal-600" />
                        <p className="font-bold">{student?.parentPhone}</p>
                      </div>
                    </div>
                  </div>

                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      // TODO: Send WhatsApp or SMS message
                      setShowFollowupForm(false);
                      setFollowupMessage("");
                    }}
                    className="space-y-6"
                  >
                    <div>
                      <label className="block text-sm font-bold mb-3">
                        الرسالة
                      </label>
                      <textarea
                        value={followupMessage}
                        onChange={(e) => setFollowupMessage(e.target.value)}
                        className="w-full px-4 py-3 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium resize-none"
                        rows={5}
                        placeholder={`السلام عليكم ورحمة الله وبركاته،\n\nبخصوص ${student?.name} في الحلقة...\n\nنتمنى التعاون معكم لتحسين الحضور والالتزام.`}
                        required
                      />
                    </div>

                    <div className="flex gap-3">
                      <button
                        type="submit"
                        className="flex-1 bg-teal-600 text-white font-bold py-3 rounded-xl hover:bg-teal-700 transition-all flex items-center justify-center gap-2"
                      >
                        <Send className="w-4 h-4" />
                        إرسال عبر واتساب
                      </button>
                      <button
                        type="button"
                        onClick={() => setShowFollowupForm(false)}
                        className="px-6 bg-gray-100 dark:bg-gray-800 font-bold rounded-xl hover:bg-gray-200 transition-all"
                      >
                        إلغاء
                      </button>
                    </div>
                  </form>
                </>
              );
            })()}
          </div>
        </div>
      )}
    </div>
  );
}
