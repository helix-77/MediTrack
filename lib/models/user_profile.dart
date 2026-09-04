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

  /// Cached BD Apps subscription lifecycle state (e.g. `"REGISTERED"` / `"UNREGISTERED"` / `"PENDING"`).
  final String? subscriptionStatus;

  /// Timestamp when the subscription status was last checked/verified against BD Apps.
  final DateTime? subscriptionVerifiedAt;

  /// Version of the subscription terms/consent agreed to by the user (e.g. `"v1.0"`).
  final String? subscriptionConsentVersion;

  /// Timestamp when the user accepted the subscription terms.
  final DateTime? subscriptionConsentAt;

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
    this.subscriptionStatus,
    this.subscriptionVerifiedAt,
    this.subscriptionConsentVersion,
    this.subscriptionConsentAt,
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? bloodGroup,
    String? allergies,
    String? doctorName,
    String? doctorPhone,
    String? emergencyContactName,
    String? emergencyContactPhone,
    bool? enableDoseReminders,
    bool? enableExpiryAlerts,
    bool? enableLowStockAlerts,
    int? refillAlertDaysBefore,
    int? expiryAlertDaysBefore,
    int? lowStockThreshold,
    String? bdMobile,
    String? subscriptionStatus,
    DateTime? subscriptionVerifiedAt,
    String? subscriptionConsentVersion,
    DateTime? subscriptionConsentAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      doctorName: doctorName ?? this.doctorName,
      doctorPhone: doctorPhone ?? this.doctorPhone,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      enableDoseReminders: enableDoseReminders ?? this.enableDoseReminders,
      enableExpiryAlerts: enableExpiryAlerts ?? this.enableExpiryAlerts,
      enableLowStockAlerts: enableLowStockAlerts ?? this.enableLowStockAlerts,
      refillAlertDaysBefore: refillAlertDaysBefore ?? this.refillAlertDaysBefore,
      expiryAlertDaysBefore: expiryAlertDaysBefore ?? this.expiryAlertDaysBefore,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      bdMobile: bdMobile ?? this.bdMobile,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionVerifiedAt: subscriptionVerifiedAt ?? this.subscriptionVerifiedAt,
      subscriptionConsentVersion: subscriptionConsentVersion ?? this.subscriptionConsentVersion,
      subscriptionConsentAt: subscriptionConsentAt ?? this.subscriptionConsentAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
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
      'subscriptionStatus': subscriptionStatus,
      'subscriptionVerifiedAt': subscriptionVerifiedAt != null
          ? Timestamp.fromDate(subscriptionVerifiedAt!)
          : null,
      'subscriptionConsentVersion': subscriptionConsentVersion,
      'subscriptionConsentAt': subscriptionConsentAt != null
          ? Timestamp.fromDate(subscriptionConsentAt!)
          : null,
    };
  }

  factory UserProfile.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot, {
    String? uid,
  }) {
    final data = snapshot.data() ?? {};
    // Profile documents live at users/{userId}/profile/main.
    // If snapshot.id is 'main', extract real userId from data['uid'] or the parent collection reference.
    final parentUserId = snapshot.reference.parent.parent?.id;
    final resolvedUid = uid ??
        (data['uid'] as String?) ??
        (parentUserId != null && parentUserId.isNotEmpty ? parentUserId : null) ??
        (snapshot.id != 'main' ? snapshot.id : '');
    return UserProfile.fromMap(data, uid: resolvedUid);
  }

  factory UserProfile.fromMap(Map<String, dynamic> data, {String uid = ''}) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return null;
    }

    final resolvedUid = uid.isNotEmpty ? uid : (data['uid'] as String? ?? '');

    return UserProfile(
      uid: resolvedUid,
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
      subscriptionStatus: data['subscriptionStatus'] as String?,
      subscriptionVerifiedAt: parseDate(data['subscriptionVerifiedAt']),
      subscriptionConsentVersion: data['subscriptionConsentVersion'] as String?,
      subscriptionConsentAt: parseDate(data['subscriptionConsentAt']),
    );
  }
}
