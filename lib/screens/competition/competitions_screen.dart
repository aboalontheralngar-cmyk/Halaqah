import 'package:flutter/material.dart';

import '../../models/competition.dart';
import '../../services/database_service.dart';
import '../../widgets/app_design_widgets.dart';
import 'competition_judge_screen.dart';
import 'peer_level_groups_screen.dart';

class CompetitionsScreen extends StatefulWidget {
  const CompetitionsScreen({super.key});

  @override
  State<CompetitionsScreen> createState() => _CompetitionsScreenState();
}

class _CompetitionsScreenState extends State<CompetitionsScreen> {
  final DatabaseService _db = DatabaseService();
  List<CompetitionEvent> _events = [];
  Map<String, int> _resultCounts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        _db.getCompetitionEvents(),
        _db.getCompetitionResultCounts(),
      ]);
      if (!mounted) return;
      setState(() {
        _events = values[0] as List<CompetitionEvent>;
        _resultCounts = values[1] as Map<String, int>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل المسابقات: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المسابقات والتحكيم')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: AppScreenBody(
                scrollable: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppPageIntro(
                      title: 'وحدة المسابقات',
                      subtitle:
                          'أنشئ فئات المسابقة، ولّد الأسئلة، وحكّم المتسابقين بدرجة حية من 100.',
                      icon: Icons.emoji_events_outlined,
                      actions: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const PeerLevelGroupsScreen()),
                          ),
                          icon: const Icon(Icons.groups_2_outlined),
                          label: const Text('مجموعات متقاربة'),
                        ),
                        FilledButton.icon(
                          onPressed: _createEvent,
                          icon: const Icon(Icons.add),
                          label: const Text('مسابقة جديدة'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    if (_events.isEmpty)
                      AppEmptyState(
                        icon: Icons.emoji_events_outlined,
                        title: 'لا توجد مسابقات بعد',
                        message:
                            'ابدأ بمسابقة داخلية للحلقة أو أنشئ فئة لفعالية مركزية.',
                        action: FilledButton.icon(
                          onPressed: _createEvent,
                          icon: const Icon(Icons.add),
                          label: const Text('إنشاء أول مسابقة'),
                        ),
                      )
                    else
                      ..._events.map(_eventCard),
                  ],
                ),
              ),
            ),
      floatingActionButton: _events.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _createEvent,
              icon: const Icon(Icons.add),
              label: const Text('مسابقة'),
            ),
    );
  }

  Widget _eventCard(CompetitionEvent event) {
    final scheme = Theme.of(context).colorScheme;
    final count = _resultCounts[event.id] ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _open(event),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${event.category} · $count تم تقييمهم',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إدارة المسابقة',
                onSelected: (value) {
                  if (value == 'edit') {
                    _editEvent(event);
                  } else if (value == 'delete') {
                    _deleteEvent(event);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('تعديل الاسم والفئة'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('حذف المسابقة'),
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_left,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<CompetitionEvent?> _eventDialog({CompetitionEvent? existing}) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final categoryController = TextEditingController(
      text: existing?.category ?? 'المصحف كاملًا',
    );
    try {
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: AppDialogTitle(
            icon: existing == null
                ? Icons.emoji_events_outlined
                : Icons.edit_outlined,
            title: existing == null ? 'مسابقة جديدة' : 'تعديل المسابقة',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المسابقة',
                  hintText: 'مسابقة الحلقة الشهرية',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'الفئة',
                  hintText: '3 أجزاء، 10 أجزاء، المصحف كاملًا',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty ||
                    categoryController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(existing == null ? 'إنشاء' : 'حفظ التعديل'),
            ),
          ],
        ),
      );
      if (save != true) return null;
      if (existing == null) {
        return CompetitionEvent(
          title: titleController.text.trim(),
          category: categoryController.text.trim(),
        );
      }
      return existing.copyWith(
        title: titleController.text.trim(),
        category: categoryController.text.trim(),
      );
    } finally {
      titleController.dispose();
      categoryController.dispose();
    }
  }

  Future<void> _createEvent() async {
    final event = await _eventDialog();
    if (event == null) return;
    await _db.saveCompetitionEvent(event);
    await _load();
    if (mounted) await _open(event);
  }

  Future<void> _editEvent(CompetitionEvent event) async {
    final updated = await _eventDialog(existing: event);
    if (updated == null) return;
    await _db.saveCompetitionEvent(updated);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث بيانات المسابقة')),
    );
  }

  Future<void> _deleteEvent(CompetitionEvent event) async {
    final count = _resultCounts[event.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppDialogTitle(
          icon: Icons.delete_outline,
          title: 'حذف المسابقة',
        ),
        content: Text(
          count == 0
              ? 'هل تريد حذف «${event.title}»؟'
              : 'هل تريد حذف «${event.title}» ونتائج $count طالب المرتبطة بها؟ لا يمكن التراجع عن الحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteCompetitionEvent(event.id);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف المسابقة ونتائجها المرتبطة')),
    );
  }

  Future<void> _open(CompetitionEvent event) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CompetitionJudgeScreen(event: event),
      ),
    );
    if (mounted) await _load();
  }
}
