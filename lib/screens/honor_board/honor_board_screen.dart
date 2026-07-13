import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class HonorBoardScreen extends StatefulWidget {
  const HonorBoardScreen({super.key});

  @override
  State<HonorBoardScreen> createState() => _HonorBoardScreenState();
}

class _HonorBoardScreenState extends State<HonorBoardScreen> {
  final DatabaseService _db = DatabaseService();
  List<StudentRankData> _ranking = [];
  bool _isLoading = true;
  
  // Ranking Mode: 'points' (السلوك والتربية) or 'memorization' (الحفظ القرآني)
  String _rankingMode = 'points';

  @override
  void initState() {
    super.initState();
    _loadRanking();
  }

  Future<void> _loadRanking() async {
    setState(() => _isLoading = true);
    try {
      final activeStudents = await _db.getStudents(status: 'active');
      final List<StudentRankData> list = [];
      
      for (final student in activeStudents) {
        int score = 0;
        if (_rankingMode == 'points') {
          score = await _db.getStudentTotalPoints(student.id);
        } else {
          score = student.totalMemorized;
        }
        list.add(StudentRankData(student: student, score: score));
      }
      
      // Sort descending by score
      list.sort((a, b) => b.score.compareTo(a.score));
      
      setState(() {
        _ranking = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة الشرف والصدارة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Toggle mode segmented button
                Container(
                  padding: const EdgeInsets.all(16),
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  child: Center(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'points',
                          label: Text('المتميزين سلوكاً ونقاطاً'),
                          icon: Icon(Icons.star, size: 16),
                        ),
                        ButtonSegment(
                          value: 'memorization',
                          label: Text('الأكثر حفظاً وتسميعاً'),
                          icon: Icon(Icons.menu_book, size: 16),
                        ),
                      ],
                      selected: {_rankingMode},
                      onSelectionChanged: (set) {
                        setState(() {
                          _rankingMode = set.first;
                        });
                        _loadRanking();
                      },
                    ),
                  ),
                ),
                
                if (_ranking.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'لا تتوفر إحصائيات للطلاب حالياً',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadRanking,
                      child: ListView(
                        children: [
                          // 1. Build the Top 3 Podium if we have at least 1 student
                          _buildPodium(),
                          
                          // 2. Full ranking table
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Text(
                              'جدول الصدارة والترتيب العام',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          
                          ...List.generate(
                            _ranking.length,
                            (index) => _buildRankTile(index),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPodium() {
    final hasOne = _ranking.isNotEmpty;
    final hasTwo = _ranking.length >= 2;
    final hasThree = _ranking.length >= 3;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0D9488).withOpacity(0.1), Colors.transparent]
              : [const Color(0xFFE0F2FE).withOpacity(0.5), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 2nd Place Spot (Left)
          if (hasTwo)
            _podiumSpot(
              rank: 2,
              data: _ranking[1],
              height: 100,
              color: const Color(0xFF94A3B8), // Silver / Slate
              medalEmoji: '🥈',
            )
          else
            const Expanded(child: SizedBox()),
          
          const SizedBox(width: 12),
          
          // 1st Place Spot (Middle)
          if (hasOne)
            _podiumSpot(
              rank: 1,
              data: _ranking[0],
              height: 140,
              color: const Color(0xFFEAB308), // Gold / Amber
              medalEmoji: '🥇',
            )
          else
            const Expanded(child: SizedBox()),
          
          const SizedBox(width: 12),
          
          // 3rd Place Spot (Right)
          if (hasThree)
            _podiumSpot(
              rank: 3,
              data: _ranking[2],
              height: 80,
              color: const Color(0xFFD97706), // Bronze / Amber Darker
              medalEmoji: '🥉',
            )
          else
            const Expanded(child: SizedBox()),
        ],
      ),
    );
  }

  Widget _podiumSpot({
    required int rank,
    required StudentRankData data,
    required double height,
    required Color color,
    required String medalEmoji,
  }) {
    final s = data.student;
    final score = data.score;
    final nameParts = s.name.split(' ');
    final shortName = nameParts.length > 2 ? '${nameParts[0]} ${nameParts[1]}' : s.name;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(medalEmoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(
            shortName,
            style: TextStyle(
              fontSize: rank == 1 ? 14 : 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            _formatScore(score),
            style: TextStyle(
              fontSize: rank == 1 ? 18 : 15,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border.all(color: color.withOpacity(0.4), width: 1.5),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: rank == 1 ? 32 : 24,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankTile(int index) {
    final data = _ranking[index];
    final s = data.student;
    final score = data.score;

    String rankLabel;
    Color rankColor;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (index == 0) {
      rankLabel = '🥇';
      rankColor = const Color(0xFFEAB308);
    } else if (index == 1) {
      rankLabel = '🥈';
      rankColor = const Color(0xFF94A3B8);
    } else if (index == 2) {
      rankLabel = '🥉';
      rankColor = const Color(0xFFD97706);
    } else {
      rankLabel = '${index + 1}';
      rankColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: index < 3
                ? Text(rankLabel, style: const TextStyle(fontSize: 16))
                : Text(
                    rankLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : const Color(0xFF334155),
                      fontSize: 13,
                    ),
                  ),
          ),
        ),
        title: Text(
          s.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            _rankingMode == 'points' ? 'السلوك والمشاركات' : 'عدد السور/الآيات المحفوظة',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: rankColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            _formatScore(score),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: index < 3 ? rankColor : (isDark ? Colors.white : const Color(0xFF0F172A)),
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  String _formatScore(int score) {
    if (_rankingMode == 'points') {
      return '$score نقطة';
    } else {
      return '$score آية';
    }
  }
}

class StudentRankData {
  final Student student;
  final int score;

  StudentRankData({required this.student, required this.score});
}
