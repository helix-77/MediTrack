import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? bloodGroup;
  final String? allergies;
  final String? doctorName;
  final String? doctorPhone;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final bool enableDoseReminders;
  final bool enableExpiryAlerts;
  final bool enableLowStockAlerts;
  final int refillAlertDaysBefore;
  final int expiryAlertDaysBefore;
  final int lowStockThreshold;

  /// BD-format mobile number used as the `subscriberId` for BD Apps
  /// SMS / subscription actions. Nullable so Firebase-only users can
  /// still use the rest of the app without linking one. When set,
  /// expected to match `^01[3-9][0-9]{8}$` (mirrors the validation in
  /// the PHP backend).
  final String? bdMobile;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.bloodGroup,
    this.allergies,
    this.doctorName,
    this.doctorPhone,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.enableDoseReminders = true,
    this.enableExpiryAlerts = true,
    this.enableLowStockAlerts = true,
    this.refillAlertDaysBefore = 3,
    this.expiryAlertDaysBefore = 30,
    this.lowStockThreshold = 5,
    this.bdMobile,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'email': email,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'doctorName': doctorName,
      'doctorPhone': doctorPhone,
      'emergencyContactName': emergencyContactName,
      'emergencyContactPhone': emergencyContactPhone,
      'enableDoseReminders': enableDoseReminders,
      'enableExpiryAlerts': enableExpiryAlerts,
      'enableLowStockAlerts': enableLowStockAlerts,
      'refillAlertDaysBefore': refillAlertDaysBefore,
      'expiryAlertDaysBefore': expiryAlertDaysBefore,
      'lowStockThreshold': lowStockThreshold,
      'bdMobile': bdMobile,
    };
  }

  factory UserProfile.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return UserProfile(
      uid: snapshot.id,
      displayName: data['displayName'] as String? ?? 'User',
      email: data['email'] as String? ?? '',
      bloodGroup: data['bloodGroup'] as String?,
      allergies: data['allergies'] as String?,
      doctorName: data['doctorName'] as String?,
      doctorPhone: data['doctorPhone'] as String?,
      emergencyContactName: data['emergencyContactName'] as String?,
      emergencyContactPhone: data['emergencyContactPhone'] as String?,
      enableDoseReminders: data['enableDoseReminders'] as bool? ?? true,
      enableExpiryAlerts: data['enableExpiryAlerts'] as bool? ?? true,
      enableLowStockAlerts: data['enableLowStockAlerts'] as bool? ?? true,
      refillAlertDaysBefore: (data['refillAlertDaysBefore'] as num?)?.toInt() ?? 3,
      expiryAlertDaysBefore: (data['expiryAlertDaysBefore'] as num?)?.toInt() ?? 30,
      lowStockThreshold: (data['lowStockThreshold'] as num?)?.toInt() ?? 5,
      bdMobile: data['bdMobile'] as String?,
    );
  }
}
