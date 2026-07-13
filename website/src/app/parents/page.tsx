"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import {
  BadgeCheck,
  Edit3,
  House,
  Link2,
  Mail,
  Phone,
  Plus,
  Search,
  Trash2,
  UserRound,
  Users,
  X,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useStore, type Student } from "@/store/useStore";

type FamilyRecord = {
  id: string;
  name: string;
  referenceName?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
};

type GuardianRecord = {
  id: string;
  familyId: string;
  name: string;
  phone: string;
  email?: string;
  relationship: string;
  isPrimary: boolean;
  notes?: string;
};

type FamilyRow = {
  id: string;
  name: string;
  reference_name?: string | null;
  notes?: string | null;
  created_at: string;
  updated_at: string;
};

type GuardianRow = {
  id: string;
  family_id: string;
  name: string;
  phone: string;
  email?: string | null;
  relationship: string;
  is_primary: boolean;
  notes?: string | null;
};

const relationshipLabels: Record<string, string> = {
  father: "الأب",
  mother: "الأم",
  brother: "الأخ",
  grandfather: "الجد",
  uncle: "العم/الخال",
  guardian: "ولي أمر",
  other: "صلة أخرى",
};

const familyCode = (id: string) =>
  `FAM-${id.replace(/[^a-zA-Z0-9]/g, "").slice(0, 8).toUpperCase().padEnd(8, "0")}`;

