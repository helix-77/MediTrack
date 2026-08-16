import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  final String id;
  final String displayName;
  final DateTime createdAt;

  FamilyMember({
    required this.id,
    required this.displayName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory FamilyMember.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return FamilyMember(
      id: snapshot.id,
      displayName: data['displayName'] as String? ?? 'Family Member',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory FamilyMember.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return FamilyMember(
      id: id,
      displayName: data['displayName'] as String? ?? 'Family Member',
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime
              ? data['createdAt'] as DateTime
              : DateTime.now()),
    );
  }
}
