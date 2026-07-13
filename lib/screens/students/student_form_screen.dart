import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../services/database_service.dart';
import '../../services/quran_service.dart';
import '../../models/student.dart';
import '../../models/settings.dart';
import '../../models/family.dart';
import '../../utils/helpers.dart';

class StudentFormScreen extends StatefulWidget {
  final Student? student;

  const StudentFormScreen({super.key, this.student});

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _planType = 'ayahs';
  int _planAmount = 5;
  String _memorizationDirection = 'desc';
  final DatabaseService _db = DatabaseService();
  bool _isSaving = false;
  HalaqahSettings _settings = HalaqahSettings();

  List<Student> _allStudents = [];
  List<Family> _families = [];
  List<Student> _suggestedSiblings = [];
  String? _familyId;
  int? _startSurahId;
  int? _startAyah;
  int? _endSurahId;
  int? _endAyah;

  bool get isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    _loadAllStudents();
    _loadSettings();
    if (widget.student != null) {
      _nameController.text = widget.student!.name;
      _phoneController.text = widget.student!.phone;
      _guardianPhoneController.text = widget.student!.guardianPhone;
      _notesController.text = widget.student!.notes ?? '';
      _familyId = widget.student!.familyId;
      _planType = widget.student!.planType;
      _planAmount = widget.student!.planAmount;
      _memorizationDirection = widget.student!.memorizationDirection;
      _startSurahId = widget.student!.preMemorizedStartSurah;
      _startAyah = widget.student!.preMemorizedStartAyah;
      _endSurahId = widget.student!.preMemorizedEndSurah;
      _endAyah = widget.student!.preMemorizedEndAyah;
    }
  }

  Future<void> _loadAllStudents() async {
    try {
      await QuranService.instance.initialize();
      final values = await Future.wait<dynamic>([
        _db.getStudents(),
        _db.getFamilies(),
      ]);
      setState(() {
        _allStudents = values[0] as List<Student>;
        _families = values[1] as List<Family>;
      });
    } catch (_) {}
  }

  Future<void> _selectFamily(String? familyId) async {
    setState(() => _familyId = familyId);
    if (familyId == null) return;
    final guardians = await _db.getFamilyGuardians(familyId);
    if (!mounted || guardians.isEmpty) return;
    final primary = guardians.firstWhere(
      (guardian) => guardian.isPrimary,
      orElse: () => guardians.first,
    );
    setState(() => _guardianPhoneController.text = primary.phone);
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _db.getSettings();
      setState(() {
        _settings = settings;
      });
    } catch (_) {}
  }

  void _checkSiblingSuggestions(String name) {
    if (isEditing) return; // Only suggest for new registrations
    final trimmed = name.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length < 2) {
      setState(() {
        _suggestedSiblings = [];
      });
      return;
    }
    
    final suffix = parts.sublist(1).join(' ').toLowerCase();
    
    // Find students whose names have a matching suffix
    final matches = _allStudents.where((student) {
      final existingName = student.name.toLowerCase();
      return existingName.contains(suffix) && 
             existingName != trimmed.toLowerCase() &&
             student.status == 'active';
    }).toList();
    
    setState(() {
      _suggestedSiblings = matches;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _guardianPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickContact(TextEditingController controller) async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('هذه الميزة مدعومة فقط على الهواتف الذكية')),
        );
        return;
      }
      
      if (await FlutterContacts.requestPermission(readonly: true)) {
        final contact = await FlutterContacts.openExternalPick();
        if (contact != null) {
          final fullContact = await FlutterContacts.getContact(contact.id);
          if (fullContact != null && fullContact.phones.isNotEmpty) {
            String phone = fullContact.phones.first.number;
            phone = phone.replaceAll(RegExp(r'\s+'), '').replaceAll('-', '');
            phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
            setState(() {
              controller.text = phone;
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('جهة الاتصال هذه لا تحتوي على أرقام هواتف')),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض صلاحية الوصول لجهات الاتصال')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في استيراد جهة الاتصال: $e')),
      );
    }
  }

  int _calculateAyahsInRange(int start, int startAyah, int end, int endAyah) {
    int totalAyahs = 0;
    if (start == end) {
      if (endAyah >= startAyah) {
        totalAyahs = endAyah - startAyah + 1;
      }
    } else if (start > end) {
      // Descending
      // Start Surah (from startAyah to totalAyahs)
      final startSurahObj = QuranService.instance.getSurah(start);
      if (startSurahObj != null) {
        final total = startSurahObj.totalAyahs;
        if (total >= startAyah) {
          totalAyahs += total - startAyah + 1;
        }
      }
      // Full Surahs in between (end + 1 to start - 1)
      for (int i = end + 1; i <= start - 1; i++) {
        final surah = QuranService.instance.getSurah(i);
        if (surah != null) {
          totalAyahs += surah.totalAyahs;
        }
      }
      // End Surah (from 1 to endAyah)
      totalAyahs += endAyah;
    } else {
      // Ascending
      // Start Surah (from startAyah to totalAyahs)
      final startSurahObj = QuranService.instance.getSurah(start);
      if (startSurahObj != null) {
        final total = startSurahObj.totalAyahs;
        if (total >= startAyah) {
          totalAyahs += total - startAyah + 1;
        }
      }
      // Full Surahs in between (start + 1 to end - 1)
      for (int i = start + 1; i <= end - 1; i++) {
        final surah = QuranService.instance.getSurah(i);
        if (surah != null) {
          totalAyahs += surah.totalAyahs;
        }
      }
      // End Surah (from 1 to endAyah)
      totalAyahs += endAyah;
    }
    return totalAyahs;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      if (isEditing) {
        int oldRangeAyahs = 0;
        if (widget.student!.preMemorizedStartSurah != null &&
            widget.student!.preMemorizedEndSurah != null &&
            widget.student!.preMemorizedEndAyah != null) {
          oldRangeAyahs = _calculateAyahsInRange(
            widget.student!.preMemorizedStartSurah!,
            widget.student!.preMemorizedStartAyah ?? 1,
            widget.student!.preMemorizedEndSurah!,
            widget.student!.preMemorizedEndAyah!,
          );
        }

        int newRangeAyahs = 0;
        bool hasRange = false;
        if (_startSurahId != null && _endSurahId != null && _endAyah != null) {
          hasRange = true;
          newRangeAyahs = _calculateAyahsInRange(
            _startSurahId!,
            _startAyah ?? 1,
            _endSurahId!,
            _endAyah!,
          );
        }

        int newTotalMemorized = widget.student!.totalMemorized - oldRangeAyahs + newRangeAyahs;
        if (newTotalMemorized < 0) newTotalMemorized = 0;

        await _db.clearPreMemorizedProgress(widget.student!.id);
        if (hasRange) {
          await _db.initializeMushafProgressForRange(
            widget.student!.id,
            _startSurahId!,
            _startAyah ?? 1,
            _endSurahId!,
            _endAyah!,
          );
        }

        final updated = widget.student!.copyWith(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          guardianPhone: _guardianPhoneController.text.trim(),
          familyId: _familyId,
          planType: _planType,
          planAmount: _planAmount,
          notes: _notesController.text.trim(),
          memorizationDirection: _memorizationDirection,
          totalMemorized: newTotalMemorized,
          preMemorizedStartSurah: _startSurahId,
          preMemorizedStartAyah: _startAyah,
          preMemorizedEndSurah: _endSurahId,
          preMemorizedEndAyah: _endAyah,
          clearPreMemorized: !hasRange,
          clearFamily: _familyId == null,
        );
        await _db.updateStudent(updated);
      } else {
        int totalAyahs = 0;
        bool hasRange = false;

        if (_startSurahId != null && _endSurahId != null && _endAyah != null) {
          hasRange = true;
          totalAyahs = _calculateAyahsInRange(
            _startSurahId!,
            _startAyah ?? 1,
            _endSurahId!,
            _endAyah!,
          );
        }

        final student = Student(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          guardianPhone: _guardianPhoneController.text.trim(),
          familyId: _familyId,
          planType: _planType,
          planAmount: _planAmount,
          notes: _notesController.text.trim(),
          memorizationDirection: _memorizationDirection,
          totalMemorized: totalAyahs,
          preMemorizedStartSurah: _startSurahId,
          preMemorizedStartAyah: _startAyah,
          preMemorizedEndSurah: _endSurahId,
          preMemorizedEndAyah: _endAyah,
        );
        await _db.insertStudent(student);

        if (hasRange) {
          await _db.initializeMushafProgressForRange(
            student.id,
            _startSurahId!,
            _startAyah ?? 1,
            _endSurahId!,
            _endAyah!,
          );
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? GenderHelper.editStudent(_settings.gender) : GenderHelper.addStudent(_settings.gender)),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '${GenderHelper.studentName(_settings.gender)} *',
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'الرجاء إدخال اسم ${GenderHelper.studentName(_settings.gender)}';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
                onChanged: (value) {
                  _checkSiblingSuggestions(value);
                },
              ),
              _buildSuggestionsList(),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: GenderHelper.studentPhone(_settings.gender),
                  prefixIcon: const Icon(Icons.phone),
                  hintText: '05xxxxxxxx',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contact_phone_outlined),
                    onPressed: () => _pickContact(_phoneController),
                    tooltip: 'استيراد من جهات الاتصال',
                  ),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _guardianPhoneController,
                decoration: InputDecoration(
                  labelText: 'رقم جوال ولي الأمر',
                  prefixIcon: const Icon(Icons.phone_android),
                  hintText: '05xxxxxxxx',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.contact_phone_outlined),
                    onPressed: () => _pickContact(_guardianPhoneController),
                    tooltip: 'استيراد من جهات الاتصال',
                  ),
                ),
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _familyId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'العائلة',
                  prefixIcon: Icon(Icons.family_restroom_outlined),
                  helperText: 'الربط الصريح أدق من الاعتماد على تشابه الاسم',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('بدون عائلة مرتبطة'),
                  ),
                  ..._families.map(
                    (family) => DropdownMenuItem(
                      value: family.id,
                      child: Text(
                        '${family.name} — ${family.displayCode}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) => _selectFamily(
                  value == null || value.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'خطة الحفظ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('نوع المقرر'),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ayahs', label: Text('آيات')),
                          ButtonSegment(value: 'lines', label: Text('أسطر')),
                          ButtonSegment(value: 'pages', label: Text('صفحات')),
                        ],
                        selected: {_planType},
                        onSelectionChanged: (set) {
                          setState(() => _planType = set.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          const Text('المقدار اليومي: '),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: _planAmount > 1
                                ? () => setState(() => _planAmount--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_planAmount',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => setState(() => _planAmount++),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          Text(_getPlanLabel(_planType)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'منهج الحفظ والتقدم',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _memorizationDirection,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'اتجاه الحفظ والتقدم',
                  prefixIcon: Icon(Icons.explore),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'desc',
                    child: Text(
                      'الناس إلى البقرة (صعودي)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'asc',
                    child: Text(
                      'البقرة إلى الناس (نزولي)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _memorizationDirection = val;
                      if (val == 'desc') {
                        _startSurahId = 114;
                        _startAyah = 1;
                        _endSurahId = 114;
                        final surah = QuranService.instance.getSurah(114);
                        _endAyah = surah?.totalAyahs ?? 6;
                      } else if (val == 'asc') {
                        _startSurahId = 1;
                        _startAyah = 1;
                        _endSurahId = 1;
                        final surah = QuranService.instance.getSurah(1);
                        _endAyah = surah?.totalAyahs ?? 7;
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              
              _buildPreMemorizedSurahSection(),
              
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات',
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'حفظ التعديلات' : GenderHelper.addStudent(_settings.gender)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_suggestedSiblings.isEmpty) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.family_restroom, color: Theme.of(context).primaryColor, size: 18),
              const SizedBox(width: 8),
              const Text(
                'عائلة مقترحة (ربط ذكي):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _suggestedSiblings.map((sibling) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    avatar: const CircleAvatar(
                      child: Icon(Icons.person, size: 14),
                    ),
                    label: Text('${GenderHelper.siblingRelation(_settings.gender)} ${sibling.name}'),
                    onPressed: () {
                      final nameParts = _nameController.text.trim().split(RegExp(r'\s+'));
                      final firstName = nameParts.isNotEmpty ? nameParts[0] : '';
                      
                      final siblingParts = sibling.name.split(RegExp(r'\s+'));
                      final siblingSuffix = siblingParts.length > 1 
                          ? siblingParts.sublist(1).join(' ') 
                          : '';
                          
                      setState(() {
                        if (firstName.isNotEmpty && siblingSuffix.isNotEmpty) {
                          _nameController.text = '$firstName $siblingSuffix';
                        }
                        _guardianPhoneController.text = sibling.guardianPhone;
                        _familyId = sibling.familyId;
                        _suggestedSiblings = [];
                      });
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم ربط ولي الأمر وتكملة الاسم بناءً على ${sibling.name}'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreMemorizedSurahSection() {
    final surahs = QuranService.instance.surahs;
    if (surahs.isEmpty) return const SizedBox.shrink();

    int surahCount = 0;
    int ayahCount = 0;
    double pageCount = 0.0;
    double lineCount = 0.0;

    if (_startSurahId != null && _endSurahId != null && _endAyah != null) {
      final start = _startSurahId!;
      final end = _endSurahId!;
      final endAyah = _endAyah!;
      final startAyah = _startAyah ?? 1;

      if (start == end) {
        surahCount = 1;
        if (endAyah >= startAyah) {
          ayahCount = endAyah - startAyah + 1;
          lineCount = QuranService.instance.calculateLines(start, startAyah, endAyah);
        }
      } else if (start > end) {
        // Descending (e.g. 114 down to 58)
        surahCount = start - end + 1;
        // Start Surah (from startAyah to totalAyahs)
        final startSurahObj = QuranService.instance.getSurah(start);
        if (startSurahObj != null) {
          final total = startSurahObj.totalAyahs;
          if (total >= startAyah) {
            ayahCount += total - startAyah + 1;
            lineCount += QuranService.instance.calculateLines(start, startAyah, total);
          }
        }
        // Full Surahs (end + 1 to start - 1)
        for (int i = end + 1; i <= start - 1; i++) {
          final surah = QuranService.instance.getSurah(i);
          if (surah != null) {
            ayahCount += surah.totalAyahs;
            lineCount += QuranService.instance.calculateLines(i, 1, surah.totalAyahs);
          }
        }
        // Partial Surah (end)
        ayahCount += endAyah;
        lineCount += QuranService.instance.calculateLines(end, 1, endAyah);
      } else {
        // Ascending (e.g. 2 up to 5)
        surahCount = end - start + 1;
        // Start Surah (from startAyah to totalAyahs)
        final startSurahObj = QuranService.instance.getSurah(start);
        if (startSurahObj != null) {
          final total = startSurahObj.totalAyahs;
          if (total >= startAyah) {
            ayahCount += total - startAyah + 1;
            lineCount += QuranService.instance.calculateLines(start, startAyah, total);
          }
        }
        // Full Surahs (start + 1 to end - 1)
        for (int i = start + 1; i <= end - 1; i++) {
          final surah = QuranService.instance.getSurah(i);
          if (surah != null) {
            ayahCount += surah.totalAyahs;
            lineCount += QuranService.instance.calculateLines(i, 1, surah.totalAyahs);
          }
        }
        // Partial Surah (end)
        ayahCount += endAyah;
        lineCount += QuranService.instance.calculateLines(end, 1, endAyah);
      }
      pageCount = lineCount / 15.0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'تحديد المحفوظ المسبق بالسور',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: _showKhatmConfirmation,
              icon: const Icon(Icons.workspace_premium, color: Colors.amber, size: 18),
              label: const Text(
                'ختم المصحف كاملًا',
                style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.amber.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<int>(
                  value: _startSurahId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'من سورة (بداية الحفظ)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.bookmark_outline),
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('بلا (لم يحفظ شيء بعد)', overflow: TextOverflow.ellipsis),
                    ),
                    ...surahs.map((s) => DropdownMenuItem<int>(
                      value: s.number,
                      child: Text('سورة ${s.name}', overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _startSurahId = val;
                      if (val == null) {
                        _startAyah = null;
                        _endSurahId = null;
                        _endAyah = null;
                      } else {
                        _startAyah = 1;
                        if (_endSurahId == null) {
                          _endSurahId = val;
                          final surah = QuranService.instance.getSurah(val);
                          _endAyah = surah?.totalAyahs ?? 1;
                        }
                      }
                    });
                  },
                ),
                if (_startSurahId != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _startAyah,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'من آية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_drop_outlined),
                    ),
                    items: _getStartAyahDropdownItems(),
                    onChanged: (val) {
                      setState(() {
                        _startAyah = val;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _endSurahId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'إلى سورة',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.bookmark),
                    ),
                    items: surahs.map((s) => DropdownMenuItem<int>(
                      value: s.number,
                      child: Text('سورة ${s.name}', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (val) {
                      setState(() {
                        _endSurahId = val;
                        if (val != null) {
                          final surah = QuranService.instance.getSurah(val);
                          _endAyah = surah?.totalAyahs ?? 1;
                        } else {
                          _endAyah = null;
                        }
                      });
                    },
                  ),
                ],
                if (_endSurahId != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _endAyah,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'إلى آية',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin_drop),
                    ),
                    items: _getEndAyahDropdownItems(),
                    onChanged: (val) {
                      setState(() {
                        _endAyah = val;
                      });
                    },
                  ),
                ],
                if (_startSurahId != null && _endSurahId != null && _endAyah != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('سور', '$surahCount'),
                        _buildStatItem('آيات', '$ayahCount'),
                        _buildStatItem('صفحات', pageCount.toStringAsFixed(1)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showKhatmConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.workspace_premium, color: Colors.amber),
              SizedBox(width: 8),
              Text('تأكيد ختم المصحف'),
            ],
          ),
          content: const Text('هل تريد تحديد أن هذا الطالب قد أتم حفظ القرآن الكريم كاملاً؟ سيتم ضبط نطاق المحفوظ تلقائيًا من سورة الفاتحة إلى سورة الناس.'),
          actions: [
            TextButton(
              child: const Text('إلغاء'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              child: const Text('تأكيد'),
              onPressed: () {
                setState(() {
                  _startSurahId = 1;
                  _startAyah = 1;
                  _endSurahId = 114;
                  _endAyah = 6;
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم ضبط المحفوظ المسبق كختم للمصحف كاملًا 🏆'),
                    backgroundColor: Colors.amber,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  List<DropdownMenuItem<int>> _getStartAyahDropdownItems() {
    if (_startSurahId == null) return [];
    final surah = QuranService.instance.getSurah(_startSurahId!);
    if (surah == null) return [];
    return List.generate(surah.totalAyahs, (i) => i + 1)
        .map((num) => DropdownMenuItem<int>(
              value: num,
              child: Text(
                num == 1 ? 'آية 1 (أول السورة)' : 'آية $num',
                overflow: TextOverflow.ellipsis,
              ),
            ))
        .toList();
  }

  List<DropdownMenuItem<int>> _getEndAyahDropdownItems() {
    if (_endSurahId == null) return [];
    final surah = QuranService.instance.getSurah(_endSurahId!);
    if (surah == null) return [];
    return List.generate(surah.totalAyahs, (i) => i + 1)
        .map((num) => DropdownMenuItem<int>(
              value: num,
              child: Text('آية $num', overflow: TextOverflow.ellipsis),
            ))
        .toList();
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.blue.shade600,
          ),
        ),
      ],
    );
  }

  String _getPlanLabel(String type) {
    switch (type) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      default:
        return '';
    }
  }
}