export default function ParentsPage() {
  const { students, currentCenter, fetchStudents } = useStore();
  const [families, setFamilies] = useState<FamilyRecord[]>([]);
  const [guardians, setGuardians] = useState<GuardianRecord[]>([]);
  const [selectedFamilyId, setSelectedFamilyId] = useState<string | null>(null);
  const [search, setSearch] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [familyForm, setFamilyForm] = useState<FamilyRecord | "new" | null>(null);
  const [guardianForm, setGuardianForm] = useState<GuardianRecord | "new" | null>(null);
  const [showMembers, setShowMembers] = useState(false);

  const halaqaId = currentCenter?.activeHalaqa?.id;

  const load = useCallback(async () => {
    if (!supabase || !currentCenter || !halaqaId) {
      setLoading(false);
      setError("اختر حلقة محددة أولًا لإدارة العائلات.");
      return;
    }
    setLoading(true);
    setError("");
    const [familyResult, guardianResult] = await Promise.all([
      supabase.from("families").select("*").eq("halaqa_id", halaqaId).order("name"),
      supabase
        .from("family_guardians")
        .select("*")
        .eq("halaqa_id", halaqaId)
        .order("is_primary", { ascending: false })
        .order("name"),
    ]);
    if (familyResult.error || guardianResult.error) {
      setError(
        familyResult.error?.message ||
          guardianResult.error?.message ||
          "تعذر تحميل بيانات العائلات",
      );
      setFamilies([]);
      setGuardians([]);
    } else {
      const mappedFamilies = ((familyResult.data || []) as FamilyRow[]).map((item) => ({
        id: item.id,
        name: item.name,
        referenceName: item.reference_name || undefined,
        notes: item.notes || undefined,
        createdAt: item.created_at,
        updatedAt: item.updated_at,
      }));
      setFamilies(mappedFamilies);
      setGuardians(
        ((guardianResult.data || []) as GuardianRow[]).map((item) => ({
          id: item.id,
          familyId: item.family_id,
          name: item.name,
          phone: item.phone,
          email: item.email || undefined,
          relationship: item.relationship,
          isPrimary: item.is_primary,
          notes: item.notes || undefined,
        })),
      );
      setSelectedFamilyId((current) =>
        current && mappedFamilies.some((family) => family.id === current)
          ? current
          : mappedFamilies[0]?.id || null,
      );
    }
    setLoading(false);
  }, [currentCenter, halaqaId]);

  useEffect(() => {
    load();
  }, [load]);

  const filteredFamilies = useMemo(() => {
    const query = search.trim().toLocaleLowerCase("ar");
    if (!query) return families;
    return families.filter(
      (family) =>
        family.name.toLocaleLowerCase("ar").includes(query) ||
        (family.referenceName || "").toLocaleLowerCase("ar").includes(query) ||
        familyCode(family.id).toLowerCase().includes(query),
    );
  }, [families, search]);

  const selectedFamily = families.find((family) => family.id === selectedFamilyId);
  const selectedGuardians = guardians.filter(
    (guardian) => guardian.familyId === selectedFamilyId,
  );
  const selectedMembers = students.filter(
    (student) => student.familyId === selectedFamilyId,
  );

  if (loading) {
    return <div className="py-24 text-center font-black text-teal-600">جارٍ تحميل العائلات…</div>;
  }

  return (
    <div className="space-y-6 pb-20" dir="rtl">
      <header className="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
        <div>
          <h1 className="flex items-center gap-3 text-3xl font-black text-gray-900 dark:text-white">
            <House className="h-8 w-8 text-teal-600" /> العائلات وأولياء الأمور
          </h1>
          <p className="mt-2 font-medium text-gray-500 dark:text-gray-400">
            ربط صريح للإخوة والأقارب وبيانات تواصل موحدة دون الاعتماد على تشابه الأسماء.
          </p>
        </div>
        <button
          onClick={() => setFamilyForm("new")}
          className="flex items-center justify-center gap-2 rounded-2xl bg-teal-600 px-6 py-3 font-black text-white hover:bg-teal-700"
        >
          <Plus className="h-5 w-5" /> عائلة جديدة
        </button>
      </header>

      {error && (
        <div className="rounded-2xl border border-red-200 bg-red-50 p-4 font-bold text-red-700 dark:border-red-900 dark:bg-red-950/30 dark:text-red-300">
          {error}
          {error.includes("families") && (
            <span className="mt-1 block text-sm">نفّذ migration المرحلة P5.4 في Supabase ثم أعد المحاولة.</span>
          )}
        </div>
      )}

      <section className="grid gap-4 md:grid-cols-3">
        <Stat label="العائلات" value={families.length} icon={<House />} color="teal" />
        <Stat label="أولياء الأمور" value={guardians.length} icon={<UserRound />} color="blue" />
        <Stat
          label="الطلاب المرتبطون"
          value={students.filter((student) => student.familyId).length}
          icon={<Link2 />}
          color="purple"
        />
      </section>

      <div className="grid gap-6 lg:grid-cols-[340px_1fr]">
        <aside className="rounded-3xl border border-gray-200 bg-white p-4 dark:border-gray-800 dark:bg-gray-900">
          <div className="relative mb-4">
            <Search className="absolute right-3 top-3 h-5 w-5 text-gray-400" />
            <input
              value={search}
              onChange={(event) => setSearch(event.target.value)}
              placeholder="بحث عن عائلة…"
              className="w-full rounded-xl border border-gray-200 bg-gray-50 py-3 pl-3 pr-10 font-bold outline-none focus:border-teal-500 dark:border-gray-700 dark:bg-gray-800"
            />
          </div>
          <div className="space-y-2">
            {filteredFamilies.map((family) => {
              const active = family.id === selectedFamilyId;
              const memberCount = students.filter((student) => student.familyId === family.id).length;
              return (
                <button
                  key={family.id}
                  onClick={() => setSelectedFamilyId(family.id)}
                  className={`w-full rounded-2xl border p-4 text-right transition ${
                    active
                      ? "border-teal-500 bg-teal-50 dark:bg-teal-950/30"
                      : "border-transparent hover:bg-gray-50 dark:hover:bg-gray-800"
                  }`}
                >
                  <div className="font-black text-gray-900 dark:text-white">{family.name}</div>
                  <div className="mt-1 text-xs font-bold text-gray-500">
                    {familyCode(family.id)} · {memberCount} طالب
                  </div>
                </button>
              );
            })}
            {!filteredFamilies.length && (
              <div className="py-12 text-center text-sm font-bold text-gray-400">لا توجد عائلات</div>
            )}
          </div>
        </aside>

        <main>
          {!selectedFamily ? (
            <div className="rounded-3xl border border-dashed border-gray-300 p-16 text-center dark:border-gray-700">
              <House className="mx-auto mb-4 h-14 w-14 text-gray-300" />
              <p className="font-black text-gray-500">أنشئ عائلة للبدء بالربط المنظم.</p>
            </div>
          ) : (
            <div className="space-y-6">
              <section className="rounded-3xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
                <div className="flex flex-col gap-4 md:flex-row md:items-start md:justify-between">
                  <div>
                    <h2 className="text-2xl font-black text-gray-900 dark:text-white">{selectedFamily.name}</h2>
                    <p className="mt-1 font-mono text-sm font-bold text-teal-600">{familyCode(selectedFamily.id)}</p>
                    {selectedFamily.referenceName && (
                      <p className="mt-2 text-sm font-bold text-gray-500">المرجع العائلي: {selectedFamily.referenceName}</p>
                    )}
                  </div>
                  <div className="flex gap-2">
                    <button onClick={() => setFamilyForm(selectedFamily)} className="rounded-xl bg-blue-50 p-3 text-blue-600 hover:bg-blue-100 dark:bg-blue-950/30">
                      <Edit3 className="h-5 w-5" />
                    </button>
                    <button onClick={() => deleteFamily(selectedFamily)} className="rounded-xl bg-red-50 p-3 text-red-600 hover:bg-red-100 dark:bg-red-950/30">
                      <Trash2 className="h-5 w-5" />
                    </button>
                  </div>
                </div>
              </section>

              <section className="rounded-3xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
                <SectionTitle title="أفراد العائلة" icon={<Users />} action="إدارة الربط" onClick={() => setShowMembers(true)} />
                <div className="mt-4 grid gap-3 md:grid-cols-2">
                  {selectedMembers.map((student) => (
                    <div key={student.id} className="rounded-2xl bg-gray-50 p-4 dark:bg-gray-800">
                      <div className="font-black text-gray-900 dark:text-white">{student.name}</div>
                      <div className="mt-1 text-xs font-bold text-gray-500">{student.status} · {student.parentPhone || "لا يوجد رقم ولي"}</div>
                    </div>
                  ))}
                  {!selectedMembers.length && <Empty text="لا يوجد طلاب مرتبطون بهذه العائلة" />}
                </div>
              </section>

              <section className="rounded-3xl border border-gray-200 bg-white p-6 dark:border-gray-800 dark:bg-gray-900">
                <SectionTitle title="أولياء الأمور" icon={<UserRound />} action="إضافة ولي" onClick={() => setGuardianForm("new")} />
                <div className="mt-4 grid gap-4 md:grid-cols-2">
                  {selectedGuardians.map((guardian) => (
                    <div key={guardian.id} className="rounded-2xl border border-gray-200 p-5 dark:border-gray-700">
                      <div className="flex items-start justify-between gap-4">
                        <div>
                          <div className="flex items-center gap-2 font-black text-gray-900 dark:text-white">
                            {guardian.name}
                            {guardian.isPrimary && <BadgeCheck className="h-5 w-5 text-teal-600" />}
                          </div>
                          <div className="mt-1 text-xs font-black text-teal-600">{relationshipLabels[guardian.relationship] || "ولي أمر"}</div>
                        </div>
                        <div className="flex gap-1">
                          <button onClick={() => setGuardianForm(guardian)} className="p-2 text-blue-600"><Edit3 className="h-4 w-4" /></button>
                          <button onClick={() => deleteGuardian(guardian)} className="p-2 text-red-600"><Trash2 className="h-4 w-4" /></button>
                        </div>
                      </div>
                      <div className="mt-4 space-y-2 text-sm font-bold text-gray-600 dark:text-gray-300">
                        <div className="flex items-center gap-2"><Phone className="h-4 w-4" /> {guardian.phone}</div>
                        {guardian.email && <div className="flex items-center gap-2"><Mail className="h-4 w-4" /> {guardian.email}</div>}
                      </div>
                    </div>
                  ))}
                  {!selectedGuardians.length && <Empty text="لا يوجد ولي أمر مسجل" />}
                </div>
              </section>
            </div>
          )}
        </main>
      </div>

      {familyForm && (
        <FamilyModal
          value={familyForm === "new" ? undefined : familyForm}
          onClose={() => setFamilyForm(null)}
          onSave={saveFamily}
        />
      )}
      {guardianForm && selectedFamily && (
        <GuardianModal
          value={guardianForm === "new" ? undefined : guardianForm}
          defaultPrimary={!selectedGuardians.length}
          onClose={() => setGuardianForm(null)}
          onSave={saveGuardian}
        />
      )}
      {showMembers && selectedFamily && (
        <MembersModal
          students={students}
          family={selectedFamily}
          onClose={() => setShowMembers(false)}
          onSave={saveMembers}
        />
      )}
    </div>
  );

  async function saveFamily(input: { name: string; referenceName: string; notes: string }) {
    if (!supabase || !currentCenter || !halaqaId || !input.name.trim()) return;
    const editing = familyForm && familyForm !== "new" ? familyForm : null;
    const payload = {
      center_id: currentCenter.id,
      halaqa_id: halaqaId,
      name: input.name.trim(),
      reference_name: input.referenceName.trim() || null,
      notes: input.notes.trim() || null,
      updated_at: new Date().toISOString(),
    };
    const result = editing
      ? await supabase.from("families").update(payload).eq("id", editing.id)
      : await supabase.from("families").insert(payload);
    if (result.error) return setError(result.error.message);
    setFamilyForm(null);
    await load();
  }

  async function deleteFamily(family: FamilyRecord) {
    if (!supabase || !confirm(`حذف عائلة «${family.name}»؟ لن تحذف سجلات الطلاب.`)) return;
    const { error: unlinkError } = await supabase.from("students").update({ family_id: null }).eq("family_id", family.id);
    if (unlinkError) return setError(unlinkError.message);
    const { error: deleteError } = await supabase.from("families").delete().eq("id", family.id);
    if (deleteError) return setError(deleteError.message);
    await Promise.all([load(), fetchStudents()]);
  }

  async function saveGuardian(input: Omit<GuardianRecord, "id" | "familyId">) {
    if (!supabase || !selectedFamily || !currentCenter || !halaqaId) return;
    const editing = guardianForm && guardianForm !== "new" ? guardianForm : null;
    const hasOtherPrimary = selectedGuardians.some(
      (guardian) => guardian.id !== editing?.id && guardian.isPrimary,
    );
    const effectivePrimary =
      input.isPrimary ||
      selectedGuardians.length <= 1 ||
      (editing?.isPrimary === true && !hasOtherPrimary);
    if (effectivePrimary) {
      const { error } = await supabase
        .from("family_guardians")
        .update({ is_primary: false })
        .eq("family_id", selectedFamily.id);
      if (error) return setError(error.message);
    }
    const payload = {
      family_id: selectedFamily.id,
      center_id: currentCenter.id,
      halaqa_id: halaqaId,
      name: input.name.trim(),
      phone: input.phone.trim(),
      email: input.email?.trim() || null,
      relationship: input.relationship,
      is_primary: effectivePrimary,
      notes: input.notes?.trim() || null,
      updated_at: new Date().toISOString(),
    };
    const result = editing
      ? await supabase.from("family_guardians").update(payload).eq("id", editing.id)
      : await supabase.from("family_guardians").insert(payload);
    if (result.error) return setError(result.error.message);
    if (effectivePrimary) {
      await supabase
        .from("students")
        .update({ parent_phone: input.phone.trim() })
        .eq("family_id", selectedFamily.id);
      await fetchStudents();
    }
    setGuardianForm(null);
    await load();
  }

  async function deleteGuardian(guardian: GuardianRecord) {
    if (!supabase || !confirm(`حذف ولي الأمر «${guardian.name}»؟`)) return;
    const { error: deleteError } = await supabase.from("family_guardians").delete().eq("id", guardian.id);
    if (deleteError) return setError(deleteError.message);
    if (guardian.isPrimary) {
      const next = selectedGuardians.find((item) => item.id !== guardian.id);
      if (next) {
        const { error: primaryError } = await supabase
          .from("family_guardians")
          .update({ is_primary: true })
          .eq("id", next.id);
        if (primaryError) return setError(primaryError.message);
        await supabase
          .from("students")
          .update({ parent_phone: next.phone })
          .eq("family_id", next.familyId);
        await fetchStudents();
      }
    }
    await load();
  }

  async function saveMembers(selected: Set<string>) {
    if (!supabase || !selectedFamily) return;
    const currentIds = students
      .filter((student) => student.familyId === selectedFamily.id)
      .map((student) => student.id);
    for (const id of currentIds.filter((id) => !selected.has(id))) {
      const { error: unlinkError } = await supabase.from("students").update({ family_id: null }).eq("id", id);
      if (unlinkError) return setError(unlinkError.message);
    }
    if (selected.size) {
      const { error: assignError } = await supabase.rpc("assign_students_to_family", {
        p_family_id: selectedFamily.id,
        p_student_ids: Array.from(selected),
      });
      if (assignError) return setError(assignError.message);
    }
    setShowMembers(false);
    await Promise.all([fetchStudents(), load()]);
  }
}

