import 'package:flutter/material.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../services/backup_service.dart';
import '../../services/supabase_service.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/settings.dart';
import '../../app/app.dart';
import '../../utils/prayer_time_helper.dart';
import 'message_templates_screen.dart';
import 'whats_new_screen.dart';

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
  String _selectedSection = 'halaqah';
  DateTime? _lastBackupAt;
  String? _lastAutomaticBackupError;
  int _savedBackupCount = 0;

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
      ]);
      final settings = results[0] as HalaqahSettings;
      setState(() {
        _settings = settings;
        _lastBackupAt = DateTime.tryParse((results[1] as String?) ?? '');
        _lastAutomaticBackupError = (results[2] as String?)?.trim();
        _savedBackupCount = (results[3] as List).length;
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
              style: GoogleFonts.tajawal(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 16),
            
            // Timing Type Selection
            Text(
              'نوع جدولة الوقت:',
              style: GoogleFonts.tajawal(fontSize: 14, fontWeight: FontWeight.bold),
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
                    label: Text('وقت ثابت', style: GoogleFonts.tajawal(fontSize: 13)),
                    icon: const Icon(Icons.timer_outlined),
                  ),
                  ButtonSegment(
                    value: 'relative',
                    label: Text('مرتبط بالصلوات', style: GoogleFonts.tajawal(fontSize: 13)),
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
                style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold),
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
                style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold),
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
                  style: GoogleFonts.tajawal(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange[700]),
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
              style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _settings.ramadanTimingType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: 'same', child: Text('نفس التوقيت المعتاد (العادي)', style: GoogleFonts.tajawal(fontSize: 14))),
                DropdownMenuItem(value: 'fixed', child: Text('ساعات ثابتة مخصصة لرمضان', style: GoogleFonts.tajawal(fontSize: 14))),
                DropdownMenuItem(value: 'relative', child: Text('مرتبط بالصلوات لرمضان', style: GoogleFonts.tajawal(fontSize: 14))),
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
                style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold),
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
                style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold),
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
            ListTile(
              leading: const Icon(Icons.backup),
              title: const Text('إنشاء نسخة الآن'),
              subtitle: const Text('حفظ نسخة كاملة وإتاحة مشاركتها خارج الجهاز'),
              onTap: () => _performBackup(),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('استعادة'),
              subtitle: const Text('استعادة إحدى النسخ المحلية المحفوظة'),
              onTap: () => _performRestore(),
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
            const Text('الإصدار 1.2.0'),
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
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      
      final filePath = await _backup.exportBackup();
      await _refreshBackupStatus();
      
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
                onPressed: () {
                  Navigator.pop(context);
                  Share.shareXFiles([XFile(filePath)], text: 'نسخة احتياطية لقاعدة بيانات حلقتي');
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
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في النسخ الاحتياطي: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _refreshBackupStatus() async {
    final lastRaw = await _db.getSetting('last_backup_at');
    final error = await _db.getSetting('last_automatic_backup_error');
    final files = await _backup.getBackupFiles();
    if (!mounted) return;
    setState(() {
      _lastBackupAt = DateTime.tryParse(lastRaw ?? '');
      _lastAutomaticBackupError = error?.trim();
      _savedBackupCount = files.length;
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
                    style: GoogleFonts.tajawal(fontWeight: FontWeight.bold, fontSize: 16),
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
                      label: Text('إضافة قاعدة جديدة', style: GoogleFonts.tajawal()),
                    ),
                    const SizedBox(height: 12),
                    if (customRules.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'لا يوجد قواعد مخصصة حاليًا. أضف قواعدك الأولى كمعلم!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.tajawal(color: Colors.grey),
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
                              title: Text(label, style: GoogleFonts.tajawal(fontWeight: FontWeight.w500)),
                              subtitle: Text(
                                '${points > 0 ? "+" : ""}$points نقطة',
                                style: GoogleFonts.tajawal(
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
                  child: Text('إغلاق', style: GoogleFonts.tajawal()),
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
                style: GoogleFonts.tajawal(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم القاعدة (مثال: صلاة الفجر في المسجد)',
                      labelStyle: GoogleFonts.tajawal(),
                      border: const OutlineInputBorder(),
                    ),
                    enabled: !isEditing,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('نوع النقاط: ', style: GoogleFonts.tajawal()),
                      ChoiceChip(
                        label: Text('إيجابي (+)', style: GoogleFonts.tajawal()),
                        selected: isPositive,
                        onSelected: (val) {
                          setSubState(() => isPositive = true);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text('سلبي (-)', style: GoogleFonts.tajawal()),
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
                      labelStyle: GoogleFonts.tajawal(),
                      border: const OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.tajawal()),
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
                  child: Text('حفظ', style: GoogleFonts.tajawal()),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
