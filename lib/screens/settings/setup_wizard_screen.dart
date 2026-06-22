import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../models/settings.dart';
import '../../utils/prayer_time_helper.dart';
import '../home/home_screen.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _db = DatabaseService();

  final _halaqahNameController = TextEditingController(text: 'حلقة التحفيظ');
  final _mosqueNameController = TextEditingController();
  final _teacherNameController = TextEditingController();
  final _teacherPhoneController = TextEditingController();

  String _normalStartTime = '16:00';
  String _normalEndTime = '18:00';
  String _gender = 'male';
  String _timeFormat = '12h';
  String _timingType = 'fixed';
  String _country = 'YE';
  String _city = 'صنعاء';
  String _relativeStartPrayer = 'asr';
  int _relativeStartOffset = 15;
  int _classDurationMinutes = 120;
  bool _isSaving = false;

  @override
  void dispose() {
    _halaqahNameController.dispose();
    _mosqueNameController.dispose();
    _teacherNameController.dispose();
    _teacherPhoneController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(bool isStart) async {
    final initialTimeStr = isStart ? _normalStartTime : _normalEndTime;
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
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _normalStartTime = formattedTime;
        } else {
          _normalEndTime = formattedTime;
        }
      });
    }
  }

  // Format 24h string to 12h for visual display
  String _formatTimeDisplay(String time24) {
    try {
      final parts = time24.split(':');
      final hour24 = int.parse(parts[0]);
      final minute = parts[1];
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      final period = hour24 >= 12 ? 'م' : 'ص';
      return '$hour12:$minute $period';
    } catch (_) {
      return time24;
    }
  }

  Future<void> _saveAndProceed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final settings = HalaqahSettings(
        halaqahName: _halaqahNameController.text.trim(),
        mosqueName: _mosqueNameController.text.trim(),
        teacherName: _teacherNameController.text.trim(),
        teacherPhone: _teacherPhoneController.text.trim(),
        normalStartTime: _normalStartTime,
        normalEndTime: _normalEndTime,
        gender: _gender,
        timeFormat: _timeFormat,
        timingType: _timingType,
        country: _country,
        city: _city,
        relativeStartPrayer: _relativeStartPrayer,
        relativeStartOffset: _relativeStartOffset,
        classDurationMinutes: _classDurationMinutes,
      );

      // Save all settings
      await _db.saveSettings(settings);
      
      // Save completion flag
      await _db.saveSetting('setup_completed', 'true');

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'حدث خطأ أثناء حفظ الإعدادات: $e',
              style: GoogleFonts.tajawal(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countryCities = PrayerTimeHelper.countriesData[_country] ?? {};
    final citiesList = countryCities.keys.toList();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor.withOpacity(0.08),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              children: [
                // Icon and Welcome Header
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.menu_book_rounded,
                          size: 64,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'مرحباً بك في تطبيق حلقتي',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'لنقم بتهيئة الإعدادات الأساسية لحلقتك أولاً',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.tajawal(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Card wrapping the form fields
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'معلومات الحلقة والمعلم',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Halaqah Name
                        TextFormField(
                          controller: _halaqahNameController,
                          decoration: InputDecoration(
                            labelText: 'اسم الحلقة *',
                            labelStyle: GoogleFonts.tajawal(),
                            prefixIcon: const Icon(Icons.mosque_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'الرجاء إدخال اسم الحلقة';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Mosque Name
                        TextFormField(
                          controller: _mosqueNameController,
                          decoration: InputDecoration(
                            labelText: 'اسم المسجد / المركز',
                            labelStyle: GoogleFonts.tajawal(),
                            prefixIcon: const Icon(Icons.location_on_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Teacher Name
                        TextFormField(
                          controller: _teacherNameController,
                          decoration: InputDecoration(
                            labelText: 'اسم المعلم / المعلمة *',
                            labelStyle: GoogleFonts.tajawal(),
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'الرجاء إدخال اسم المعلم';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Teacher Phone
                        TextFormField(
                          controller: _teacherPhoneController,
                          decoration: InputDecoration(
                            labelText: 'رقم جوال المعلم',
                            labelStyle: GoogleFonts.tajawal(),
                            prefixIcon: const Icon(Icons.phone_outlined),
                            hintText: '05xxxxxxxx',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Card wrapping Timing, Gender, and Format settings
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تخصيص الإعدادات وجنس الحلقة',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Gender Selection
                        Text(
                          'جنس الحلقة:',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: theme.primaryColor.withOpacity(0.15),
                            selectedForegroundColor: theme.primaryColor,
                          ),
                          segments: [
                            ButtonSegment(
                              value: 'male',
                              label: Text('بنين (طلاب)', style: GoogleFonts.tajawal()),
                              icon: const Icon(Icons.male),
                            ),
                            ButtonSegment(
                              value: 'female',
                              label: Text('بنات (طالبات)', style: GoogleFonts.tajawal()),
                              icon: const Icon(Icons.female),
                            ),
                          ],
                          selected: {_gender},
                          onSelectionChanged: (set) {
                            setState(() => _gender = set.first);
                          },
                        ),
                        const SizedBox(height: 20),

                        // Halaqah timing selection
                        Text(
                          'طريقة تحديد وقت الحلقة:',
                          style: GoogleFonts.tajawal(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: theme.primaryColor.withOpacity(0.15),
                              selectedForegroundColor: theme.primaryColor,
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
                            selected: {_timingType},
                            onSelectionChanged: (set) {
                              setState(() => _timingType = set.first);
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        if (_timingType == 'fixed') ...[
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectTime(true),
                                  borderRadius: BorderRadius.circular(16),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'البدء',
                                      labelStyle: GoogleFonts.tajawal(),
                                      prefixIcon: const Icon(Icons.access_time_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      _formatTimeDisplay(_normalStartTime),
                                      style: GoogleFonts.tajawal(fontSize: 15),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _selectTime(false),
                                  borderRadius: BorderRadius.circular(16),
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'الانتهاء',
                                      labelStyle: GoogleFonts.tajawal(),
                                      prefixIcon: const Icon(Icons.access_time_outlined),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: Text(
                                      _formatTimeDisplay(_normalEndTime),
                                      style: GoogleFonts.tajawal(fontSize: 15),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Relative/Dynamic timing selector
                          DropdownButtonFormField<String>(
                            value: _country,
                            decoration: InputDecoration(
                              labelText: 'الدولة *',
                              labelStyle: GoogleFonts.tajawal(),
                              prefixIcon: const Icon(Icons.public),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            items: PrayerTimeHelper.getSupportedCountries().entries.map((e) {
                              return DropdownMenuItem(value: e.key, child: Text(e.value, style: GoogleFonts.tajawal()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final newCountryCities = PrayerTimeHelper.countriesData[val] ?? {};
                                final defaultCity = newCountryCities.keys.isNotEmpty ? newCountryCities.keys.first : 'custom';
                                setState(() {
                                  _country = val;
                                  _city = defaultCity;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: citiesList.contains(_city) ? _city : (citiesList.isNotEmpty ? citiesList.first : 'custom'),
                            decoration: InputDecoration(
                              labelText: 'المدينة *',
                              labelStyle: GoogleFonts.tajawal(),
                              prefixIcon: const Icon(Icons.location_city),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            items: [
                              ...citiesList.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.tajawal()))),
                              DropdownMenuItem(value: 'custom', child: Text('موقع مخصص', style: GoogleFonts.tajawal())),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _city = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          DropdownButtonFormField<String>(
                            value: _relativeStartPrayer,
                            decoration: InputDecoration(
                              labelText: 'البداية نسبة إلى صلاة *',
                              labelStyle: GoogleFonts.tajawal(),
                              prefixIcon: const Icon(Icons.church_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            items: ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].map((p) {
                              return DropdownMenuItem(value: p, child: Text(PrayerTimeHelper.getPrayerLabel(p), style: GoogleFonts.tajawal()));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _relativeStartPrayer = val);
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Slider for offset
                          Text(
                            'إزاحة وقت البدء: ' +
                                (_relativeStartOffset >= 0 ? '+' : '') +
                                '$_relativeStartOffset دقيقة (${_relativeStartOffset >= 0 ? 'بعد الصلاة' : 'قبل الصلاة'})',
                            style: GoogleFonts.tajawal(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey[700]),
                          ),
                          Slider(
                            value: _relativeStartOffset.toDouble(),
                            min: -90,
                            max: 120,
                            divisions: 42,
                            label: '$_relativeStartOffset د',
                            onChanged: (val) {
                              setState(() => _relativeStartOffset = val.toInt());
                            },
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Time Format Selection
                        DropdownButtonFormField<String>(
                          value: _timeFormat,
                          decoration: InputDecoration(
                            labelText: 'تنسيق الوقت الافتراضي',
                            labelStyle: GoogleFonts.tajawal(),
                            prefixIcon: const Icon(Icons.av_timer),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: '12h',
                              child: Text('12 ساعة (ص / م)', style: GoogleFonts.tajawal()),
                            ),
                            DropdownMenuItem(
                              value: '24h',
                              child: Text('24 ساعة', style: GoogleFonts.tajawal()),
                            ),
                            DropdownMenuItem(
                              value: 'device',
                              child: Text('تلقائي (مع إعداد الجوال)', style: GoogleFonts.tajawal()),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _timeFormat = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Save and Proceed Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveAndProceed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 1,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'حفظ الإعدادات والبدء',
                          style: GoogleFonts.tajawal(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
