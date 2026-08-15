/// Prevents two memorization entry routes from being active for the same
/// student at the same time. This is especially important when a QR scan and
/// the regular memorization screen are opened almost simultaneously.
class RecitationFlowCoordinator {
  RecitationFlowCoordinator._();

  static final Map<String, Object> _owners = <String, Object>{};

  static bool acquire(String studentId, Object owner) {
    final currentOwner = _owners[studentId];
    if (currentOwner != null && !identical(currentOwner, owner)) return false;
    _owners[studentId] = owner;
    return true;
  }

  static void release(String studentId, Object owner) {
    if (identical(_owners[studentId], owner)) {
      _owners.remove(studentId);
    }
  }
}