function Stat({ label, value, icon, color }: { label: string; value: number; icon: React.ReactNode; color: "teal" | "blue" | "purple" }) {
  const colorClass = {
    teal: "text-teal-600",
    blue: "text-blue-600",
    purple: "text-purple-600",
  }[color];
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-gray-900">
      <div className={`mb-3 ${colorClass}`}>{icon}</div>
      <div className="text-3xl font-black text-gray-900 dark:text-white">{value}</div>
      <div className="text-sm font-bold text-gray-500">{label}</div>
    </div>
  );
}

function SectionTitle({ title, icon, action, onClick }: { title: string; icon: React.ReactNode; action: string; onClick: () => void }) {
  return (
    <div className="flex items-center gap-3">
      <span className="text-teal-600">{icon}</span>
      <h3 className="flex-1 text-xl font-black text-gray-900 dark:text-white">{title}</h3>
      <button onClick={onClick} className="flex items-center gap-1 rounded-xl bg-teal-50 px-3 py-2 text-sm font-black text-teal-700 dark:bg-teal-950/30 dark:text-teal-300">
        <Plus className="h-4 w-4" /> {action}
      </button>
    </div>
  );
}

function Empty({ text }: { text: string }) {
  return <div className="rounded-2xl border border-dashed border-gray-300 p-8 text-center text-sm font-bold text-gray-400 dark:border-gray-700">{text}</div>;
}

