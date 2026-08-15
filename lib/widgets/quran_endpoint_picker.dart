import 'package:flutter/material.dart';

import '../services/quran_service.dart';
import 'surah_picker.dart';

class QuranEndpoint {
  const QuranEndpoint({required this.surahId, required this.ayah});

  final int surahId;
  final int ayah;
}

Future<QuranEndpoint?> showQuranEndpointPicker(
  BuildContext context, {
  required int initialSurahId,
  int initialAyah = 1,
  String title = 'اختر نهاية النطاق',
}) async {
  final quran = QuranService.instance;
  await quran.initialize();
  if (!context.mounted) return null;
  final surahId = await showSurahPicker(
    context,
    selectedSurahId: initialSurahId,
  );
  if (surahId == null || !context.mounted) return null;
  final surah = quran.getSurah(surahId);
  if (surah == null) return null;
  var ayah = initialAyah.clamp(1, surah.totalAyahs).toInt();
  final selected = await showDialog<int>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('$title — سورة ${surah.name}'),
        content: DropdownButtonFormField<int>(
          initialValue: ayah,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'الآية',
            border: OutlineInputBorder(),
          ),
          items: List.generate(
            surah.totalAyahs,
            (index) => DropdownMenuItem(
              value: index + 1,
              child: Text('الآية ${index + 1}'),
            ),
          ),
          onChanged: (value) {
            if (value != null) setDialogState(() => ayah = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, ayah),
            child: const Text('اختيار'),
          ),
        ],
      ),
    ),
  );
  return selected == null ? null : QuranEndpoint(surahId: surahId, ayah: selected);
}
