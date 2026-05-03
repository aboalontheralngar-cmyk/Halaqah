import 'package:flutter/material.dart';
import '../../services/quran_service.dart';
import '../../widgets/surah_picker.dart';

class MemorizationPlanScreen extends StatefulWidget {
  const MemorizationPlanScreen({super.key});

  @override
  State<MemorizationPlanScreen> createState() => _MemorizationPlanScreenState();
}

class _MemorizationPlanScreenState extends State<MemorizationPlanScreen>
    with SingleTickerProviderStateMixin {
  final QuranService _quran = QuranService.instance;
  late TabController _tabController;

  int _startSurah = 78;
  int _startAyah = 1;
  double _dailyLines = 2.0;
  int _daysPerWeek = 5;
  
  Map<String, dynamic>? _monthlyPlan;
  Map<String, dynamic>? _yearlyPlan;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateMonthlyPlan() {
    final plan = _quran.generateMonthlyPlan(
      startSurah: _startSurah,
      startAyah: _startAyah,
      dailyLines: _dailyLines,
      daysInMonth: 26,
    );
    setState(() => _monthlyPlan = plan);
  }

  void _generateYearlyPlan() {
    final plan = _quran.generateYearlyPlan(
      startSurah: _startSurah,
      startAyah: _startAyah,
      dailyLines: _dailyLines,
      daysPerWeek: _daysPerWeek,
    );
    setState(() => _yearlyPlan = plan);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خطة الحفظ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الخطة الشهرية'),
            Tab(text: 'الخطة السنوية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMonthlyPlanTab(),
          _buildYearlyPlanTab(),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعدادات الخطة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final surahId = await showSurahPicker(
                  context,
                  selectedSurahId: _startSurah,
                  title: 'سورة البداية',
                );
                if (surahId != null) {
                  setState(() {
                    _startSurah = surahId;
                    _startAyah = 1;
                    _monthlyPlan = null;
                    _yearlyPlan = null;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('سورة البداية', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            'سورة ${_quran.getSurahName(_startSurah)} - الآية $_startAyah',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('المقرر اليومي:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _dailyLines,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    label: '${_dailyLines.toStringAsFixed(1)} سطر',
                    onChanged: (value) {
                      setState(() {
                        _dailyLines = value;
                        _monthlyPlan = null;
                        _yearlyPlan = null;
                      });
                    },
                  ),
                ),
                Text('${_dailyLines.toStringAsFixed(1)} سطر'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('أيام الحفظ/أسبوع:'),
                const SizedBox(width: 12),
                Expanded(
                  child: Slider(
                    value: _daysPerWeek.toDouble(),
                    min: 3,
                    max: 6,
                    divisions: 3,
                    label: '$_daysPerWeek أيام',
                    onChanged: (value) {
                      setState(() {
                        _daysPerWeek = value.round();
                        _yearlyPlan = null;
                      });
                    },
                  ),
                ),
                Text('$_daysPerWeek أيام'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSettingsCard(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateMonthlyPlan,
              icon: const Icon(Icons.calendar_month),
              label: const Text('توليد الخطة الشهرية'),
            ),
          ),
          if (_monthlyPlan != null) ...[
            const SizedBox(height: 16),
            _buildMonthlyPlanView(),
          ],
        ],
      ),
    );
  }

  Widget _buildYearlyPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSettingsCard(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateYearlyPlan,
              icon: const Icon(Icons.calendar_today),
              label: const Text('توليد الخطة السنوية'),
            ),
          ),
          if (_yearlyPlan != null) ...[
            const SizedBox(height: 16),
            _buildYearlyPlanView(),
          ],
        ],
      ),
    );
  }

  Widget _buildMonthlyPlanView() {
    final plan = _monthlyPlan!;
    final dailyPlan = plan['plan'] as List;

    return Card(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'الخطة الشهرية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'من ${plan['start']} إلى ${plan['end']}',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'المقرر اليومي: ${plan['daily_target']} سطر',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: dailyPlan.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final day = dailyPlan[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getDayColor(index),
                  child: Text(
                    '${day['day']}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(
                  day['from_surah'] == day['to_surah']
                      ? '${day['from_surah_name']}: ${day['from_ayah']} - ${day['to_ayah']}'
                      : '${day['from_surah_name']}:${day['from_ayah']} - ${day['to_surah_name']}:${day['to_ayah']}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: Text(
                  '${day['lines']} سطر',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYearlyPlanView() {
    final plan = _yearlyPlan!;
    final monthlyPlan = plan['plan'] as List;

    return Card(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'الخطة السنوية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'البداية: ${plan['start']}',
                  style: const TextStyle(color: Colors.white70),
                ),
                Text(
                  'المقرر: ${plan['daily_target']} سطر - ${plan['days_per_week']} أيام/أسبوع',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: monthlyPlan.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final month = monthlyPlan[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getMonthColor(index),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                title: Text(
                  month['month'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${month['from_surah']}:${month['from_ayah']} - ${month['to_surah']}:${month['to_ayah']}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${month['total_lines']} سطر',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${month['work_days']} يوم',
                      style: TextStyle(color: Colors.grey[600], fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getDayColor(int index) {
    if (index % 7 == 4 || index % 7 == 5) return Colors.orange;
    return Theme.of(context).primaryColor;
  }

  Color _getMonthColor(int index) {
    final colors = [
      Colors.blue, Colors.green, Colors.purple, Colors.orange,
      Colors.teal, Colors.red, Colors.indigo, Colors.pink,
      Colors.amber, Colors.cyan, Colors.deepPurple, Colors.lime,
    ];
    return colors[index % colors.length];
  }
}
