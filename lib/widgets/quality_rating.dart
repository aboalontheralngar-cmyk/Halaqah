import 'package:flutter/material.dart';

class QualityRating extends StatelessWidget {
  final int rating;
  final Function(int)? onRatingChanged;
  final bool readOnly;
  final double size;
  final bool showLabel;

  const QualityRating({
    super.key,
    required this.rating,
    this.onRatingChanged,
    this.readOnly = false,
    this.size = 32,
    this.showLabel = true,
  });

  static const Map<int, String> ratingLabels = {
    5: 'ممتاز',
    4: 'جيد جداً',
    3: 'جيد',
    2: 'مقبول',
    1: 'ضعيف',
  };

  static const Map<int, Color> ratingColors = {
    5: Colors.green,
    4: Colors.lightGreen,
    3: Colors.orange,
    2: Colors.deepOrange,
    1: Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final starRating = index + 1;
            final isSelected = starRating <= rating;
            return GestureDetector(
              onTap: readOnly ? null : () => onRatingChanged?.call(starRating),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  isSelected ? Icons.star : Icons.star_border,
                  color: isSelected ? ratingColors[rating] : Colors.grey[300],
                  size: size,
                ),
              ),
            );
          }),
        ),
        if (showLabel && rating > 0) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: ratingColors[rating]?.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              ratingLabels[rating] ?? '',
              style: TextStyle(
                color: ratingColors[rating],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class QualityRatingSelector extends StatelessWidget {
  final int selectedRating;
  final Function(int) onRatingSelected;

  const QualityRatingSelector({
    super.key,
    required this.selectedRating,
    required this.onRatingSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تقييم الجودة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [5, 4, 3, 2, 1].map((rating) {
            final isSelected = rating == selectedRating;
            final color = QualityRating.ratingColors[rating]!;
            return InkWell(
              onTap: () => onRatingSelected(rating),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? color : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      QualityRating.ratingLabels[rating]!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class QualityBadge extends StatelessWidget {
  final int rating;

  const QualityBadge({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    final color = QualityRating.ratingColors[rating] ?? Colors.grey;
    final label = QualityRating.ratingLabels[rating] ?? 'غير محدد';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
