"use client";

import { useState, useMemo } from "react";
import {
  Users,
  Phone,
  MessageSquare,
  Send,
  Plus,
  Edit,
  Trash2,
  X,
  Search,
  Mail,
  AlertCircle,
  CheckCircle,
  Clock,
  User,
} from "lucide-react";
import { useStore } from "@/store/useStore";

interface Parent {
  id: string;
  studentId: string;
  name: string;
  phone: string;
  email?: string;
  relationship: "father" | "mother" | "guardian";
  notes?: string;
}

export default function ParentsPage() {
  const { students } = useStore();

  // محاكاة بيانات أولياء الأمور
  const [parents, setParents] = useState<Parent[]>([
    {
      id: "1",
      studentId: "1",
      name: "محمد علي",
      phone: "0551234567",
      email: "mohd@email.com",
      relationship: "father",
      notes: "يفضل التواصل بالهاتف في الصباح",
    },
    {
      id: "2",
      studentId: "2",
      name: "فاطمة أحمد",
      phone: "0552345678",
      email: "fatma@email.com",
      relationship: "mother",
      notes: "",
    },
  ]);

  const [search, setSearch] = useState("");
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [showMessage, setShowMessage] = useState<string | null>(null);
  const [messageText, setMessageText] = useState("");

  const [formData, setFormData] = useState({
    studentId: "",
    name: "",
    phone: "",
    email: "",
    relationship: "father" as Parent["relationship"],
    notes: "",
  });

  const filteredParents = useMemo(() => {
    return parents.filter(
      (p) =>
        p.name.includes(search) ||
        p.phone.includes(search) ||
        students.find((s) => s.id === p.studentId)?.name.includes(search)
    );
  }, [parents, search]);

  const parentsByStudent = useMemo(() => {
    const grouped: { [key: string]: Parent[] } = {};
    parents.forEach((p) => {
      if (!grouped[p.studentId]) grouped[p.studentId] = [];
      grouped[p.studentId].push(p);
    });
    return grouped;
  }, [parents]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editingId) {
      setParents(
        parents.map((p) =>
          p.id === editingId ? { ...p, ...formData, id: p.id } : p
        )
      );
      setEditingId(null);
    } else {
      const newParent: Parent = {
        id: Date.now().toString(),
        ...formData,
      };
      setParents([...parents, newParent]);
    }
    setShowForm(false);
    setFormData({
      studentId: "",
      name: "",
      phone: "",
      email: "",
      relationship: "father",
      notes: "",
    });
  };

  const getRelationshipLabel = (rel: Parent["relationship"]) => {
    const labels = {
      father: "الأب",
      mother: "الأم",
      guardian: "ولي أمر",
    };
    return labels[rel];
  };

  const stats = useMemo(() => {
    return {
      totalParents: parents.length,
      withPhone: parents.filter((p) => p.phone).length,
      withEmail: parents.filter((p) => p.email).length,
      uniqueStudents: Object.keys(parentsByStudent).length,
    };
  }, [parents, parentsByStudent]);

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight flex items-center gap-4">
            <Users className="w-8 h-8" />
            إدارة أولياء الأمور
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">
            تواصل مباشر مع أولياء الأمور ومتابعة بيانات الاتصال
          </p>
        </div>
        <button
          onClick={() => {
            setEditingId(null);
            setShowForm(true);
          }}
          className="bg-teal-600 text-white px-8 py-4 rounded-3xl font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-2"
        >
          <Plus className="w-5 h-5" /> إضافة ولي أمر
        </button>
      </div>

      {/* Stats */}
      <div className="grid md:grid-cols-4 gap-4">
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">إجمالي الأولياء</p>
          <p className="text-3xl font-black text-teal-600">{stats.totalParents}</p>
        </div>
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">بأرقام هاتف</p>
          <p className="text-3xl font-black text-blue-600">{stats.withPhone}</p>
        </div>
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">ببريد إلكتروني</p>
          <p className="text-3xl font-black text-purple-600">{stats.withEmail}</p>
        </div>
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">عدد الطلاب</p>
          <p className="text-3xl font-black text-orange-600">
            {stats.uniqueStudents}
          </p>
        </div>
      </div>

      {/* Search */}
      <div className="relative">
        <Search className="absolute right-4 top-3 w-5 h-5 text-gray-400" />
        <input
          type="text"
          placeholder="ابحث عن ولي أمر أو طالب..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full pl-4 pr-12 py-3 border border-gray-300 dark:border-gray-700 rounded-xl bg-white dark:bg-gray-900 font-medium"
        />
      </div>

      {/* Parents by Student */}
      <div className="space-y-8">
        {Object.entries(parentsByStudent)
          .sort((a, b) => {
            const studentA = students.find((s) => s.id === a[0]);
            const studentB = students.find((s) => s.id === b[0]);
            return (studentA?.name || "").localeCompare(studentB?.name || "");
          })
          .filter(
            ([studentId]) =>
              search === "" ||
              students.find((s) => s.id === studentId)?.name.includes(search) ||
              parentsByStudent[studentId].some(
                (p) =>
                  p.name.includes(search) ||
                  p.phone.includes(search)
              )
          )
          .map(([studentId, studentParents]) => {
            const student = students.find((s) => s.id === studentId);
            if (!student) return null;

            return (
              <div
                key={studentId}
                className="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-800 p-8 space-y-6"
              >
                <div className="flex items-center gap-4 pb-6 border-b border-gray-200 dark:border-gray-800">
                  <div className="w-12 h-12 rounded-2xl bg-teal-100 dark:bg-teal-900/30 flex items-center justify-center font-black text-teal-600 dark:text-teal-400">
                    {student.name[0]}
                  </div>
                  <div>
                    <h2 className="text-2xl font-black text-gray-900 dark:text-white">
                      {student.name}
                    </h2>
                    <p className="text-sm text-gray-500 dark:text-gray-400">
                      المستوى: {student.level}
                    </p>
                  </div>
                </div>

                <div className="grid md:grid-cols-2 gap-6">
                  {studentParents.map((parent) => (
                    <div
                      key={parent.id}
                      className="border-2 border-gray-200 dark:border-gray-800 rounded-2xl p-6 space-y-4"
                    >
                      <div className="flex items-start justify-between">
                        <div className="flex-1">
                          <h3 className="font-black text-lg text-gray-900 dark:text-white">
                            {parent.name}
                          </h3>
                          <p className="text-xs font-bold text-teal-600 mt-1">
                            {getRelationshipLabel(parent.relationship)}
                          </p>
                        </div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => {
                              setFormData({
                                studentId: parent.studentId,
                                name: parent.name,
                                phone: parent.phone,
                                email: parent.email || "",
                                relationship: parent.relationship,
                                notes: parent.notes || "",
                              });
                              setEditingId(parent.id);
                              setShowForm(true);
                            }}
                            className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() =>
                              setParents(parents.filter((p) => p.id !== parent.id))
                            }
                            className="p-2 text-red-600 hover:bg-red-100 rounded-lg"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                      <div className="space-y-2 text-sm">
                        <div className="flex items-center gap-3">
                          <Phone className="w-4 h-4 text-gray-400" />
                          <a
                            href={`tel:${parent.phone}`}
                            className="font-bold text-teal-600 hover:underline"
                          >
                            {parent.phone}
                          </a>
                        </div>
                        {parent.email && (
                          <div className="flex items-center gap-3">
                            <Mail className="w-4 h-4 text-gray-400" />
                            <a
                              href={`mailto:${parent.email}`}
                              className="font-bold text-purple-600 hover:underline truncate"
                            >
                              {parent.email}
                            </a>
                          </div>
                        )}
                      </div>

                      {parent.notes && (
                        <div className="p-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg">
                          <p className="text-xs font-bold text-yellow-800 dark:text-yellow-300">
                            ملاحظات: {parent.notes}
                          </p>
                        </div>
                      )}

                      <button
                        onClick={() => setShowMessage(parent.id)}
                        className="w-full px-4 py-2 bg-teal-50 dark:bg-teal-900/20 border border-teal-200 dark:border-teal-800 text-teal-600 dark:text-teal-400 font-bold rounded-lg hover:bg-teal-100 transition-all flex items-center justify-center gap-2"
                      >
                        <MessageSquare className="w-4 h-4" />
                        إرسال رسالة
                      </button>
                    </div>
                  ))}
                </div>
              </div>
            );
          })}
      </div>

      {/* Modal Form */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 flex items-end md:items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-3xl p-8 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-black">
                {editingId ? "تعديل ولي أمر" : "إضافة ولي أمر جديد"}
              </h2>
              <button
                onClick={() => setShowForm(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label className="block text-sm font-bold mb-3">الطالب</label>
                <select
                  value={formData.studentId}
                  onChange={(e) =>
                    setFormData({ ...formData, studentId: e.target.value })
                  }
                  disabled={!!editingId}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium disabled:opacity-50"
                  required
                >
                  <option value="">اختر طالباً</option>
                  {students.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">اسم ولي الأمر</label>
                <input
                  type="text"
                  value={formData.name}
                  onChange={(e) =>
                    setFormData({ ...formData, name: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">رقم الهاتف</label>
                <input
                  type="tel"
                  value={formData.phone}
                  onChange={(e) =>
                    setFormData({ ...formData, phone: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">البريد الإلكتروني (اختياري)</label>
                <input
                  type="email"
                  value={formData.email}
                  onChange={(e) =>
                    setFormData({ ...formData, email: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">العلاقة</label>
                <select
                  value={formData.relationship}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      relationship: e.target.value as Parent["relationship"],
                    })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                >
                  <option value="father">الأب</option>
                  <option value="mother">الأم</option>
                  <option value="guardian">ولي أمر</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">ملاحظات</label>
                <textarea
                  value={formData.notes}
                  onChange={(e) =>
                    setFormData({ ...formData, notes: e.target.value })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium resize-none"
                  rows={3}
                  placeholder="مثل: يفضل التواصل في أوقات محددة"
                />
              </div>

              <button
                type="submit"
                className="w-full bg-teal-600 text-white font-bold py-3 rounded-xl hover:bg-teal-700 transition-all"
              >
                {editingId ? "تحديث" : "إضافة"}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Message Modal */}
      {showMessage && (
        <div className="fixed inset-0 bg-black/50 flex items-end md:items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-3xl p-8 w-full max-w-md shadow-2xl">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-black">إرسال رسالة</h2>
              <button
                onClick={() => setShowMessage(null)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            {(() => {
              const parent = parents.find((p) => p.id === showMessage);
              return (
                <>
                  <div className="mb-6 p-4 bg-gray-50 dark:bg-gray-800 rounded-xl">
                    <p className="text-sm font-bold text-gray-500 mb-2">إلى</p>
                    <p className="font-black text-lg">{parent?.name}</p>
                    <p className="text-sm text-gray-500 mt-1">
                      {getRelationshipLabel(parent?.relationship || "father")} •{" "}
                      {parent?.phone}
                    </p>
                  </div>

                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      // TODO: Send WhatsApp/SMS message
                      setShowMessage(null);
                      setMessageText("");
                    }}
                    className="space-y-4"
                  >
                    <textarea
                      value={messageText}
                      onChange={(e) => setMessageText(e.target.value)}
                      className="w-full px-4 py-3 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium resize-none"
                      rows={5}
                      placeholder="اكتب رسالتك هنا..."
                      required
                    />

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
                        onClick={() => setShowMessage(null)}
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
