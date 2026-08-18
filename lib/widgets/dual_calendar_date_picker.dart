import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';

import '../utils/helpers.dart';

/// اختيار فترة بخيار صريح بين التقويم الهجري والميلادي.
///
/// التقويم الهجري لا يعتمد على تحويلات يدوية أو حقول نصية؛ بل يعرض شبكة أيام
/// الشهر الهجري الفعلية انطلاقًا من محرك `hijri` المستخدم أصلًا في التطبيق.
Future<DateTimeRange?> showDualCalendarDateRangePicker({
  required BuildContext context,
  required DateTimeRange initialDateRange,
  required DateTime firstDate,
  required DateTime lastDate,
  bool preferHijri = true,
  String title = 'اختيار الفترة',
}) async {
  final mode = await showDialog<_CalendarMode>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: const Text('اختر التقويم الذي تريد استخدامه لتحديد بداية الفترة ونهايتها.'),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(dialogContext, _CalendarMode.gregorian),
          icon: const Icon(Icons.calendar_month_outlined),
          label: const Text('ميلادي'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialogContext, _CalendarMode.hijri),
          icon: const Icon(Icons.brightness_2_outlined),
          label: const Text('هجري'),
        ),
      ],
    ),
  );
  if (mode == null) return null;
  if (mode == _CalendarMode.gregorian) {
    if (!context.mounted) return null;
    return showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: initialDateRange,
      helpText: title,
      saveText: 'اعتماد الفترة',
    );
  }

  if (!context.mounted) return null;
  final start = await _showHijriDatePicker(
    context: context,
    initialDate: initialDateRange.start,
    firstDate: firstDate,
    lastDate: lastDate,
    title: 'بداية الفترة الهجرية',
  );
  if (start == null || !context.mounted) return null;
  final end = await _showHijriDatePicker(
    context: context,
    initialDate: initialDateRange.end.isBefore(start)
        ? start
        : initialDateRange.end,
    firstDate: start,
    lastDate: lastDate,
    title: 'نهاية الفترة الهجرية',
  );
  if (end == null) return null;
  return DateTimeRange(start: _day(start), end: _day(end));
}

enum _CalendarMode { hijri, gregorian }

Future<DateTime?> _showHijriDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  required String title,
}) async {
  var selected = _day(initialDate);
  var anchor = _day(initialDate);
  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final month = HijriCalendar.fromDate(anchor);
        final monthStart = anchor.subtract(Duration(days: month.hDay - 1));
        final days = <DateTime>[];
        for (var i = 0; i < 31; i++) {
          final candidate = _day(monthStart.add(Duration(days: i)));
          final hijri = HijriCalendar.fromDate(candidate);
          if (hijri.hYear != month.hYear || hijri.hMonth != month.hMonth) break;
          days.add(candidate);
        }
        final canGoBack = monthStart.isAfter(_day(firstDate));
        final canGoNext = days.isNotEmpty && days.last.isBefore(_day(lastDate));
        final selectedHijri = HijriCalendar.fromDate(selected);
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title),
              const SizedBox(height: 4),
              Text(
                '${selectedHijri.hDay} ${Helpers.getHijriMonthName(selectedHijri.hMonth)} ${selectedHijri.hYear}هـ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'الشهر التالي',
                      onPressed: canGoNext
                          ? () => setState(() => anchor = days.last.add(const Duration(days: 2)))
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                    Expanded(
                      child: Text(
                        '${Helpers.getHijriMonthName(month.hMonth)} ${month.hYear}هـ',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'الشهر السابق',
                      onPressed: canGoBack
                          ? () => setState(() => anchor = monthStart.subtract(const Duration(days: 2)))
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    // Two text lines are rendered in every cell. A slightly
                    // taller cell prevents sub-pixel RenderFlex overflows on
                    // compact Samsung/Android devices and larger text scales.
                    childAspectRatio: 0.84,
                  ),
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final date = days[index];
                    final hijri = HijriCalendar.fromDate(date);
                    final enabled = !date.isBefore(_day(firstDate)) &&
                        !date.isAfter(_day(lastDate));
                    final isSelected = _sameDay(date, selected);
                    return Padding(
                      padding: const EdgeInsets.all(2),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: enabled ? () => setState(() => selected = date) : null,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${hijri.hDay}',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                    color: enabled
                                        ? Theme.of(context).colorScheme.onSurface
                                        : Theme.of(context).disabledColor,
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _weekdayShort(date.weekday),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontSize: 8,
                                        height: 1,
                                        color: enabled
                                            ? Theme.of(context).colorScheme.onSurfaceVariant
                                            : Theme.of(context).disabledColor,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('اعتماد'),
            ),
          ],
        );
      },
    ),
  );
}

String _weekdayShort(int weekday) => switch (weekday) {
      DateTime.monday => 'اث',
      DateTime.tuesday => 'ثل',
      DateTime.wednesday => 'أر',
      DateTime.thursday => 'خم',
      DateTime.friday => 'جم',
      DateTime.saturday => 'سب',
      DateTime.sunday => 'أح',
      _ => '',
    };

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
