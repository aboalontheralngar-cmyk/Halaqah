"use client";

import { useState, useMemo } from "react";
import {
  Plus,
  DollarSign,
  TrendingUp,
  Wallet,
  Receipt,
  Download,
  X,
  Calendar,
  User,
  Filter,
  ChevronDown,
} from "lucide-react";
import { useStore } from "@/store/useStore";

interface FundTransaction {
  id: string;
  type: "subscription" | "donation" | "penalty" | "expense";
  studentId?: string;
  amount: number;
  reason: string;
  date: string;
  notes?: string;
}

export default function FundPage() {
  const { students } = useStore();
  
  // محاكاة بيانات الصندوق
  const [transactions, setTransactions] = useState<FundTransaction[]>([
    { id: "1", type: "subscription", studentId: "1", amount: 500, reason: "اشتراك شهري", date: "2024-06-10", notes: "" },
    { id: "2", type: "subscription", studentId: "2", amount: 500, reason: "اشتراك شهري", date: "2024-06-10", notes: "" },
    { id: "3", type: "donation", amount: 1000, reason: "تبرع من محسن", date: "2024-06-08", notes: "بسم الله" },
    { id: "4", type: "expense", amount: -200, reason: "شراء مصاحف", date: "2024-06-05", notes: "" },
    { id: "5", type: "penalty", studentId: "1", amount: 50, reason: "عقوبة تحويل إلى الصندوق", date: "2024-06-01", notes: "" },
  ]);

  const [showForm, setShowForm] = useState(false);
  const [filterType, setFilterType] = useState<"all" | "subscription" | "donation" | "penalty" | "expense">("all");
  
  const [formData, setFormData] = useState({
    type: "subscription" as FundTransaction["type"],
    studentId: "",
    amount: 500,
    reason: "",
    notes: "",
  });

  const filteredTransactions = useMemo(() => {
    return filterType === "all" 
      ? transactions 
      : transactions.filter(t => t.type === filterType);
  }, [transactions, filterType]);

  const balance = useMemo(() => {
    return transactions.reduce((sum, t) => sum + t.amount, 0);
  }, [transactions]);

  const stats = useMemo(() => {
    return {
      totalSubscriptions: transactions
        .filter(t => t.type === "subscription")
        .reduce((sum, t) => sum + t.amount, 0),
      totalDonations: transactions
        .filter(t => t.type === "donation")
        .reduce((sum, t) => sum + t.amount, 0),
      totalPenalties: transactions
        .filter(t => t.type === "penalty")
        .reduce((sum, t) => sum + t.amount, 0),
      totalExpenses: Math.abs(
        transactions
          .filter(t => t.type === "expense")
          .reduce((sum, t) => sum + t.amount, 0)
      ),
    };
  }, [transactions]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    const newTransaction: FundTransaction = {
      id: Date.now().toString(),
      type: formData.type,
      studentId: formData.studentId || undefined,
      amount: formData.type === "expense" ? -formData.amount : formData.amount,
      reason: formData.reason,
      date: new Date().toISOString().split("T")[0],
      notes: formData.notes,
    };
    setTransactions([newTransaction, ...transactions]);
    setShowForm(false);
    setFormData({
      type: "subscription",
      studentId: "",
      amount: 500,
      reason: "",
      notes: "",
    });
  };

  const getTransactionColor = (type: FundTransaction["type"]) => {
    switch (type) {
      case "subscription":
        return "bg-blue-50 border-blue-200 text-blue-900";
      case "donation":
        return "bg-green-50 border-green-200 text-green-900";
      case "penalty":
        return "bg-orange-50 border-orange-200 text-orange-900";
      case "expense":
        return "bg-red-50 border-red-200 text-red-900";
    }
  };

  const getTransactionLabel = (type: FundTransaction["type"]) => {
    switch (type) {
      case "subscription":
        return "اشتراك";
      case "donation":
        return "تبرع";
      case "penalty":
        return "عقوبة";
      case "expense":
        return "مصروف";
    }
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight flex items-center gap-4">
            <Wallet className="w-8 h-8" />
            صندوق الحلقة
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">إدارة الاشتراكات والتبرعات ومصروفات الحلقة</p>
        </div>
        <button
          onClick={() => setShowForm(true)}
          className="bg-green-600 text-white px-8 py-4 rounded-3xl font-black text-sm hover:bg-green-700 shadow-xl shadow-green-100 dark:shadow-none transition-all flex items-center justify-center gap-2"
        >
          <Plus className="w-5 h-5" /> تسجيل عملية جديدة
        </button>
      </div>

      {/* Balance Card */}
      <div className="grid md:grid-cols-2 gap-6">
        <div className="bg-gradient-to-br from-green-600 to-green-700 text-white rounded-[2rem] p-8 shadow-lg">
          <div className="flex items-center justify-between mb-6">
            <p className="font-bold opacity-90">الرصيد الحالي</p>
            <DollarSign className="w-6 h-6 opacity-80" />
          </div>
          <p className="text-4xl font-black mb-2">{balance.toLocaleString()}</p>
          <p className="text-sm opacity-80">ر.س</p>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
            <p className="text-xs font-bold text-gray-500 uppercase mb-3">اشتراكات</p>
            <p className="text-2xl font-black text-blue-600">{stats.totalSubscriptions}</p>
            <p className="text-xs text-gray-400 mt-1">من {transactions.filter(t => t.type === "subscription").length} طالب</p>
          </div>
          <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
            <p className="text-xs font-bold text-gray-500 uppercase mb-3">تبرعات</p>
            <p className="text-2xl font-black text-green-600">{stats.totalDonations}</p>
            <p className="text-xs text-gray-400 mt-1">{transactions.filter(t => t.type === "donation").length} تبرع</p>
          </div>
          <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
            <p className="text-xs font-bold text-gray-500 uppercase mb-3">عقوبات محولة</p>
            <p className="text-2xl font-black text-orange-600">{stats.totalPenalties}</p>
            <p className="text-xs text-gray-400 mt-1">{transactions.filter(t => t.type === "penalty").length} عقوبة</p>
          </div>
          <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
            <p className="text-xs font-bold text-gray-500 uppercase mb-3">مصروفات</p>
            <p className="text-2xl font-black text-red-600">{stats.totalExpenses}</p>
            <p className="text-xs text-gray-400 mt-1">{transactions.filter(t => t.type === "expense").length} مصروف</p>
          </div>
        </div>
      </div>

      {/* Filter & Transactions */}
      <div className="space-y-6">
        <div className="flex items-center gap-4 overflow-x-auto pb-2">
          {(["all", "subscription", "donation", "penalty", "expense"] as const).map(type => (
            <button
              key={type}
              onClick={() => setFilterType(type)}
              className={`px-6 py-2 rounded-full font-bold text-sm transition-all whitespace-nowrap ${
                filterType === type
                  ? "bg-gray-900 text-white dark:bg-white dark:text-gray-900"
                  : "bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700"
              }`}
            >
              {type === "all" ? "الكل" : getTransactionLabel(type as any)}
            </button>
          ))}
        </div>

        {/* Transactions List */}
        <div className="space-y-3">
          {filteredTransactions.length === 0 ? (
            <div className="text-center py-12 bg-gray-50 dark:bg-gray-900 rounded-2xl">
              <Receipt className="w-16 h-16 text-gray-300 mx-auto mb-4" />
              <p className="text-gray-500">لا توجد عمليات</p>
            </div>
          ) : (
            filteredTransactions.map(transaction => {
              const student = transaction.studentId 
                ? students.find(s => s.id === transaction.studentId)
                : null;

              return (
                <div
                  key={transaction.id}
                  className={`border rounded-xl p-4 flex items-center justify-between ${getTransactionColor(
                    transaction.type
                  )}`}
                >
                  <div className="flex-1">
                    <p className="font-bold">{transaction.reason}</p>
                    <p className="text-sm opacity-70 mt-1">
                      {student ? `من: ${student.name}` : "عملية عامة"} • {transaction.date}
                    </p>
                    {transaction.notes && (
                      <p className="text-xs opacity-60 mt-1">ملاحظات: {transaction.notes}</p>
                    )}
                  </div>
                  <div className="text-right">
                    <p className={`text-lg font-black ${
                      transaction.amount > 0 ? "text-green-600" : "text-red-600"
                    }`}>
                      {transaction.amount > 0 ? "+" : ""}{transaction.amount}
                    </p>
                    <p className="text-xs opacity-60">ر.س</p>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Modal Form */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 flex items-end md:items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-3xl p-8 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-black">تسجيل عملية جديدة</h2>
              <button onClick={() => setShowForm(false)} className="text-gray-400 hover:text-gray-600">
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label className="block text-sm font-bold mb-3">نوع العملية</label>
                <select
                  value={formData.type}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      type: e.target.value as FundTransaction["type"],
                    })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                >
                  <option value="subscription">اشتراك</option>
                  <option value="donation">تبرع</option>
                  <option value="penalty">عقوبة محولة</option>
                  <option value="expense">مصروف</option>
                </select>
              </div>

              {(formData.type === "subscription" || formData.type === "penalty") && (
                <div>
                  <label className="block text-sm font-bold mb-3">الطالب</label>
                  <select
                    value={formData.studentId}
                    onChange={(e) =>
                      setFormData({ ...formData, studentId: e.target.value })
                    }
                    className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  >
                    <option value="">اختر طالباً</option>
                    {students.map(student => (
                      <option key={student.id} value={student.id}>
                        {student.name}
                      </option>
                    ))}
                  </select>
                </div>
              )}

              <div>
                <label className="block text-sm font-bold mb-3">المبلغ (ر.س)</label>
                <input
                  type="number"
                  value={formData.amount}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      amount: Number(e.target.value),
                    })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  min="0"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">السبب / الوصف</label>
                <input
                  type="text"
                  value={formData.reason}
                  onChange={(e) =>
                    setFormData({ ...formData, reason: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  placeholder="مثل: اشتراك شهري"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">ملاحظات (اختياري)</label>
                <textarea
                  value={formData.notes}
                  onChange={(e) =>
                    setFormData({ ...formData, notes: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium resize-none"
                  rows={3}
                  placeholder="أي ملاحظات إضافية..."
                />
              </div>

              <button
                type="submit"
                className="w-full bg-green-600 text-white font-bold py-3 rounded-xl hover:bg-green-700 transition-all"
              >
                تسجيل العملية
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