function ModalShell({ title, onClose, children }: { title: string; onClose: () => void; children: React.ReactNode }) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/55 p-4" dir="rtl">
      <div className="max-h-[90vh] w-full max-w-xl overflow-y-auto rounded-3xl bg-white p-6 shadow-2xl dark:bg-gray-900">
        <div className="mb-5 flex items-center"><h2 className="flex-1 text-2xl font-black">{title}</h2><button onClick={onClose}><X /></button></div>
        {children}
      </div>
    </div>
  );
}

function FamilyModal({ value, onClose, onSave }: { value?: FamilyRecord; onClose: () => void; onSave: (input: { name: string; referenceName: string; notes: string }) => void }) {
  const [name, setName] = useState(value?.name || "");
  const [referenceName, setReferenceName] = useState(value?.referenceName || "");
  const [notes, setNotes] = useState(value?.notes || "");
  return (
    <ModalShell title={value ? "تعديل العائلة" : "عائلة جديدة"} onClose={onClose}>
      <form onSubmit={(event) => { event.preventDefault(); onSave({ name, referenceName, notes }); }} className="space-y-4">
        <Input label="اسم العائلة *" value={name} onChange={setName} placeholder="مثال: عائلة آل محمد" />
        <Input label="الجد أو المرجع العائلي" value={referenceName} onChange={setReferenceName} placeholder="لتمييز العائلات المتشابهة" />
        <Input label="ملاحظات" value={notes} onChange={setNotes} />
        <button disabled={!name.trim()} className="w-full rounded-2xl bg-teal-600 py-3 font-black text-white disabled:opacity-40">حفظ</button>
      </form>
    </ModalShell>
  );
}

