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
      'createdAt': Timestamp.fromDate(createdAt),
    };
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
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
