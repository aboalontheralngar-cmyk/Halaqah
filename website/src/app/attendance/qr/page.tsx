"use client";

import { logOperationalError } from "@/lib/operationalLog";
import { useCallback, useEffect, useRef, useState } from "react";
import { useShallow } from "zustand/react/shallow";
import { useRouter } from "next/navigation";
import { Html5QrcodeScanner } from "html5-qrcode";
import {
  Camera,
  CheckCircle, 
  UserCheck, 
  ArrowRight,
  AlertCircle,
  BookOpen,
  ClipboardCheck,
  RotateCcw,
} from "lucide-react";
import { useStore, type Student } from "@/store/useStore";
import { decodeStudentQr } from "@/lib/studentQr";

function localDateKey(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

export default function QRScannerPage() {
  const router = useRouter();
  const {
    fetchStudents,
    fetchAttendance
  } = useStore(
    useShallow((state) => ({
      fetchStudents: state.fetchStudents,
      fetchAttendance: state.fetchAttendance,
    })),
  );
  const [lastScanned, setLastScanned] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "success" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");
  const [scannedStudent, setScannedStudent] = useState<Student | null>(null);
  const scannerRef = useRef<Html5QrcodeScanner | null>(null);
  const processingRef = useRef(false);
  const resetTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const scheduleReset = useCallback(() => {
    if (resetTimerRef.current) clearTimeout(resetTimerRef.current);
    resetTimerRef.current = setTimeout(() => {
      processingRef.current = false;
      setStatus("idle");
      setScannedStudent(null);
    }, 3000);
  }, []);

  const resetScanner = useCallback(() => {
    if (resetTimerRef.current) clearTimeout(resetTimerRef.current);
    processingRef.current = false;
    setStatus("idle");
    setLastScanned(null);
    setScannedStudent(null);
    setErrorMsg("");
  }, []);

  const openMemorization = (mode: "session" | "direct") => {
    if (!scannedStudent) return;
    localStorage.setItem("memorization_prefill_student_id", scannedStudent.id);
    localStorage.setItem("memorization_entry_mode", mode);
    router.push("/memorization");
  };

  const onScanSuccess = useCallback(async (decodedText: string) => {
    if (processingRef.current) return;
    processingRef.current = true;

    const decoded = decodeStudentQr(decodedText);
    if (!decoded) {
      setStatus("error");
      setErrorMsg("الكود غير تابع لنظام حلقتي أو أن تنسيقه غير صالح.");
      scheduleReset();
      return;
    }

    const state = useStore.getState();
    const student = state.students.find(student =>
      decoded.legacyStudentId
        ? student.id === decoded.token
        : student.qrCode === decoded.token ||
          (!student.qrCode && student.id === decoded.token)
    );

    if (!student) {
      setStatus("error");
      setErrorMsg("لم يتم العثور على الطالب داخل الحلقة الحالية.");
      scheduleReset();
      return;
    }

    const today = localDateKey(new Date());
    const existing = state.attendance.find(record =>
      record.studentId === student.id && record.date === today
    );

    if (existing?.status === "present" || existing?.status === "late") {
      setLastScanned(`${student.name} — مسجل مسبقًا`);
      setScannedStudent(student);
      setStatus("success");
      return;
    }

    await state.addAttendance({
      studentId: student.id,
      date: today,
      status: "present",
      arrivalTime: new Date().toTimeString().slice(0, 8),
    });

    setLastScanned(student.name);
    setScannedStudent(student);
    setStatus("success");
  }, [scheduleReset]);

  const onScanFailure = useCallback(() => {
    // Frame misses are normal while the camera is searching for a QR code.
  }, []);

  useEffect(() => {
    void Promise.all([fetchStudents(), fetchAttendance()]);
  }, [fetchAttendance, fetchStudents]);

  useEffect(() => {
    scannerRef.current = new Html5QrcodeScanner(
      "reader",
      { fps: 10, qrbox: { width: 250, height: 250 } },
      false
    );

    scannerRef.current.render(onScanSuccess, onScanFailure);

    return () => {
      if (scannerRef.current) {
        scannerRef.current.clear().catch(err => logOperationalError("attendance_qr.scanner_clear", err));
      }
      if (resetTimerRef.current) clearTimeout(resetTimerRef.current);
    };
  }, [onScanFailure, onScanSuccess]);

  return (
    <div className="min-h-[80vh] flex flex-col items-center justify-center space-y-8 animate-in fade-in duration-700">
      <div className="text-center space-y-2">
        <h1 className="text-3xl font-black text-[var(--foreground)]">ماسح الحضور الذكي 📸</h1>
        <p className="text-[var(--muted)] font-medium">قم بتوجيه كاميرا الجوال نحو كود الطالب لرصد الحضور فوراً.</p>
      </div>

      <div className="relative w-full max-w-md aspect-square bg-gray-900 rounded-[3rem] overflow-hidden shadow-2xl border-4 border-white dark:border-gray-800">
        <div id="reader" className="w-full h-full"></div>
        
        {/* Status Overlays */}
        {status === "success" && (
          <div className="absolute inset-0 overflow-y-auto bg-green-600/95 p-6 text-white z-50 animate-in zoom-in-95 duration-300">
            <div className="flex min-h-full flex-col items-center justify-center">
              <CheckCircle className="mb-3 h-14 w-14" />
              <h2 className="text-xl font-black">تم التعرف على الطالب وتحضيره</h2>
              <p className="mt-2 text-center text-base font-bold">{lastScanned}</p>
              <div className="mt-5 grid w-full grid-cols-1 gap-2 sm:grid-cols-2">
                <button
                  type="button"
                  onClick={() => openMemorization("direct")}
                  className="flex items-center justify-center gap-2 rounded-2xl bg-white px-4 py-3 text-xs font-black text-emerald-800"
                >
                  <ClipboardCheck className="h-4 w-4" /> تسجيل حفظ مباشر
                </button>
                <button
                  type="button"
                  onClick={() => openMemorization("session")}
                  className="flex items-center justify-center gap-2 rounded-2xl bg-emerald-900/35 px-4 py-3 text-xs font-black text-white ring-1 ring-white/40"
                >
                  <BookOpen className="h-4 w-4" /> بدء جلسة تسميع
                </button>
                <button
                  type="button"
                  onClick={resetScanner}
                  className="flex items-center justify-center gap-2 rounded-2xl bg-black/15 px-4 py-3 text-xs font-black text-white sm:col-span-2"
                >
                  <RotateCcw className="h-4 w-4" /> الاكتفاء بالحضور ومسح طالب آخر
                </button>
              </div>
            </div>
          </div>
        )}

        {status === "error" && (
          <div className="absolute inset-0 bg-rose-500/90 backdrop-blur-md flex flex-col items-center justify-center text-white z-50 animate-in zoom-in-95 duration-300">
            <AlertCircle className="w-20 h-20 mb-4" />
            <h2 className="text-xl font-black">خطأ في المسح</h2>
            <p className="text-sm font-bold mt-2 px-8 text-center">{errorMsg}</p>
          </div>
        )}
      </div>

      <div className="flex gap-4">
        <button 
          onClick={() => router.back()}
          className="px-8 py-4 bg-[var(--surface)] border border-[var(--border)] rounded-3xl font-black text-sm text-gray-600 dark:text-gray-300 flex items-center gap-2 hover:bg-gray-50 transition-all"
        >
          <ArrowRight className="w-5 h-5" /> العودة للخلف
        </button>
        <div className="px-8 py-4 bg-teal-600 text-white rounded-3xl font-black text-sm shadow-xl shadow-teal-100 dark:shadow-none flex items-center gap-2">
          <Camera className="w-5 h-5" /> الكاميرا تعمل تلقائيًا
        </div>
      </div>

      <div className="bg-amber-50 dark:bg-amber-900/20 border border-amber-100 dark:border-amber-800 p-6 rounded-[2rem] max-w-md w-full">
        <h4 className="text-xs font-black text-amber-900 dark:text-amber-400 uppercase tracking-widest mb-2 flex items-center gap-2">
          <UserCheck className="w-4 h-4" /> نصيحة تقنية
        </h4>
        <p className="text-[11px] text-amber-700 dark:text-amber-300 leading-relaxed font-medium">
          تأكد من وجود إضاءة جيدة وأن كود الطالب واضح تماماً أمام الكاميرا. يمكنك طباعة الأكواد للطلاب من صفحة إدارة الطلاب.
        </p>
      </div>
    </div>
  );
}
