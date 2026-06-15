import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/database_service.dart';
import '../../services/backup_service.dart';
import '../../models/settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final BackupService _backup = BackupService();
  HalaqahSettings _settings = HalaqahSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final settings = await _db.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    await _db.saveSettings(_settings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ الإعدادات')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHalaqahSection(),
                const SizedBox(height: 16),
                _buildTimingSection(),
                const SizedBox(height: 16),
                _buildRulesSection(),
                const SizedBox(height: 16),
                _buildDisplaySection(),
                const SizedBox(height: 16),
                _buildDataSection(),
                const SizedBox(height: 24),
                _buildAboutSection(),
              ],
            ),
    );
  }

  Widget _buildHalaqahSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات الحلقة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _settings.halaqahName,
              decoration: const InputDecoration(
                labelText: 'اسم الحلقة',
                prefixIcon: Icon(Icons.mosque),
              ),
              onChanged: (value) {
                _settings = _settings.copyWith(halaqahName: value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _settings.mosqueName,
              decoration: const InputDecoration(
                labelText: 'اسم المسجد',
                prefixIcon: Icon(Icons.location_on),
              ),
              onChanged: (value) {
                _settings = _settings.copyWith(mosqueName: value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _settings.teacherName,
              decoration: const InputDecoration(
                labelText: 'اسم المعلم',
                prefixIcon: Icon(Icons.person),
              ),
              onChanged: (value) {
                _settings = _settings.copyWith(teacherName: value);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _settings.teacherPhone,
              decoration: const InputDecoration(
                labelText: 'رقم جوال المعلم',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              onChanged: (value) {
                _settings = _settings.copyWith(teacherPhone: value);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
                child: const Text('حفظ'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أوقات الحلقة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _settings.normalStartTime,
                    decoration: const InputDecoration(
                      labelText: 'وقت البدء',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    onChanged: (value) {
                      _settings = _settings.copyWith(normalStartTime: value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _settings.normalEndTime,
                    decoration: const InputDecoration(
                      labelText: 'وقت الانتهاء',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                    onChanged: (value) {
                      _settings = _settings.copyWith(normalEndTime: value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('وضع رمضان'),
              subtitle: const Text('تفعيل أوقات رمضان الخاصة'),
              value: _settings.isRamadanMode,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(isRamadanMode: value);
                });
                _saveSettings();
              },
            ),
            if (_settings.isRamadanMode) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: _settings.ramadanStartTime,
                      decoration: const InputDecoration(
                        labelText: 'بدء رمضان',
                        prefixIcon: Icon(Icons.nightlight),
                      ),
                      onChanged: (value) {
                        _settings = _settings.copyWith(ramadanStartTime: value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _settings.ramadanEndTime,
                      decoration: const InputDecoration(
                        labelText: 'انتهاء رمضان',
                        prefixIcon: Icon(Icons.nightlight),
                      ),
                      onChanged: (value) {
                        _settings = _settings.copyWith(ramadanEndTime: value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRulesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'قواعد الحلقة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('أيام التحذير من الغياب'),
              subtitle: Text('${_settings.absenceDaysBeforeWarning} أيام'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _settings.absenceDaysBeforeWarning > 1
                        ? () {
                            setState(() {
                              _settings = _settings.copyWith(
                                absenceDaysBeforeWarning:
                                    _settings.absenceDaysBeforeWarning - 1,
                              );
                            });
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _settings = _settings.copyWith(
                          absenceDaysBeforeWarning:
                              _settings.absenceDaysBeforeWarning + 1,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('أيام الفصل التلقائي'),
              subtitle: Text('${_settings.absenceDaysBeforeExpulsion} أيام'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _settings.absenceDaysBeforeExpulsion > 1
                        ? () {
                            setState(() {
                              _settings = _settings.copyWith(
                                absenceDaysBeforeExpulsion:
                                    _settings.absenceDaysBeforeExpulsion - 1,
                              );
                            });
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        _settings = _settings.copyWith(
                          absenceDaysBeforeExpulsion:
                              _settings.absenceDaysBeforeExpulsion + 1,
                        );
                      });
                    },
                  ),
                ],
              ),
            ),
            SwitchListTile(
              title: const Text('الفصل التلقائي'),
              subtitle: const Text('فصل الطالب تلقائياً عند تجاوز أيام الغياب'),
              value: _settings.autoExpulsionEnabled,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(autoExpulsionEnabled: value);
                });
                _saveSettings();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'العرض',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('التقويم الهجري'),
              subtitle: const Text('عرض التواريخ بالتقويم الهجري'),
              value: _settings.useHijriCalendar,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(useHijriCalendar: value);
                });
                _saveSettings();
              },
            ),
            ListTile(
              title: const Text('ترتيب المراجعة'),
              subtitle: Text(
                _settings.revisionOrder == 'ascending' ? 'تصاعدي' : 'تنازلي',
              ),
              trailing: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'ascending', label: Text('تصاعدي')),
                  ButtonSegment(value: 'descending', label: Text('تنازلي')),
                ],
                selected: {_settings.revisionOrder},
                onSelectionChanged: (set) {
                  setState(() {
                    _settings = _settings.copyWith(revisionOrder: set.first);
                  });
                  _saveSettings();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'البيانات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('نسخ احتياطي'),
              subtitle: const Text('تصدير البيانات'),
              onTap: () => _performBackup(),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('استعادة'),
              subtitle: const Text('استيراد البيانات'),
              onTap: () => _performRestore(),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('مزامنة'),
              subtitle: const Text('مزامنة عبر WiFi/Bluetooth'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('ستتوفر هذه الميزة في التحديث القادم')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.auto_stories, size: 48, color: Colors.teal),
            const SizedBox(height: 8),
            const Text(
              'حلقتي',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('الإصدار 1.0.0'),
            const SizedBox(height: 8),
            Text(
              'تطبيق لإدارة الحلقات القرآنية',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBackup() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      final filePath = await _backup.exportBackup();
      
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تم النسخ الاحتياطي'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تم حفظ النسخة الاحتياطية بنجاح'),
                const SizedBox(height: 8),
                Text(
                  'المسار: $filePath',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في النسخ الاحتياطي: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _performRestore() async {
    try {
      final files = await _backup.getBackupFiles();
      
      if (files.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا يوجد نسخ احتياطية محفوظة')),
          );
        }
        return;
      }
      
      if (!mounted) return;
      
      final selectedFile = await showDialog<File>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اختر نسخة احتياطية'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: files.length,
              itemBuilder: (context, index) {
                final file = files[index] as File;
                final fileName = file.path.split('/').last.split('\\').last;
                return ListTile(
                  leading: const Icon(Icons.backup),
                  title: Text(fileName),
                  onTap: () => Navigator.pop(context, file),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );
      
      if (selectedFile == null) return;
      
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('تأكيد الاستعادة'),
          content: const Text('سيتم استبدال البيانات الحالية. هل أنت متأكد؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator()),
        );
      }
      
      final success = await _backup.importBackup(selectedFile.path);
      
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'تم استعادة البيانات بنجاح' : 'فشل في استعادة البيانات'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
