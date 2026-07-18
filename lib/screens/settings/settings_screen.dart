import 'package:flutter/material.dart';
import 'dart:io';
import '../../services/database_service.dart';
import '../../services/backup_service.dart';
import '../../services/backup_crypto_service.dart';
import '../../services/cloud_backup_service.dart';
import '../../services/cloud_connection_diagnostics.dart';
import '../../services/audit_log_service.dart';
import '../../services/supabase_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/settings.dart';
import '../../app/app.dart';
import '../../app/build_info.dart';
import '../../utils/prayer_time_helper.dart';
import 'message_templates_screen.dart';
import 'whats_new_screen.dart';
import 'privacy_policy_screen.dart';
import 'audit_log_screen.dart';
import 'diagnostics_screen.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const SettingsScreen({super.key, this.onOpenMenu});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DatabaseService _db = DatabaseService();
  final BackupService _backup = BackupService();
  HalaqahSettings _settings = HalaqahSettings();
  bool _isLoading = true;
  String _selectedSection = 'halaqah';
  DateTime? _lastBackupAt;
  String? _lastAutomaticBackupError;
  int _savedBackupCount = 0;
  bool _isPassphraseConfigured = false;
  bool _dataActionBusy = false;
  bool _checkingCloudConnection = false;
  CloudConnectionDiagnostic? _cloudConnectionDiagnostic;
  DateTime? _lastCloudUploadAt;
  DateTime? _lastCloudDownloadAt;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.getSettings(),
        _db.getSetting('last_backup_at'),
        _db.getSetting('last_automatic_backup_error'),
        _backup.getBackupFiles(),
        _backup.passphrases.isConfigured,
        _db.getSetting('last_cloud_upload_at'),
        _db.getSetting('last_cloud_download_at'),
      ]);
      final settings = results[0] as HalaqahSettings;
      setState(() {
        _settings = settings;
        _lastBackupAt = DateTime.tryParse((results[1] as String?) ?? '');
        _lastAutomaticBackupError = (results[2] as String?)?.trim();
        _savedBackupCount = (results[3] as List).length;
        _isPassphraseConfigured = results[4] as bool;
        _lastCloudUploadAt = DateTime.tryParse((results[5] as String?) ?? '');
        _lastCloudDownloadAt =
            DateTime.tryParse((results[6] as String?) ?? '');
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

  Future<void> _selectTime(bool isStart, {bool isRamadan = false}) async {
    final initialTimeStr = isRamadan
        ? (isStart ? _settings.ramadanStartTime : _settings.ramadanEndTime)
        : (isStart ? _settings.normalStartTime : _settings.normalEndTime);
    
    final parts = initialTimeStr.split(':');
    final initialTime = TimeOfDay(
      hour: parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 16) : 16,
      minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0,
    );
    
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      final formattedTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isRamadan) {
          if (isStart) {
            _settings = _settings.copyWith(ramadanStartTime: formattedTime);
          } else {
            _settings = _settings.copyWith(ramadanEndTime: formattedTime);
          }
        } else {
          if (isStart) {
            _settings = _settings.copyWith(normalStartTime: formattedTime);
          } else {
            _settings = _settings.copyWith(normalEndTime: formattedTime);
          }
        }
      });
      await _saveSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.menu),
                tooltip: 'القائمة الرئيسية',
              ),
        title: const Text('الإعدادات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
            tooltip: 'حفظ الإعدادات',
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSettingsNavigation(),
                  const SizedBox(height: 16),
                  _buildSelectedSection(),
                ],
              ),
      ),
    );
  }

  Widget _buildSettingsNavigation() {
    const sections = <(String, String, IconData)>[
      ('halaqah', 'الحلقة', Icons.mosque_outlined),
      ('timing', 'الأوقات', Icons.schedule_outlined),
      ('rules', 'القواعد', Icons.rule_outlined),
      ('display', 'المظهر', Icons.palette_outlined),
      ('data', 'البيانات', Icons.shield_outlined),
      ('diagnostics', 'التشخيص', Icons.health_and_safety_outlined),
      ('about', 'حول', Icons.info_outline),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أقسام الإعدادات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sections.map((section) {
                return ChoiceChip(
                  selected: _selectedSection == section.$1,
                  avatar: Icon(section.$3, size: 18),
                  label: Text(section.$2),
                  onSelected: (_) {
                    setState(() => _selectedSection = section.$1);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedSection() {
    switch (_selectedSection) {
      case 'timing':
        return _buildTimingSection();
      case 'rules':
        return _buildRulesSection();
      case 'display':
        return _buildDisplaySection();
      case 'data':
        return _buildDataSection();
      case 'diagnostics':
        return _buildDiagnosticsSection();
      case 'about':
        return _buildAboutSection();
      default:
        return _buildHalaqahSection();
    }
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
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _settings.currencySymbol,
              decoration: const InputDecoration(
                labelText: 'رمز العملة للصندوق المالي',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              onChanged: (value) {
                _settings = _settings.copyWith(currencySymbol: value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _settings.gender,
              decoration: const InputDecoration(
                labelText: 'جنس الحلقة',
                prefixIcon: Icon(Icons.people_outline),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'male', child: Text('طلاب (بنين)')),
                DropdownMenuItem(value: 'female', child: Text('طالبات (بنات)')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _settings = _settings.copyWith(gender: val);
                  });
                  _saveSettings();
                }
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
    final countryCities = PrayerTimeHelper.countriesData[_settings.country] ?? {};
    final cities = countryCities.keys.toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أوقات الحلقة وجدولة الصلوات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 16),
            
            // Timing Type Selection
            Text(
              'نوع جدولة الوقت:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Theme.of(context).primaryColor.withOpacity(0.15),
                  selectedForegroundColor: Theme.of(context).primaryColor,
                ),
                segments: [
                  ButtonSegment(
                    value: 'fixed',
                    label: Text('وقت ثابت', style: TextStyle(fontSize: 13)),
                    icon: const Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment(
                    value: 'relative',
                    label: Text('مرتبط بالصلوات', style: TextStyle(fontSize: 13)),
                    icon: const Icon(Icons.access_time_filled_outlined),
                  ),
                ],
                selected: {_settings.timingType},
                onSelectionChanged: (set) {
                  setState(() {
                    _settings = _settings.copyWith(timingType: set.first);
                  });
                  _saveSettings();
                },
              ),
            ),
            const SizedBox(height: 20),

            if (_settings.timingType == 'fixed') ...[
              // Fixed timing fields
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true),
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'وقت البدء',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _settings.normalStartTime,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false),
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'وقت الانتهاء',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _settings.normalEndTime,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Relative timing options
              // 1. Country Selection
              DropdownButtonFormField<String>(
                value: _settings.country,
                decoration: const InputDecoration(
                  labelText: 'الدولة',
                  prefixIcon: Icon(Icons.public),
                  border: OutlineInputBorder(),
                ),
                items: PrayerTimeHelper.getSupportedCountries().entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final newCountryCities = PrayerTimeHelper.countriesData[val] ?? {};
                    final defaultCity = newCountryCities.keys.isNotEmpty ? newCountryCities.keys.first : 'custom';
                    setState(() {
                      _settings = _settings.copyWith(
                        country: val,
                        city: defaultCity,
                        customLatitude: null,
                        customLongitude: null,
                      );
                    });
                    _saveSettings();
                  }
                },
              ),
              const SizedBox(height: 16),

              // 2. City Selection
              DropdownButtonFormField<String>(
                value: cities.contains(_settings.city) ? _settings.city : 'custom',
                decoration: const InputDecoration(
                  labelText: 'المدينة',
                  prefixIcon: Icon(Icons.location_city),
                  border: OutlineInputBorder(),
                ),
                items: [
                  ...cities.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                  DropdownMenuItem(value: 'custom', child: Text('موقع مخصص (إدخال يدوي)')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      if (val == 'custom') {
                        _settings = _settings.copyWith(
                          city: 'custom',
                          customLatitude: _settings.customLatitude ?? 15.3694,
                          customLongitude: _settings.customLongitude ?? 44.1910,
                        );
                      } else {
                        _settings = _settings.copyWith(
                          city: val,
                          customLatitude: null,
                          customLongitude: null,
                        );
                      }
                    });
                    _saveSettings();
                  }
                },
              ),
              const SizedBox(height: 16),

              // 3. Custom Coordinates (if selected custom)
              if (_settings.city == 'custom') ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _settings.customLatitude?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'خط العرض (Latitude)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) {
                            _settings = _settings.copyWith(customLatitude: parsed);
                            _saveSettings();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        initialValue: _settings.customLongitude?.toString() ?? '',
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'خط الطول (Longitude)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = double.tryParse(val);
                          if (parsed != null) {
                            _settings = _settings.copyWith(customLongitude: parsed);
                            _saveSettings();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // 4. Calculation Method Selection
              DropdownButtonFormField<String>(
                value: _settings.calculationMethod,
                decoration: const InputDecoration(
                  labelText: 'طريقة الحساب الفلكية',
                  prefixIcon: Icon(Icons.calculate_outlined),
                  border: OutlineInputBorder(),
                ),
                items: PrayerTimeHelper.getCalculationMethods().entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _settings = _settings.copyWith(calculationMethod: val);
                    });
                    _saveSettings();
                  }
                },
              ),
              const SizedBox(height: 16),

              // 5. Reference Prayer Selection
              DropdownButtonFormField<String>(
                value: _settings.relativeStartPrayer,
                decoration: const InputDecoration(
                  labelText: 'صلاة البداية المرجعية',
                  prefixIcon: Icon(Icons.church_outlined),
                  border: OutlineInputBorder(),
                ),
                items: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map((p) {
                  return DropdownMenuItem(value: p, child: Text(PrayerTimeHelper.getPrayerLabel(p)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _settings = _settings.copyWith(relativeStartPrayer: val);
                    });
                    _saveSettings();
                  }
                },
              ),
              const SizedBox(height: 16),

              // 6. Relative Offset slider
              Text(
                'إزاحة وقت البدء بالنسبة للصلاة: ' +
                    (_settings.relativeStartOffset >= 0 ? '+' : '') +
                    '${_settings.relativeStartOffset} دقيقة' +
                    ' (${_settings.relativeStartOffset >= 0 ? 'بعد الصلاة' : 'قبل الصلاة'})',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _settings.relativeStartOffset.toDouble(),
                min: -90,
                max: 120,
                divisions: 42,
                label: '${_settings.relativeStartOffset} د',
                onChanged: (val) {
                  setState(() {
                    _settings = _settings.copyWith(relativeStartOffset: val.toInt());
                  });
                },
                onChangeEnd: (val) {
                  _saveSettings();
                },
              ),
              const SizedBox(height: 8),

              // 7. Class Duration
              Text(
                'مدة الحلقة: ${_settings.classDurationMinutes} دقيقة (${(_settings.classDurationMinutes / 60).toStringAsFixed(1)} ساعة)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _settings.classDurationMinutes.toDouble(),
                min: 30,
                max: 240,
                divisions: 14,
                label: '${_settings.classDurationMinutes} د',
                onChanged: (val) {
                  setState(() {
                    _settings = _settings.copyWith(classDurationMinutes: val.toInt());
                  });
                },
                onChangeEnd: (val) {
                  _saveSettings();
                },
              ),
            ],

            const Divider(height: 32),

            // Ramadan Timing options header
            Row(
              children: [
                Icon(Icons.nightlight_outlined, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'توقيت شهر رمضان المبارك',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange[700]),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Force Ramadan Mode manually
            SwitchListTile(
              title: const Text('وضع رمضان النشط حالياً'),
              subtitle: const Text('تفعيل أوقات رمضان الخاصة يدوياً (أو سيتعرف التطبيق عليها تلقائياً هجرياً)'),
              value: _settings.isRamadanMode,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(isRamadanMode: value);
                });
                _saveSettings();
              },
            ),

            const SizedBox(height: 8),
            Text(
              'نوع توقيت حلقة رمضان:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _settings.ramadanTimingType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'same', child: Text('نفس التوقيت المعتاد (العادي)', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 'fixed', child: Text('ساعات ثابتة مخصصة لرمضان', style: TextStyle(fontSize: 14))),
                DropdownMenuItem(value: 'relative', child: Text('مرتبط بالصلوات لرمضان', style: TextStyle(fontSize: 14))),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _settings = _settings.copyWith(ramadanTimingType: val);
                  });
                  _saveSettings();
                }
              },
            ),
            const SizedBox(height: 16),

            if (_settings.ramadanTimingType == 'fixed') ...[
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(true, isRamadan: true),
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'بدء رمضان',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _settings.ramadanStartTime,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectTime(false, isRamadan: true),
                      borderRadius: BorderRadius.circular(8),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'انتهاء رمضان',
                          prefixIcon: Icon(Icons.access_time),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          _settings.ramadanEndTime,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_settings.ramadanTimingType == 'relative') ...[
              // Reference prayer in Ramadan
              DropdownButtonFormField<String>(
                value: _settings.ramadanRelativeStartPrayer,
                decoration: const InputDecoration(
                  labelText: 'صلاة البدء في رمضان',
                  prefixIcon: Icon(Icons.church_outlined),
                  border: OutlineInputBorder(),
                ),
                items: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map((p) {
                  return DropdownMenuItem(value: p, child: Text(PrayerTimeHelper.getPrayerLabel(p)));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _settings = _settings.copyWith(ramadanRelativeStartPrayer: val);
                    });
                    _saveSettings();
                  }
                },
              ),
              const SizedBox(height: 16),

              // Relative offset in Ramadan
              Text(
                'إزاحة وقت البدء في رمضان: ' +
                    (_settings.ramadanRelativeStartOffset >= 0 ? '+' : '') +
                    '${_settings.ramadanRelativeStartOffset} دقيقة' +
                    ' (${_settings.ramadanRelativeStartOffset >= 0 ? 'بعد الصلاة' : 'قبل الصلاة'})',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _settings.ramadanRelativeStartOffset.toDouble(),
                min: -90,
                max: 120,
                divisions: 42,
                label: '${_settings.ramadanRelativeStartOffset} د',
                onChanged: (val) {
                  setState(() {
                    _settings = _settings.copyWith(ramadanRelativeStartOffset: val.toInt());
                  });
                },
                onChangeEnd: (val) {
                  _saveSettings();
                },
              ),
              const SizedBox(height: 8),

              // Class duration in Ramadan
              Text(
                'مدة حلقة رمضان: ${_settings.ramadanClassDurationMinutes} دقيقة (${(_settings.ramadanClassDurationMinutes / 60).toStringAsFixed(1)} ساعة)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _settings.ramadanClassDurationMinutes.toDouble(),
                min: 30,
                max: 240,
                divisions: 14,
                label: '${_settings.ramadanClassDurationMinutes} د',
                onChanged: (val) {
                  setState(() {
                    _settings = _settings.copyWith(ramadanClassDurationMinutes: val.toInt());
                  });
                },
                onChangeEnd: (val) {
                  _saveSettings();
                },
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
                            _saveSettings();
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
                      _saveSettings();
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
                            _saveSettings();
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
                      _saveSettings();
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
            const Divider(),
            ListTile(
              leading: const Icon(Icons.stars_outlined, color: Colors.amber),
              title: const Text('قواعد النقاط والسلوك المخصصة'),
              subtitle: const Text('إضافة وتعديل وحذف بنود النقاط والمكافآت المخصصة'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showCustomPointsConfigDialog,
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
              'العرض والمظهر',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.palette_outlined),
              title: Text('المظهر'),
              subtitle: Text('يمكن اتباع إعداد الجهاز أو اختيار وضع ثابت'),
            ),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'system',
                    label: Text('الجهاز'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                  ButtonSegment(value: 'light', label: Text('فاتح')),
                  ButtonSegment(value: 'dark', label: Text('داكن')),
                ],
                selected: {_settings.theme},
                onSelectionChanged: (selection) async {
                  final selectedTheme = selection.first;
                  setState(() {
                    _settings = _settings.copyWith(theme: selectedTheme);
                  });
                  themeNotifier.value = themeModeFromSetting(selectedTheme);
                  await _saveSettings();
                },
              ),
            ),
            const Divider(height: 24),
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
            const Divider(height: 24),
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
            const Divider(height: 24),
            ListTile(
              title: const Text('تنسيق الوقت'),
              subtitle: Text(
                _settings.timeFormat == '12h'
                    ? '12 ساعة (ص/م)'
                    : _settings.timeFormat == '24h'
                        ? '24 ساعة'
                        : 'تلقائي مع الجوال',
              ),
              trailing: DropdownButton<String>(
                value: _settings.timeFormat,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: '12h', child: Text('12 ساعة')),
                  DropdownMenuItem(value: '24h', child: Text('24 ساعة')),
                  DropdownMenuItem(value: 'device', child: Text('تلقائي مع الجوال')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _settings = _settings.copyWith(timeFormat: val);
                    });
                    _saveSettings();
                  }
                },
              ),
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.message_outlined, color: Colors.teal),
              title: const Text('قوالب رسائل أولياء الأمور'),
              subtitle: const Text('تخصيص نصوص رسائل الواجبات والتقييمات للوالدين'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MessageTemplatesScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataSection() {
    final supabase = SupabaseService.instance;
    final lastBackupText = _lastBackupAt == null
        ? 'لم تُنشأ نسخة احتياطية بعد'
        : 'آخر نسخة: ${_formatBackupDate(_lastBackupAt!)}';
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _lastBackupAt == null
                        ? Icons.warning_amber_rounded
                        : Icons.verified_user_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lastBackupText,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('النسخ المحلية المحفوظة: $_savedBackupCount'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_lastAutomaticBackupError?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                'تعذر آخر نسخ تلقائي. افتح هذا القسم وأنشئ نسخة يدوية للتحقق من مساحة الجهاز.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const Divider(height: 28),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isPassphraseConfigured
                    ? Colors.green.withOpacity(0.09)
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPassphraseConfigured
                        ? Icons.lock_outline
                        : Icons.lock_open_outlined,
                    color: _isPassphraseConfigured
                        ? Colors.green
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPassphraseConfigured
                              ? 'تشفير النسخ الاحتياطية مفعّل'
                              : 'يلزم إعداد عبارة حماية',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          'احفظ العبارة خارج الجهاز؛ لا يمكن فك النسخة بدونها.',
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _dataActionBusy ? null : _configureBackupPassphrase,
                    child: Text(
                      _isPassphraseConfigured ? 'تغيير' : 'إعداد',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: const Text('إنشاء نسخة الآن'),
              subtitle: const Text('إنشاء ملف مشفر ومتحقق من سلامته'),
              onTap: _dataActionBusy ? null : _performBackup,
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('استعادة'),
              subtitle: const Text('استعادة إحدى النسخ المحلية المحفوظة'),
              onTap: _dataActionBusy ? null : _performRestore,
            ),
            const Divider(height: 28),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.schedule_send_outlined),
              title: const Text('النسخ المحلي التلقائي'),
              subtitle: Text(
                'ينفذ عند أول فتح للتطبيق بعد الساعة ${_formatHour(_settings.automaticBackupHour)}',
              ),
              value: _settings.automaticBackupEnabled,
              onChanged: (value) async {
                if (value && !await _ensurePassphraseConfigured()) return;
                setState(() {
                  _settings = _settings.copyWith(
                    automaticBackupEnabled: value,
                  );
                });
                await _saveSettings();
              },
            ),
            if (_settings.automaticBackupEnabled) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('وقت النسخ التلقائي'),
                subtitle: const Text('يُطبق عند فتح التطبيق، ولا يحتاج بقاءه مفتوحًا عند الوقت نفسه'),
                trailing: Text(
                  _formatHour(_settings.automaticBackupHour),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: _selectAutomaticBackupHour,
              ),
              DropdownButtonFormField<int>(
                value: const [7, 14, 30]
                        .contains(_settings.automaticBackupRetentionCount)
                    ? _settings.automaticBackupRetentionCount
                    : 14,
                decoration: const InputDecoration(
                  labelText: 'عدد النسخ التلقائية المحتفظ بها',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                items: const [7, 14, 30]
                    .map((count) => DropdownMenuItem(
                          value: count,
                          child: Text('$count نسخة'),
                        ))
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    _settings = _settings.copyWith(
                      automaticBackupRetentionCount: value,
                    );
                  });
                  await _saveSettings();
                },
              ),
            ],
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('تذكير سلامة البيانات'),
              subtitle: const Text('تنبيه دوري إذا لم تُنشأ نسخة خلال المدة المحددة'),
              value: _settings.backupReminderEnabled,
              onChanged: (value) async {
                setState(() {
                  _settings = _settings.copyWith(
                    backupReminderEnabled: value,
                  );
                });
                await _saveSettings();
              },
            ),
            if (_settings.backupReminderEnabled)
              DropdownButtonFormField<int>(
                value: const [1, 3, 7]
                        .contains(_settings.backupReminderIntervalDays)
                    ? _settings.backupReminderIntervalDays
                    : 3,
                decoration: const InputDecoration(
                  labelText: 'فترة التذكير',
                  prefixIcon: Icon(Icons.date_range_outlined),
                ),
                items: const [1, 3, 7]
                    .map((days) => DropdownMenuItem(
                          value: days,
                          child: Text(days == 1 ? 'يوميًا' : 'كل $days أيام'),
                        ))
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    _settings = _settings.copyWith(
                      backupReminderIntervalDays: value,
                    );
                  });
                  await _saveSettings();
                },
              ),
            const Divider(height: 28),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.cloud_sync_outlined),
              title: const Text('نسخة سحابية تلقائية مشفرة'),
              subtitle: Text(
                supabase.isAuthenticated
                    ? 'ترفع النسخة التلقائية إلى مساحة خاصة بالحساب'
                    : 'يلزم تسجيل الدخول لتفعيلها',
              ),
              value: _settings.cloudBackupEnabled,
              onChanged: !supabase.isAuthenticated
                  ? null
                  : (value) async {
                      if (value && !await _ensurePassphraseConfigured()) return;
                      setState(() {
                        _settings = _settings.copyWith(
                          cloudBackupEnabled: value,
                        );
                      });
                      await _saveSettings();
                    },
            ),
            if (supabase.isAuthenticated) ...[
              DropdownButtonFormField<int>(
                value: const [10, 30, 60]
                        .contains(_settings.cloudBackupRetentionCount)
                    ? _settings.cloudBackupRetentionCount
                    : 30,
                decoration: const InputDecoration(
                  labelText: 'عدد النسخ السحابية المحتفظ بها',
                  prefixIcon: Icon(Icons.cloud_queue_outlined),
                ),
                items: const [10, 30, 60]
                    .map(
                      (count) => DropdownMenuItem(
                        value: count,
                        child: Text('$count نسخة'),
                      ),
                    )
                    .toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  setState(() {
                    _settings = _settings.copyWith(
                      cloudBackupRetentionCount: value,
                    );
                  });
                  await _saveSettings();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('رفع نسخة مشفرة الآن'),
                subtitle: const Text('لا يُرفع أي ملف غير مشفر'),
                onTap: _dataActionBusy ? null : _performCloudBackup,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('استعادة من السحابة'),
                subtitle: const Text('تنزيل النسخة ثم التحقق منها قبل الاستعادة'),
                onTap: _dataActionBusy ? null : _performCloudRestore,
              ),
            ],
            const Divider(height: 28),
            DropdownButtonFormField<int>(
              value: const [365, 730, 1825]
                      .contains(_settings.auditLogRetentionDays)
                  ? _settings.auditLogRetentionDays
                  : 730,
              decoration: const InputDecoration(
                labelText: 'مدة الاحتفاظ بسجل التدقيق',
                prefixIcon: Icon(Icons.history_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 365, child: Text('سنة واحدة')),
                DropdownMenuItem(value: 730, child: Text('سنتان')),
                DropdownMenuItem(value: 1825, child: Text('خمس سنوات')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                setState(() {
                  _settings = _settings.copyWith(
                    auditLogRetentionDays: value,
                  );
                });
                await _saveSettings();
                await AuditLogService().prune(retentionDays: value);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined),
              title: const Text('سجل التدقيق'),
              subtitle: const Text('مراجعة النسخ والاستعادة والتغييرات الحساسة'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuditLogScreen()),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('سياسة الخصوصية وإدارة البيانات'),
              subtitle: const Text('ما يُجمع، ولماذا، وكيف يُحتفظ به ويُحذف'),
              onTap: () => _openPrivacyPolicy(),
            ),
            const Divider(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _checkingCloudConnection
                  ? const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _cloudConnectionDiagnostic?.isHealthy == true
                          ? Icons.cloud_done_outlined
                          : Icons.network_check_outlined,
                      color: _cloudConnectionDiagnostic?.isHealthy == true
                          ? Colors.green
                          : null,
                    ),
              title: const Text('فحص اتصال Supabase'),
              subtitle: Text(
                _cloudConnectionDiagnostic?.message ??
                    'يفحص DNS والاتصال المشفر دون رفع أو تنزيل بيانات',
              ),
              trailing: const Icon(Icons.chevron_left),
              onTap: _checkingCloudConnection
                  ? null
                  : _performCloudConnectionCheck,
            ),
            const Divider(height: 28),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                supabase.isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                color: supabase.isAuthenticated ? Colors.green : null,
              ),
              title: const Text('المزامنة السحابية'),
              subtitle: Text(
                supabase.isAuthenticated
                    ? 'متصل بالحساب ${supabase.currentUserEmail ?? ''}'
                    : 'غير متصل؛ يمكن ربط الحساب من زر السحابة في الشاشة الرئيسية',
              ),
            ),
            if (supabase.isAuthenticated) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_upload_outlined),
                title: const Text('رفع تغييرات الجهاز'),
                subtitle: Text(
                  _lastCloudUploadAt == null
                      ? 'الجهاز ← السحابة فقط'
                      : 'الجهاز ← السحابة فقط\nآخر رفع: ${_formatBackupDate(_lastCloudUploadAt!)}',
                ),
                onTap: _dataActionBusy
                    ? null
                    : () => _performDirectionalSync(
                          CloudSyncDirection.uploadOnly,
                        ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('تنزيل بيانات السحابة'),
                subtitle: Text(
                  _lastCloudDownloadAt == null
                      ? 'السحابة ← الجهاز فقط، مع نسخة حماية أولًا'
                      : 'السحابة ← الجهاز فقط\nآخر تنزيل: ${_formatBackupDate(_lastCloudDownloadAt!)}',
                ),
                onTap: _dataActionBusy
                    ? null
                    : () => _performDirectionalSync(
                          CloudSyncDirection.downloadOnly,
                        ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.sync),
                title: const Text('مزامنة ذكية ثنائية الاتجاه'),
                subtitle: const Text(
                  'ترفع تغييرات الجهاز أولًا، ثم تنزّل البيانات التشغيلية',
                ),
                onTap: _dataActionBusy
                    ? null
                    : () => _performDirectionalSync(
                          CloudSyncDirection.bidirectional,
                        ),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'تسجيل الخروج من السحابة',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                ),
                subtitle: Text('الحساب الحالي: ${supabase.currentUserEmail}'),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تسجيل الخروج'),
                      content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج وإلغاء ربط الحساب السحابي؟'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('إلغاء'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('تسجيل خروج', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await supabase.signOut();
                    setState(() {});
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تسجيل الخروج بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatHour(int hour) =>
      '${hour.clamp(0, 23).toInt().toString().padLeft(2, '0')}:00';

  Future<void> _performCloudConnectionCheck() async {
    setState(() => _checkingCloudConnection = true);
    final result = await SupabaseService.instance.diagnoseConnection();
    if (!mounted) return;
    setState(() {
      _checkingCloudConnection = false;
      _cloudConnectionDiagnostic = result;
    });

    final color = result.isHealthy
        ? Colors.green
        : Theme.of(context).colorScheme.error;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          result.isHealthy
              ? Icons.cloud_done_outlined
              : Icons.cloud_off_outlined,
          color: color,
          size: 36,
        ),
        title: Text(result.title, textAlign: TextAlign.center),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(result.message),
              const SizedBox(height: 12),
              Text('النطاق: ${result.host}'),
              Text('زمن الفحص: ${result.elapsed.inMilliseconds} ms'),
              if (result.httpStatus != null)
                Text('HTTP: ${result.httpStatus}'),
              const SizedBox(height: 12),
              ...result.recommendations.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(item)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('تم'),
          ),
        ],
      ),
    );
  }

  String _formatBackupDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year}، $hour:$minute';
  }

  Future<void> _selectAutomaticBackupHour() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _settings.automaticBackupHour.clamp(0, 23).toInt(),
        minute: 0,
      ),
    );
    if (picked == null) return;
    setState(() {
      _settings = _settings.copyWith(automaticBackupHour: picked.hour);
    });
    await _saveSettings();
  }

  Widget _buildDiagnosticsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.health_and_safety_outlined, color: Colors.teal),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مركز التشخيص والدعم',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'يفحص نسخة التطبيق وSQLite والنسخ الاحتياطية والمزامنة واتصال Supabase والحوادث البرمجية المنقحة.',
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'لا يضم تقرير الدعم أسماء الطلاب أو الهواتف أو الملاحظات أو كلمات المرور أو رموز الجلسات.',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DiagnosticsScreen(),
                  ),
                ),
                icon: const Icon(Icons.monitor_heart_outlined),
                label: const Text('فتح مركز التشخيص'),
              ),
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
            const Text('الإصدار ${AppBuildInfo.displayVersion}'),
            const SizedBox(height: 8),
            Text(
              'تطبيق لإدارة الحلقات القرآنية',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.withOpacity(0.1),
                foregroundColor: Colors.teal,
                elevation: 0,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const WhatsNewScreen()),
                );
              },
              icon: const Icon(Icons.new_releases_outlined),
              label: const Text('ما الجديد في هذا التحديث؟'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBackup() async {
    if (!await _ensurePassphraseConfigured()) return;
    var progressOpen = false;
    try {
      setState(() => _dataActionBusy = true);
      progressOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final filePath = await _backup.exportBackup();
      await _refreshBackupStatus();

      if (mounted && progressOpen) {
        Navigator.pop(context);
        progressOpen = false;
      }

      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تم إنشاء نسخة مشفرة'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تم تشفير النسخة والتحقق من سلامتها. ستحتاج إلى عبارة '
                  'الحماية نفسها عند الاستعادة على جهاز آخر.',
                ),
                const SizedBox(height: 8),
                Text(
                  'المسار: $filePath',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles(
                    [XFile(filePath)],
                    text: 'نسخة احتياطية مشفرة لتطبيق حلقتي',
                  );
                },
                child: const Text('مشاركة الملف'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted && progressOpen) Navigator.pop(context);
      if (mounted) {
        _showDataError('تعذر إنشاء النسخة: $e');
      }
    } finally {
      if (mounted) setState(() => _dataActionBusy = false);
    }
  }

  Future<void> _refreshBackupStatus() async {
    final lastRaw = await _db.getSetting('last_backup_at');
    final error = await _db.getSetting('last_automatic_backup_error');
    final files = await _backup.getBackupFiles();
    final passphraseConfigured = await _backup.passphrases.isConfigured;
    if (!mounted) return;
    setState(() {
      _lastBackupAt = DateTime.tryParse(lastRaw ?? '');
      _lastAutomaticBackupError = error?.trim();
      _savedBackupCount = files.length;
      _isPassphraseConfigured = passphraseConfigured;
    });
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
                  leading: Icon(
                    file.path.endsWith('.halaqah')
                        ? Icons.lock_outline
                        : Icons.warning_amber_outlined,
                  ),
                  title: Text(fileName),
                  subtitle: Text(
                    file.path.endsWith('.halaqah')
                        ? 'نسخة مشفرة'
                        : 'نسخة قديمة غير مشفرة',
                  ),
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
      await _restoreFile(selectedFile);
    } catch (e) {
      if (mounted) {
        _showDataError('تعذر فتح النسخ الاحتياطية: $e');
      }
    }
  }

  Future<bool> _ensurePassphraseConfigured() async {
    if (await _backup.passphrases.isConfigured) return true;
    await _configureBackupPassphrase();
    return _backup.passphrases.isConfigured;
  }

  Future<void> _configureBackupPassphrase() async {
    final formKey = GlobalKey<FormState>();
    final passphraseController = TextEditingController();
    final confirmationController = TextEditingController();
    try {
      final passphrase = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            _isPassphraseConfigured
                ? 'تغيير عبارة حماية النسخ'
                : 'إعداد عبارة حماية النسخ',
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isPassphraseConfigured)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: Text(
                      'تنبيه: النسخ السابقة تبقى مرتبطة بعبارتها القديمة. '
                      'لا تغيّر العبارة قبل التأكد من حفظ القديمة.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                TextFormField(
                  controller: passphraseController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'عبارة الحماية',
                    helperText: '10 أحرف على الأقل، ويفضل جملة يسهل تذكرها',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                  validator: (value) {
                    final length = value?.runes.length ?? 0;
                    if (length < 10) return 'أدخل 10 أحرف على الأقل';
                    if (length > 256) return 'العبارة أطول من الحد المسموح';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmationController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'تأكيد العبارة',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                  validator: (value) => value != passphraseController.text
                      ? 'العبارتان غير متطابقتين'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(dialogContext, passphraseController.text);
              },
              child: const Text('حفظ بأمان'),
            ),
          ],
        ),
      );
      if (passphrase == null) return;
      await _backup.passphrases.save(passphrase);
      await AuditLogService().record(
        eventType: 'backup.passphrase_changed',
        entityType: 'security_setting',
      );
      if (!mounted) return;
      setState(() => _isPassphraseConfigured = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ عبارة الحماية في مخزن الجهاز الآمن'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      passphraseController.dispose();
      confirmationController.dispose();
    }
  }

  Future<String?> _requestBackupPassphrase() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('عبارة حماية النسخة'),
          content: TextField(
            controller: controller,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'أدخل العبارة المستخدمة عند إنشاء النسخة',
              prefixIcon: Icon(Icons.key_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text.runes.length < 10) return;
                Navigator.pop(dialogContext, controller.text);
              },
              child: const Text('فتح النسخة'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _restoreFile(File file) async {
    final inspection = await _backup.inspectBackup(file.path);
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد الاستعادة'),
        content: Text(
          '${inspection.encrypted ? 'النسخة مشفرة وسيتم التحقق من سلامتها.' : 'تحذير: هذه نسخة قديمة غير مشفرة.'}\n\n'
          'ستُستبدل البيانات المحلية الحالية داخل معاملة واحدة. يُنصح '
          'بإنشاء نسخة حديثة قبل المتابعة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _dataActionBusy = true);
    var progressOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      try {
        await _backup.importBackup(file.path);
      } on BackupAuthenticationException {
        if (mounted && progressOpen) {
          Navigator.pop(context);
          progressOpen = false;
        }
        final passphrase = await _requestBackupPassphrase();
        if (passphrase == null || !mounted) return;
        progressOpen = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        await _backup.importBackup(file.path, passphrase: passphrase);
      } on BackupPassphraseRequiredException {
        if (mounted && progressOpen) {
          Navigator.pop(context);
          progressOpen = false;
        }
        final passphrase = await _requestBackupPassphrase();
        if (passphrase == null || !mounted) return;
        progressOpen = true;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
        await _backup.importBackup(file.path, passphrase: passphrase);
      }
      if (mounted && progressOpen) {
        Navigator.pop(context);
        progressOpen = false;
      }
      await _refreshBackupStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم التحقق من النسخة واستعادة البيانات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted && progressOpen) Navigator.pop(context);
      if (mounted) _showDataError('فشلت الاستعادة: $error');
    } finally {
      if (mounted) setState(() => _dataActionBusy = false);
    }
  }

  Future<void> _performCloudBackup() async {
    if (!await _ensurePassphraseConfigured()) return;
    setState(() => _dataActionBusy = true);
    var progressOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final entry = await CloudBackupService().createAndUpload(
        retentionCount: _settings.cloudBackupRetentionCount,
      );
      await _refreshBackupStatus();
      if (mounted && progressOpen) {
        Navigator.pop(context);
        progressOpen = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم رفع النسخة المشفرة: ${entry.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      if (mounted && progressOpen) Navigator.pop(context);
      if (mounted) {
        _showDataError(
          'تعذر رفع النسخة. تأكد من تنفيذ migration التخزين السحابي: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _dataActionBusy = false);
    }
  }

  Future<void> _performDirectionalSync(CloudSyncDirection direction) async {
    if (direction.shouldDownload &&
        !await _ensurePassphraseConfigured()) {
      return;
    }
    if (direction == CloudSyncDirection.downloadOnly) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تنزيل بيانات السحابة؟'),
          content: const Text(
            'سينشئ التطبيق نسخة احتياطية محلية أولًا، ثم يدمج بيانات '
            'السحابة مع بيانات هذا الجهاز. لن يرفع هذا الخيار أي بيانات '
            'محلية.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('تنزيل'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _dataActionBusy = true);
    var progressOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                direction == CloudSyncDirection.uploadOnly
                    ? 'جاري رفع بيانات الجهاز...'
                    : direction == CloudSyncDirection.downloadOnly
                        ? 'جاري تنزيل بيانات السحابة...'
                        : 'جاري الرفع والتنزيل...',
              ),
            ),
          ],
        ),
      ),
    );
    try {
      final result = await SupabaseService.instance.synchronizeData(
        direction: direction,
      );
      if (mounted && progressOpen) {
        Navigator.pop(context);
        progressOpen = false;
      }
      if (!mounted) return;
      setState(() {
        if (direction.shouldUpload) {
          _lastCloudUploadAt = result.completedAt;
        }
        if (direction.shouldDownload) {
          _lastCloudDownloadAt = result.completedAt;
        }
      });
      final message = direction == CloudSyncDirection.uploadOnly
          ? 'تم الرفع فقط: الجهاز ← السحابة'
          : direction == CloudSyncDirection.downloadOnly
              ? 'تم التنزيل فقط: السحابة ← الجهاز'
              : 'اكتملت المزامنة الثنائية: رفع ثم تنزيل';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    } catch (error) {
      if (mounted && progressOpen) Navigator.pop(context);
      if (mounted) _showDataError('فشلت العملية السحابية: $error');
    } finally {
      if (mounted) setState(() => _dataActionBusy = false);
    }
  }

  Future<void> _performCloudRestore() async {
    setState(() => _dataActionBusy = true);
    var progressOpen = false;
    try {
      final cloud = CloudBackupService();
      final entries = await cloud.listBackups();
      if (!mounted) return;
      if (entries.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا توجد نسخ سحابية لهذا الحساب والمركز')),
        );
        return;
      }
      final selected = await showDialog<CloudBackupEntry>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('اختر نسخة سحابية'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: entries.length,
              itemBuilder: (_, index) => ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(entries[index].name),
                onTap: () => Navigator.pop(dialogContext, entries[index]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      progressOpen = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      final localPath = await cloud.download(selected);
      if (mounted && progressOpen) {
        Navigator.pop(context);
        progressOpen = false;
      }
      if (!mounted) return;
      setState(() => _dataActionBusy = false);
      await _restoreFile(File(localPath));
    } catch (error) {
      if (mounted && progressOpen) Navigator.pop(context);
      if (mounted) _showDataError('تعذر تحميل النسخة السحابية: $error');
    } finally {
      if (mounted) setState(() => _dataActionBusy = false);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PrivacyPolicyScreen(settings: _settings),
      ),
    );
    await _db.saveSetting(
      'privacy_policy_reviewed_at',
      DateTime.now().toIso8601String(),
    );
  }

  void _showDataError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showCustomPointsConfigDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final customRules = _settings.pointsConfig.entries
                .where((e) => e.key.startsWith('c_'))
                .toList();

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.star, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'قواعد النقاط والسلوك المخصصة',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditRuleDialog(setDialogState),
                      icon: const Icon(Icons.add),
                      label: Text('إضافة قاعدة جديدة', style: TextStyle()),
                    ),
                    const SizedBox(height: 12),
                    if (customRules.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'لا يوجد قواعد مخصصة حاليًا. أضف قواعدك الأولى كمعلم!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: customRules.length,
                          itemBuilder: (context, index) {
                            final rule = customRules[index];
                            final label = rule.key.substring(2);
                            final points = rule.value;
                            return ListTile(
                              title: Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                '${points > 0 ? "+" : ""}$points نقطة',
                                style: TextStyle(
                                  color: points >= 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _showAddEditRuleDialog(
                                      setDialogState,
                                      ruleKey: rule.key,
                                      ruleVal: rule.value,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        _settings.pointsConfig.remove(rule.key);
                                      });
                                      _saveSettings();
                                      setDialogState(() {});
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إغلاق', style: TextStyle()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddEditRuleDialog(void Function(void Function()) setParentState, {String? ruleKey, int? ruleVal}) {
    final isEditing = ruleKey != null;
    final nameController = TextEditingController(text: isEditing ? ruleKey.substring(2) : '');
    final pointsController = TextEditingController(text: isEditing ? ruleVal!.abs().toString() : '');
    bool isPositive = isEditing ? ruleVal! >= 0 : true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSubState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'تعديل القاعدة' : 'إضافة قاعدة جديدة',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم القاعدة (مثال: صلاة الفجر في المسجد)',
                      labelStyle: TextStyle(),
                      border: const OutlineInputBorder(),
                    ),
                    enabled: !isEditing,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('نوع النقاط: ', style: TextStyle()),
                      ChoiceChip(
                        label: Text('إيجابي (+)', style: TextStyle()),
                        selected: isPositive,
                        onSelected: (val) {
                          setSubState(() => isPositive = true);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('سلبي (-)', style: TextStyle()),
                        selected: !isPositive,
                        onSelected: (val) {
                          setSubState(() => isPositive = false);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pointsController,
                    decoration: InputDecoration(
                      labelText: 'مقدار النقاط',
                      labelStyle: TextStyle(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: TextStyle()),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = nameController.text.trim();
                    final points = int.tryParse(pointsController.text.trim()) ?? 0;
                    if (name.isEmpty || points <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('الرجاء إدخال اسم وقيمة نقاط صحيحة')),
                      );
                      return;
                    }
                    
                    final key = 'c_$name';
                    final actualPoints = isPositive ? points : -points;
                    
                    setState(() {
                      _settings.pointsConfig[key] = actualPoints;
                    });
                    _saveSettings();
                    setParentState(() {});
                    Navigator.pop(context);
                  },
                  child: Text('حفظ', style: TextStyle()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
