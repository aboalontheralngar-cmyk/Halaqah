import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AyahRangePicker extends StatefulWidget {
  final int minAyah;
  final int maxAyahs;
  final int initialFrom;
  final int initialTo;
  final bool enabled;
  final bool singleValue;
  final Function(int from, int to) onRangeChanged;

  const AyahRangePicker({
    super.key,
    required this.maxAyahs,
    this.minAyah = 1,
    this.initialFrom = 1,
    required this.initialTo,
    this.enabled = true,
    this.singleValue = false,
    required this.onRangeChanged,
  });

  @override
  State<AyahRangePicker> createState() => _AyahRangePickerState();
}

class _AyahRangePickerState extends State<AyahRangePicker> {
  late RangeValues _currentRange;
  late final TextEditingController _fromController;
  late final TextEditingController _toController;
  String? _fromError;
  String? _toError;

  int get _safeMaxAyahs => widget.maxAyahs < 1 ? 1 : widget.maxAyahs;
  int get _safeMinAyah => widget.minAyah.clamp(1, _safeMaxAyahs).toInt();

  @override
  void initState() {
    super.initState();
    final double from = widget.initialFrom.toDouble().clamp(
          _safeMinAyah.toDouble(),
          _safeMaxAyahs.toDouble(),
        );
    final double to =
        widget.initialTo.toDouble().clamp(from, _safeMaxAyahs.toDouble());
    _currentRange = RangeValues(from, to);
    _fromController = TextEditingController(text: '${from.round()}');
    _toController = TextEditingController(text: '${to.round()}');
  }

  @override
  void didUpdateWidget(AyahRangePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minAyah != widget.minAyah ||
        oldWidget.maxAyahs != widget.maxAyahs ||
        oldWidget.initialFrom != widget.initialFrom ||
        oldWidget.initialTo != widget.initialTo) {
      final double from = widget.initialFrom.toDouble().clamp(
            _safeMinAyah.toDouble(),
            _safeMaxAyahs.toDouble(),
          );
      final double to =
          widget.initialTo.toDouble().clamp(from, _safeMaxAyahs.toDouble());
      _currentRange = RangeValues(from, to);
      _syncControllers(from.round(), to.round());
      _fromError = null;
      _toError = null;
    }
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  void _syncControllers(int from, int to) {
    if (_fromController.text != '$from') {
      _fromController.value = TextEditingValue(
        text: '$from',
        selection: TextSelection.collapsed(offset: '$from'.length),
      );
    }
    if (_toController.text != '$to') {
      _toController.value = TextEditingValue(
        text: '$to',
        selection: TextSelection.collapsed(offset: '$to'.length),
      );
    }
  }

  void _setRange(int from, int to) {
    setState(() {
      _currentRange = RangeValues(from.toDouble(), to.toDouble());
      _fromError = null;
      _toError = null;
      _syncControllers(from, to);
    });
    widget.onRangeChanged(from, to);
  }

  void _handleFromInput(String text) {
    final value = int.tryParse(text);
    final to = _currentRange.end.round();
    if (value == null) {
      setState(() => _fromError = 'أدخل رقمًا');
      return;
    }
    if (value < _safeMinAyah || value > _safeMaxAyahs) {
      setState(
        () => _fromError = 'من $_safeMinAyah إلى $_safeMaxAyahs',
      );
      return;
    }
    if (value > to) {
      setState(() => _fromError = 'أكبر من آية النهاية');
      return;
    }
    _setRange(value, to);
  }

  void _handleSingleInput(String text) {
    final value = int.tryParse(text);
    if (value == null) {
      setState(() => _fromError = 'أدخل رقمًا');
      return;
    }
    if (value < _safeMinAyah || value > _safeMaxAyahs) {
      setState(
        () => _fromError = 'من $_safeMinAyah إلى $_safeMaxAyahs',
      );
      return;
    }
    _setRange(value, value);
  }

  void _handleToInput(String text) {
    final value = int.tryParse(text);
    final from = _currentRange.start.round();
    if (value == null) {
      setState(() => _toError = 'أدخل رقمًا');
      return;
    }
    if (value < _safeMinAyah || value > _safeMaxAyahs) {
      setState(
        () => _toError = 'من $_safeMinAyah إلى $_safeMaxAyahs',
      );
      return;
    }
    if (value < from) {
      setState(() => _toError = 'أصغر من آية البداية');
      return;
    }
    _setRange(from, value);
  }

  @override
  Widget build(BuildContext context) {
    final from = _currentRange.start.round();
    final to = _currentRange.end.round();
    final count = to - from + 1;

    if (widget.singleValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'آية البداية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildAyahInput(
                'من',
                _fromController,
                _fromError,
                _handleSingleInput,
              ),
              Expanded(
                child: _safeMaxAyahs > _safeMinAyah
                    ? Slider(
                        value: from.toDouble(),
                        min: _safeMinAyah.toDouble(),
                        max: _safeMaxAyahs.toDouble(),
                        divisions: _safeMaxAyahs - _safeMinAyah,
                        label: '$from',
                        onChanged: widget.enabled
                            ? (value) {
                                final ayah = value.round();
                                _setRange(ayah, ayah);
                              }
                            : null,
                      )
                    : const SizedBox(height: 48),
              ),
              Container(
                width: 72,
                alignment: Alignment.center,
                child: Text(
                  'الآية $from',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('الآية $_safeMinAyah', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text('الآية $_safeMaxAyahs', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      );
    }

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
            _buildAyahInput(
              'من',
              _fromController,
              _fromError,
              _handleFromInput,
            ),
            Expanded(
              child: _safeMaxAyahs > _safeMinAyah
                  ? RangeSlider(
                      values: _currentRange,
                      min: _safeMinAyah.toDouble(),
                      max: _safeMaxAyahs.toDouble(),
                      divisions: _safeMaxAyahs - _safeMinAyah,
                      labels: RangeLabels('$from', '$to'),
                      onChanged: widget.enabled
                          ? (values) {
                              _setRange(
                                values.start.round(),
                                values.end.round(),
                              );
                            }
                          : null,
                    )
                  : const SizedBox(height: 48),
            ),
            _buildAyahInput(
              'إلى',
              _toController,
              _toError,
              _handleToInput,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('الآية $_safeMinAyah', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('الآية $_safeMaxAyahs', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }

  Widget _buildAyahInput(
    String label,
    TextEditingController controller,
    String? errorText,
    ValueChanged<String> onChanged,
  ) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        SizedBox(
          width: 60,
          child: TextFormField(
            controller: controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              errorText: errorText,
              errorMaxLines: 2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: onChanged,
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
