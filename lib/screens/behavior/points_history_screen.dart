import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/behavior_point.dart';
import '../../utils/helpers.dart';

class PointsHistoryScreen extends StatefulWidget {
  final Student student;

  const PointsHistoryScreen({super.key, required this.student});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<BehaviorPoint> _points = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoading = true);
    try {
      final points = await _db.getStudentBehaviorPoints(widget.student.id);
      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<BehaviorPoint> get _filteredPoints {
    if (_filter == 'all') return _points;
    if (_filter == 'positive') {
      return _points.where((p) => p.type == 'positive').toList();
    }
    return _points.where((p) => p.type == 'negative').toList();
  }

  int get _positiveTotal =>
      _points.where((p) => p.type == 'positive').fold(0, (sum, p) => sum + p.points);

  int get _negativeTotal =>
      _points.where((p) => p.type == 'negative').fold(0, (sum, p) => sum + p.points);

  int get _netTotal => _positiveTotal + _negativeTotal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('نقاط ${widget.student.name}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'positive', child: Text('إيجابية فقط')),
              const PopupMenuItem(value: 'negative', child: Text('سلبية فقط')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(),
                Expanded(
                  child: _filteredPoints.isEmpty
                      ? _buildEmptyState()
                      : _buildPointsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem('إيجابي', '+$_positiveTotal', Colors.green),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem('سلبي', '$_negativeTotal', Colors.red),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem('الصافي', '$_netTotal', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سجل نقاط',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsList() {
    return RefreshIndicator(
      onRefresh: _loadPoints,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredPoints.length,
        itemBuilder: (context, index) {
          final point = _filteredPoints[index];
          return _buildPointCard(point);
        },
      ),
    );
  }

  Widget _buildPointCard(BehaviorPoint point) {
    final isPositive = point.type == 'positive';
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            isPositive ? Icons.add_circle : Icons.remove_circle,
            color: color,
          ),
        ),
        title: Text(point.reason),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(Helpers.formatHijriDate(point.date)),
            if (point.notes != null && point.notes!.isNotEmpty)
              Text(
                point.notes!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            if (!point.resolved)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'مخالفة قائمة',
                  style: TextStyle(fontSize: 10, color: Colors.orange),
                ),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${isPositive ? '+' : ''}${point.points}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
