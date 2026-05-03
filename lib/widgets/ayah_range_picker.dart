import 'package:flutter/material.dart';

class AyahRangePicker extends StatefulWidget {
  final int maxAyahs;
  final int initialFrom;
  final int initialTo;
  final Function(int from, int to) onRangeChanged;

  const AyahRangePicker({
    super.key,
    required this.maxAyahs,
    this.initialFrom = 1,
    required this.initialTo,
    required this.onRangeChanged,
  });

  @override
  State<AyahRangePicker> createState() => _AyahRangePickerState();
}

class _AyahRangePickerState extends State<AyahRangePicker> {
  late RangeValues _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = RangeValues(
      widget.initialFrom.toDouble(),
      widget.initialTo.toDouble(),
    );
  }

  @override
  void didUpdateWidget(AyahRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.maxAyahs != widget.maxAyahs) {
      _currentRange = RangeValues(1, widget.maxAyahs.toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _currentRange.start.round();
    final to = _currentRange.end.round();
    final count = to - from + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'نطاق الآيات',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count آية',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildAyahInput('من', from, (value) {
              if (value >= 1 && value <= to) {
                setState(() {
                  _currentRange = RangeValues(value.toDouble(), _currentRange.end);
                });
                widget.onRangeChanged(value, to);
              }
            }),
            Expanded(
              child: RangeSlider(
                values: _currentRange,
                min: 1,
                max: widget.maxAyahs.toDouble(),
                divisions: widget.maxAyahs - 1,
                labels: RangeLabels('$from', '$to'),
                onChanged: (values) {
                  setState(() => _currentRange = values);
                  widget.onRangeChanged(values.start.round(), values.end.round());
                },
              ),
            ),
            _buildAyahInput('إلى', to, (value) {
              if (value >= from && value <= widget.maxAyahs) {
                setState(() {
                  _currentRange = RangeValues(_currentRange.start, value.toDouble());
                });
                widget.onRangeChanged(from, value);
              }
            }),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الآية 1', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('الآية ${widget.maxAyahs}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildAyahInput(String label, int value, Function(int) onChanged) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: TextFormField(
            initialValue: '$value',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (text) {
              final newValue = int.tryParse(text);
              if (newValue != null) {
                onChanged(newValue);
              }
            },
          ),
        ),
      ],
    );
  }
}

class AyahRangePickerCompact extends StatelessWidget {
  final int maxAyahs;
  final int from;
  final int to;
  final VoidCallback onTap;

  const AyahRangePickerCompact({
    super.key,
    required this.maxAyahs,
    required this.from,
    required this.to,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('نطاق الآيات', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  'من $from إلى $to',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${to - from + 1} آية',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
