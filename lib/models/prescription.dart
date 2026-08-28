import 'package:cloud_firestore/cloud_firestore.dart';

class Prescription {
  final String id;
  final String title;
  final String? doctorName;
  final DateTime date;
  final String? imageUrl;
  final String extractedText;
  final String? notes;
  final String status; // 'draft' | 'reviewed'
  final String? familyMemberId;
  final DateTime createdAt;

  Prescription({
    required this.id,
    required this.title,
    this.doctorName,
    required this.date,
    this.imageUrl,
    required this.extractedText,
    this.notes,
    this.status = 'draft',
    this.familyMemberId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'doctorName': doctorName,
      'date': Timestamp.fromDate(date),
      'imageUrl': imageUrl,
      'extractedText': extractedText,
      'notes': notes,
      'status': status,
      'familyMemberId': familyMemberId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Prescription copyWith({
    String? id,
    String? title,
    String? doctorName,
    DateTime? date,
    String? imageUrl,
    String? extractedText,
    String? notes,
    String? status,
    String? familyMemberId,
    DateTime? createdAt,
  }) {
    return Prescription(
      id: id ?? this.id,
      title: title ?? this.title,
      doctorName: doctorName ?? this.doctorName,
      date: date ?? this.date,
      imageUrl: imageUrl ?? this.imageUrl,
      extractedText: extractedText ?? this.extractedText,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      familyMemberId: familyMemberId ?? this.familyMemberId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Prescription.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return Prescription(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Prescription',
      doctorName: data['doctorName'] as String?,
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      imageUrl: data['imageUrl'] as String?,
      extractedText: data['extractedText'] as String? ?? '',
      notes: data['notes'] as String?,
      status: data['status'] as String? ?? 'draft',
      familyMemberId: data['familyMemberId'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory Prescription.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return Prescription(
      id: id,
      title: data['title'] as String? ?? 'Prescription',
      doctorName: data['doctorName'] as String?,
      date: data['date'] is Timestamp
          ? (data['date'] as Timestamp).toDate()
          : (data['date'] is DateTime
              ? data['date'] as DateTime
              : DateTime.now()),
      imageUrl: data['imageUrl'] as String?,
      extractedText: data['extractedText'] as String? ?? '',
      notes: data['notes'] as String?,
      status: data['status'] as String? ?? 'draft',
      familyMemberId: data['familyMemberId'] as String?,
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : (data['createdAt'] is DateTime
              ? data['createdAt'] as DateTime
              : DateTime.now()),
    );
  }
}
