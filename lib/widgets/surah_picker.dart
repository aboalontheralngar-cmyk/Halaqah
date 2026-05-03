import 'package:flutter/material.dart';
import '../utils/quran_data.dart';

class SurahPicker extends StatefulWidget {
  final int? selectedSurahId;
  final List<int>? allowedSurahIds;
  final bool multiSelect;
  final List<int>? selectedSurahIds;
  final Function(int) onSurahSelected;
  final Function(List<int>)? onMultipleSelected;

  const SurahPicker({
    super.key,
    this.selectedSurahId,
    this.allowedSurahIds,
    this.multiSelect = false,
    this.selectedSurahIds,
    required this.onSurahSelected,
    this.onMultipleSelected,
  });

  @override
  State<SurahPicker> createState() => _SurahPickerState();
}

class _SurahPickerState extends State<SurahPicker> {
  String _searchQuery = '';
  List<int> _selectedIds = [];

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.selectedSurahIds ?? [];
  }

  List<Map<String, dynamic>> get _filteredSurahs {
    var surahs = QuranData.surahs;
    
    if (widget.allowedSurahIds != null) {
      surahs = surahs.where((s) => widget.allowedSurahIds!.contains(s['id'])).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      surahs = surahs.where((s) => 
        s['name'].toString().contains(_searchQuery) ||
        s['id'].toString().contains(_searchQuery)
      ).toList();
    }
    
    return surahs;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'ابحث عن سورة...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value);
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredSurahs.length,
            itemBuilder: (context, index) {
              final surah = _filteredSurahs[index];
              final isSelected = widget.multiSelect
                  ? _selectedIds.contains(surah['id'])
                  : widget.selectedSurahId == surah['id'];
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isSelected
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    '${surah['id']}',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  surah['name'],
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                subtitle: Text('${surah['ayahs']} آية - الجزء ${surah['juz']}'),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
                    : null,
                onTap: () {
                  if (widget.multiSelect) {
                    setState(() {
                      if (_selectedIds.contains(surah['id'])) {
                        _selectedIds.remove(surah['id']);
                      } else {
                        _selectedIds.add(surah['id']);
                      }
                    });
                    widget.onMultipleSelected?.call(_selectedIds);
                  } else {
                    widget.onSurahSelected(surah['id']);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class SurahPickerDialog extends StatelessWidget {
  final int? selectedSurahId;
  final List<int>? allowedSurahIds;
  final String title;

  const SurahPickerDialog({
    super.key,
    this.selectedSurahId,
    this.allowedSurahIds,
    this.title = 'اختر السورة',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              title: Text(title),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: SurahPicker(
                selectedSurahId: selectedSurahId,
                allowedSurahIds: allowedSurahIds,
                onSurahSelected: (id) {
                  Navigator.pop(context, id);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<int?> showSurahPicker(
  BuildContext context, {
  int? selectedSurahId,
  List<int>? allowedSurahIds,
  String title = 'اختر السورة',
}) async {
  return showDialog<int>(
    context: context,
    builder: (context) => SurahPickerDialog(
      selectedSurahId: selectedSurahId,
      allowedSurahIds: allowedSurahIds,
      title: title,
    ),
  );
}
