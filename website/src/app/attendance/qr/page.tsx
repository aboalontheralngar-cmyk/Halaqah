"use client";

import { useEffect, useState, useRef } from "react";
import { useRouter } from "next/navigation";
import { Html5QrcodeScanner } from "html5-qrcode";
import { 
  X, 
  Camera, 
  CheckCircle, 
  UserCheck, 
  ArrowRight,
  AlertCircle
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function QRScannerPage() {
  const router = useRouter();
  const { students, addAttendance, attendance } = useStore();
  const [lastScanned, setLastScanned] = useState<string | null>(null);
  const [status, setStatus] = useState<"idle" | "success" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");
  const scannerRef = useRef<Html5QrcodeScanner | null>(null);

  useEffect(() => {
    scannerRef.current = new Html5QrcodeScanner(
      "reader",
      { fps: 10, qrbox: { width: 250, height: 250 } },
      false
    );

    scannerRef.current.render(onScanSuccess, onScanFailure);

    return () => {
      if (scannerRef.current) {
        scannerRef.current.clear().catch(err => console.error("Failed to clear scanner", err));
      }
    };
  }, []);

  async function onScanSuccess(decodedText: string) {
    if (status === "success" && lastScanned === decodedText) return;

    const student = students.find(s => s.id === decodedText || s.phone === decodedText);
    
    if (student) {
      setLastScanned(student.name);
      setStatus("success");
      
      // Mark as present
      const today = new Date().toISOString().split("T")[0];
      await addAttendance({
        studentId: student.id,
        date: today,
        status: "present"
      });

      // Reset after 3 seconds to allow next scan
      setTimeout(() => {
        setStatus("idle");
      }, 3000);
    } else {
      setStatus("error");
      setErrorMsg("عذراً، لم يتم العثور على هذا الطالب في النظام.");
      setTimeout(() => setStatus("idle"), 3000);
    }
  }

  function onScanFailure(error: any) {
    // Silent fail is fine for normal scanning flow
  }

  return (
    <div className="min-h-[80vh] flex flex-col items-center justify-center space-y-8 animate-in fade-in duration-700">
      <div className="text-center space-y-2">
        <h1 className="text-3xl font-black text-gray-900 dark:text-white">ماسح الحضور الذكي 📸</h1>
        <p className="text-gray-500 dark:text-gray-400 font-medium">قم بتوجيه كاميرا الجوال نحو كود الطالب لرصد الحضور فوراً.</p>
      </div>

      <div className="relative w-full max-w-md aspect-square bg-gray-900 rounded-[3rem] overflow-hidden shadow-2xl border-4 border-white dark:border-gray-800">
        <div id="reader" className="w-full h-full"></div>
        
        {/* Status Overlays */}
        {status === "success" && (
          <div className="absolute inset-0 bg-green-500/90 backdrop-blur-md flex flex-col items-center justify-center text-white z-50 animate-in zoom-in-95 duration-300">
            <CheckCircle className="w-20 h-20 mb-4 animate-bounce" />
            <h2 className="text-2xl font-black">تم تسجيل الحضور!</h2>
            <p className="text-lg font-bold mt-2">{lastScanned}</p>
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
          className="px-8 py-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-3xl font-black text-sm text-gray-600 dark:text-gray-300 flex items-center gap-2 hover:bg-gray-50 transition-all"
        >
          <ArrowRight className="w-5 h-5" /> العودة للخلف
        </button>
        <button className="px-8 py-4 bg-teal-600 text-white rounded-3xl font-black text-sm shadow-xl shadow-teal-100 dark:shadow-none flex items-center gap-2">
          <Camera className="w-5 h-5" /> تشغيل الكاميرا
        </button>
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
