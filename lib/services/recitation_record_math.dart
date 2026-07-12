class RecitationRecordMath {
  const RecitationRecordMath._();

  static int adjustMemorizedTotal({
    required int currentTotal,
    required int previousTrackedCount,
    required int currentTrackedCount,
    int maximum = 6236,
  }) {
    return (currentTotal + currentTrackedCount - previousTrackedCount)
        .clamp(0, maximum)
        .toInt();
  }
}
