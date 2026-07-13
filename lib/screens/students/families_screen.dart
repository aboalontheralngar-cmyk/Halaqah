import 'package:flutter/material.dart';

import '../../models/family.dart';
import '../../models/family_guardian.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class FamiliesScreen extends StatefulWidget {
  const FamiliesScreen({super.key});

  @override
  State<FamiliesScreen> createState() => _FamiliesScreenState();
}

class _FamiliesScreenState extends State<FamiliesScreen> {
  final DatabaseService _db = DatabaseService();
  List<Family> _families = [];
  final Map<String, int> _memberCounts = {};
  final Map<String, int> _guardianCounts = {};
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final families = await _db.getFamilies();
    final members = await Future.wait(
      families.map((family) => _db.getFamilyMembers(family.id)),
    );
    final guardians = await Future.wait(
      families.map((family) => _db.getFamilyGuardians(family.id)),
    );
    if (!mounted) return;
    setState(() {
      _families = families;
      for (var index = 0; index < families.length; index++) {
        _memberCounts[families[index].id] = members[index].length;
        _guardianCounts[families[index].id] = guardians[index].length;
      }
      _loading = false;
    });
  }

  List<Family> get _filtered => _families.where((family) {
        final query = _search.trim().toLowerCase();
        if (query.isEmpty) return true;
        return family.name.toLowerCase().contains(query) ||
            (family.referenceName ?? '').toLowerCase().contains(query) ||
            family.displayCode.toLowerCase().contains(query);
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العائلات وأولياء الأمور'),
        actions: [
          IconButton(
            onPressed: () => _editFamily(),
            icon: const Icon(Icons.add),
            tooltip: 'إضافة عائلة',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو المرجع أو كود العائلة',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                  const SizedBox(height: 12),
                  if (_filtered.isEmpty)
                    _emptyState()
                  else
                    ..._filtered.map(_familyCard),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editFamily(),
        icon: const Icon(Icons.family_restroom),
        label: const Text('عائلة جديدة'),
      ),
    );
  }

  Widget _emptyState() => Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.family_restroom, size: 52, color: Colors.grey[400]),
              const SizedBox(height: 12),
              const Text('لا توجد عائلات مسجلة'),
              const SizedBox(height: 6),
              const Text(
                'أنشئ عائلة ثم اربط بها الإخوة وأولياء أمورهم دون الاعتماد على تشابه الأسماء.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );

  Widget _familyCard(Family family) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.family_restroom)),
          title: Text(family.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if ((family.referenceName ?? '').isNotEmpty)
                Text('المرجع العائلي: ${family.referenceName}'),
              Text(
                '${family.displayCode} · ${_memberCounts[family.id] ?? 0} طالب · '
                '${_guardianCounts[family.id] ?? 0} ولي أمر',
              ),
            ],
          ),
          isThreeLine: (family.referenceName ?? '').isNotEmpty,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FamilyDetailScreen(familyId: family.id),
              ),
            );
            await _load();
          },
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') _editFamily(family);
              if (value == 'delete') _deleteFamily(family);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('تعديل بيانات العائلة')),
              PopupMenuItem(value: 'delete', child: Text('حذف العائلة')),
            ],
          ),
        ),
      );

  Future<void> _editFamily([Family? family]) async {
    final name = TextEditingController(text: family?.name ?? '');
    final reference = TextEditingController(text: family?.referenceName ?? '');
    final notes = TextEditingController(text: family?.notes ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(family == null ? 'إضافة عائلة' : 'تعديل العائلة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'اسم العائلة *',
                  hintText: 'مثال: عائلة آل محمد',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reference,
                decoration: const InputDecoration(
                  labelText: 'الجد أو المرجع العائلي',
                  hintText: 'يميز العائلات المتشابهة في اللقب',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'ملاحظات'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (result != true || name.text.trim().isEmpty) return;
    final value = family ?? Family(name: name.text.trim());
    value
      ..name = name.text.trim()
      ..referenceName = reference.text.trim()
      ..notes = notes.text.trim();
    await _db.saveFamily(value);
    await _load();
  }

  Future<void> _deleteFamily(Family family) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف العائلة؟'),
        content: Text(
          'سيزال ربط الطلاب بعائلة «${family.name}» وتحذف بيانات أولياء الأمر العائلية. '
          'لن تحذف سجلات الطلاب أو تسميعهم.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteFamily(family.id);
    await _load();
  }
}

class FamilyDetailScreen extends StatefulWidget {
  final String familyId;

  const FamilyDetailScreen({super.key, required this.familyId});

  @override
  State<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends State<FamilyDetailScreen> {
  final DatabaseService _db = DatabaseService();
  Family? _family;
  List<Student> _members = [];
  List<FamilyGuardian> _guardians = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final values = await Future.wait<dynamic>([
      _db.getFamily(widget.familyId),
      _db.getFamilyMembers(widget.familyId),
      _db.getFamilyGuardians(widget.familyId),
    ]);
    if (!mounted) return;
    setState(() {
      _family = values[0] as Family?;
      _members = values[1] as List<Student>;
      _guardians = values[2] as List<FamilyGuardian>;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final family = _family;
    return Scaffold(
      appBar: AppBar(title: Text(family?.name ?? 'تفاصيل العائلة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : family == null
              ? const Center(child: Text('العائلة غير موجودة'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                          title: Text(family.displayCode),
                          subtitle: Text(
                            (family.referenceName ?? '').isEmpty
                                ? 'لا يوجد مرجع عائلي إضافي'
                                : 'المرجع: ${family.referenceName}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _sectionHeader(
                        'أفراد العائلة',
                        Icons.groups_outlined,
                        'إدارة الربط',
                        _chooseMembers,
                      ),
                      if (_members.isEmpty)
                        const Card(child: ListTile(title: Text('لم يربط أي طالب بهذه العائلة')))
                      else
                        ..._members.map(
                          (student) => Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text(student.name.isEmpty ? '؟' : student.name[0])),
                              title: Text(student.name),
                              subtitle: Text('${student.displayCode} · ${student.status}'),
                              trailing: IconButton(
                                onPressed: () async {
                                  await _db.removeStudentFromFamily(student.id);
                                  await _load();
                                },
                                icon: const Icon(Icons.link_off),
                                tooltip: 'إزالة الربط فقط',
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _sectionHeader(
                        'أولياء الأمور',
                        Icons.contact_phone_outlined,
                        'إضافة ولي',
                        () => _editGuardian(),
                      ),
                      if (_guardians.isEmpty)
                        const Card(child: ListTile(title: Text('لا يوجد ولي أمر مسجل للعائلة')))
                      else
                        ..._guardians.map(_guardianCard),
                    ],
                  ),
                ),
    );
  }

  Widget _sectionHeader(
    String title,
    IconData icon,
    String action,
    VoidCallback onPressed,
  ) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
            TextButton.icon(onPressed: onPressed, icon: const Icon(Icons.add), label: Text(action)),
          ],
        ),
      );

  Widget _guardianCard(FamilyGuardian guardian) => Card(
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(guardian.isPrimary ? Icons.star : Icons.person_outline),
          ),
          title: Row(
            children: [
              Expanded(child: Text(guardian.name)),
              if (guardian.isPrimary)
                const Chip(label: Text('الأساسي'), visualDensity: VisualDensity.compact),
            ],
          ),
          subtitle: Text('${guardian.relationshipLabel} · ${guardian.phone}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') await _editGuardian(guardian);
              if (value == 'delete') {
                await _db.deleteFamilyGuardian(guardian.id);
                await _load();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
          ),
        ),
      );

  Future<void> _chooseMembers() async {
    final students = await _db.getStudents();
    final selected = students
        .where((student) => student.familyId == widget.familyId)
        .map((student) => student.id)
        .toSet();
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('اختيار أفراد العائلة'),
          content: SizedBox(
            width: double.maxFinite,
            height: 420,
            child: ListView(
              children: students.map((student) {
                final belongsElsewhere = student.familyId != null &&
                    student.familyId != widget.familyId;
                return CheckboxListTile(
                  value: selected.contains(student.id),
                  title: Text(student.name),
                  subtitle: belongsElsewhere
                      ? const Text('مرتبط بعائلة أخرى — سيُنقل عند الاختيار')
                      : Text(student.displayCode),
                  onChanged: (value) => setDialogState(() {
                    value == true ? selected.add(student.id) : selected.remove(student.id);
                  }),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('اعتماد')),
          ],
        ),
      ),
    );
    if (result == null) return;
    for (final member in _members.where((item) => !result.contains(item.id))) {
      await _db.removeStudentFromFamily(member.id);
    }
    await _db.assignStudentsToFamily(
      familyId: widget.familyId,
      studentIds: result.toList(),
    );
    await _load();
  }

  Future<void> _editGuardian([FamilyGuardian? guardian]) async {
    final name = TextEditingController(text: guardian?.name ?? '');
    final phone = TextEditingController(text: guardian?.phone ?? '');
    final email = TextEditingController(text: guardian?.email ?? '');
    final notes = TextEditingController(text: guardian?.notes ?? '');
    var relationship = guardian?.relationship ?? 'father';
    var primary = guardian?.isPrimary ?? _guardians.isEmpty;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(guardian == null ? 'إضافة ولي أمر' : 'تعديل ولي الأمر'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم *')),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف *'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: relationship,
                  decoration: const InputDecoration(labelText: 'صلة القرابة'),
                  items: const [
                    DropdownMenuItem(value: 'father', child: Text('الأب')),
                    DropdownMenuItem(value: 'mother', child: Text('الأم')),
                    DropdownMenuItem(value: 'brother', child: Text('الأخ')),
                    DropdownMenuItem(value: 'grandfather', child: Text('الجد')),
                    DropdownMenuItem(value: 'uncle', child: Text('العم/الخال')),
                    DropdownMenuItem(value: 'guardian', child: Text('ولي أمر')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (value) => setDialogState(() => relationship = value ?? 'guardian'),
                ),
                const SizedBox(height: 10),
                TextField(controller: email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: primary,
                  title: const Text('جهة الاتصال الأساسية'),
                  subtitle: const Text('يستخدم رقمه افتراضيًا في تقارير أبناء العائلة'),
                  onChanged: (value) => setDialogState(() => primary = value),
                ),
                TextField(controller: notes, maxLines: 2, decoration: const InputDecoration(labelText: 'ملاحظات')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty || phone.text.trim().isEmpty) return;
    final value = guardian ?? FamilyGuardian(
      familyId: widget.familyId,
      name: name.text,
      phone: phone.text,
    );
    value
      ..name = name.text.trim()
      ..phone = phone.text.trim()
      ..email = email.text.trim()
      ..relationship = relationship
      ..isPrimary = primary
      ..notes = notes.text.trim();
    await _db.saveFamilyGuardian(value);
    await _load();
  }
}
