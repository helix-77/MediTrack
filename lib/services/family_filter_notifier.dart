import 'package:flutter/material.dart';

class FamilyFilterNotifier extends ChangeNotifier {
  // 'self' for current user/Myself, or familyMember.id for a specific member
  String _selectedMemberId = 'self';

  String get selectedMemberId => _selectedMemberId;
  bool get isSelf => _selectedMemberId == 'self';

  /// Returns null for 'self' (which matches familyMemberId == null in Medicine/Prescription models)
  /// or returns the actual family member ID string.
  String? get currentFamilyMemberId =>
      _selectedMemberId == 'self' ? null : _selectedMemberId;

  void selectMember(String memberId) {
    if (_selectedMemberId != memberId) {
      _selectedMemberId = memberId;
      notifyListeners();
    }
  }

  void selectSelf() {
    selectMember('self');
  }
}