function GuardianModal({ value, defaultPrimary, onClose, onSave }: { value?: GuardianRecord; defaultPrimary: boolean; onClose: () => void; onSave: (input: Omit<GuardianRecord, "id" | "familyId">) => void }) {
  const [name, setName] = useState(value?.name || "");
  const [phone, setPhone] = useState(value?.phone || "");
  const [email, setEmail] = useState(value?.email || "");
  const [relationship, setRelationship] = useState(value?.relationship || "father");
  const [isPrimary, setIsPrimary] = useState(value?.isPrimary ?? defaultPrimary);
  const [notes, setNotes] = useState(value?.notes || "");
  return (
    <ModalShell title={value ? "تعديل ولي الأمر" : "إضافة ولي أمر"} onClose={onClose}>
      <form onSubmit={(event) => { event.preventDefault(); onSave({ name, phone, email, relationship, isPrimary, notes }); }} className="space-y-4">
        <Input label="الاسم *" value={name} onChange={setName} />
        <Input label="رقم الهاتف *" value={phone} onChange={setPhone} />
        <Input label="البريد الإلكتروني" value={email} onChange={setEmail} />
        <label className="block text-sm font-black">صلة القرابة<select value={relationship} onChange={(event) => setRelationship(event.target.value)} className="mt-2 w-full rounded-xl border border-gray-200 bg-white p-3 dark:border-gray-700 dark:bg-gray-800">{Object.entries(relationshipLabels).map(([key, label]) => <option key={key} value={key}>{label}</option>)}</select></label>
        <label className="flex items-center gap-3 rounded-xl bg-gray-50 p-4 font-bold dark:bg-gray-800"><input type="checkbox" checked={isPrimary} onChange={(event) => setIsPrimary(event.target.checked)} /> جهة الاتصال الأساسية</label>
        <Input label="ملاحظات" value={notes} onChange={setNotes} />
        <button disabled={!name.trim() || !phone.trim()} className="w-full rounded-2xl bg-teal-600 py-3 font-black text-white disabled:opacity-40">حفظ</button>
      </form>
    </ModalShell>
  );
}

