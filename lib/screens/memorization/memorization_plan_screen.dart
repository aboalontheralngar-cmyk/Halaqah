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
  
  Map<String, dynamic>? _weeklyPlan;
  Map<String, dynamic>? _monthlyPlan;
  Map<String, dynamic>? _yearlyPlan;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  void _generateWeeklyPlan() {
    // الخطة الأسبوعية = خطة لعدد أيام الحفظ في الأسبوع
    final plan = _quran.generateMonthlyPlan(
      startSurah: _startSurah,
      startAyah: _startAyah,
      dailyLines: _dailyLines,
      daysInMonth: _daysPerWeek,
    );
    setState(() => _weeklyPlan = plan);
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
          isScrollable: true,
          tabs: const [
            Tab(text: 'الخطة الأسبوعية'),
            Tab(text: 'الخطة الشهرية'),
            Tab(text: 'الخطة السنوية'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildWeeklyPlanTab(),
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
                const Expanded(child: Text('المقرر اليومي (أسطر):')),
                _buildStepperButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (_dailyLines > 0.5) {
                      setState(() {
                        _dailyLines -= 0.5;
                        _weeklyPlan = null;
                        _monthlyPlan = null;
                        _yearlyPlan = null;
                      });
                    }
                  },
                ),
                Container(
                  width: 56,
                  alignment: Alignment.center,
                  child: Text(
                    _dailyLines.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildStepperButton(
                  icon: Icons.add,
                  onTap: () {
                    if (_dailyLines < 10) {
                      setState(() {
                        _dailyLines += 0.5;
                        _weeklyPlan = null;
                        _monthlyPlan = null;
                        _yearlyPlan = null;
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(child: Text('أيام الحفظ/أسبوع:')),
                _buildStepperButton(
                  icon: Icons.remove,
                  onTap: () {
                    if (_daysPerWeek > 1) {
                      setState(() {
                        _daysPerWeek--;
                        _weeklyPlan = null;
                        _yearlyPlan = null;
                      });
                    }
                  },
                ),
                Container(
                  width: 56,
                  alignment: Alignment.center,
                  child: Text(
                    '$_daysPerWeek',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildStepperButton(
                  icon: Icons.add,
                  onTap: () {
                    if (_daysPerWeek < 7) {
                      setState(() {
                        _daysPerWeek++;
                        _weeklyPlan = null;
                        _yearlyPlan = null;
                      });
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: icon == Icons.add
              ? Theme.of(context).primaryColor
              : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: icon == Icons.add ? Colors.white : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildWeeklyPlanTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildSettingsCard(),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateWeeklyPlan,
              icon: const Icon(Icons.view_week),
              label: const Text('توليد الخطة الأسبوعية'),
            ),
          ),
          if (_weeklyPlan != null) ...[
            const SizedBox(height: 16),
            _buildDailyListView(_weeklyPlan!, 'الخطة الأسبوعية'),
          ],
        ],
      ),
    );
  }

  Widget _buildDailyListView(Map<String, dynamic> plan, String title) {
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
                Text(
                  title,
                  style: const TextStyle(
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