function MembersModal({ students, family, onClose, onSave }: { students: Student[]; family: FamilyRecord; onClose: () => void; onSave: (selected: Set<string>) => void }) {
  const [selected, setSelected] = useState(new Set(students.filter((student) => student.familyId === family.id).map((student) => student.id)));
  return (
    <ModalShell title={`أفراد ${family.name}`} onClose={onClose}>
      <p className="mb-4 text-sm font-bold text-amber-700 dark:text-amber-300">اختيار طالب مرتبط بعائلة أخرى سينقله إلى هذه العائلة بعد الاعتماد.</p>
      <div className="max-h-96 space-y-2 overflow-y-auto">
        {students.map((student) => (
          <label key={student.id} className="flex items-center gap-3 rounded-xl border border-gray-200 p-3 dark:border-gray-700">
            <input
              type="checkbox"
              checked={selected.has(student.id)}
              onChange={(event) => setSelected((current) => {
                const next = new Set(current);
                if (event.target.checked) next.add(student.id);
                else next.delete(student.id);
                return next;
              })}
            />
            <span className="flex-1 font-black">{student.name}</span>
            {student.familyId && student.familyId !== family.id && <span className="text-xs font-bold text-orange-600">عائلة أخرى</span>}
          </label>
        ))}
      </div>
      <button onClick={() => onSave(selected)} className="mt-5 w-full rounded-2xl bg-teal-600 py-3 font-black text-white">اعتماد الربط</button>
    </ModalShell>
  );
}

function Input({ label, value, onChange, placeholder }: { label: string; value: string; onChange: (value: string) => void; placeholder?: string }) {
  return <label className="block text-sm font-black">{label}<input value={value} onChange={(event) => onChange(event.target.value)} placeholder={placeholder} className="mt-2 w-full rounded-xl border border-gray-200 bg-white p-3 outline-none focus:border-teal-500 dark:border-gray-700 dark:bg-gray-800" /></label>;
}
