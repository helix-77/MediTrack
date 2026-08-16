import 'package:cloud_firestore/cloud_firestore.dart';
import 'medicine_schedule.dart';

class Medicine {
  final String id;
  final String name;
  final String? genericName;
  final String? dosageForm;
  final String? strength;
  final int quantityCurrent;
  final int quantityTotal;
  final DateTime? expiryDate;
  final String? batchNumber;
  final String? manufacturer;
  final String? imageUrl;
  final int lowStockThreshold;
  final String? familyMemberId;
  final MedicineSchedule schedule;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medicine({
    required this.id,
    required this.name,
    this.genericName,
    this.dosageForm,
    this.strength,
    required this.quantityCurrent,
    required this.quantityTotal,
    this.expiryDate,
    this.batchNumber,
    this.manufacturer,
    this.imageUrl,
    this.lowStockThreshold = 5,
    this.familyMemberId,
    required this.schedule,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'genericName': genericName,
      'dosageForm': dosageForm,
      'strength': strength,
      'quantityCurrent': quantityCurrent,
      'quantityTotal': quantityTotal,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'batchNumber': batchNumber,
      'manufacturer': manufacturer,
      'imageUrl': imageUrl,
      'lowStockThreshold': lowStockThreshold,
      'familyMemberId': familyMemberId,
      'schedule': schedule.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Medicine.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Medicine(
      id: doc.id,
      name: data['name'] as String? ?? '',
      genericName: data['genericName'] as String?,
      dosageForm: data['dosageForm'] as String?,
      strength: data['strength'] as String?,
      quantityCurrent: data['quantityCurrent'] as int? ?? 0,
      quantityTotal: data['quantityTotal'] as int? ?? 0,
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      batchNumber: data['batchNumber'] as String?,
      manufacturer: data['manufacturer'] as String?,
      imageUrl: data['imageUrl'] as String?,
      lowStockThreshold: data['lowStockThreshold'] as int? ?? 5,
      familyMemberId: data['familyMemberId'] as String?,
      schedule: MedicineSchedule.fromMap(
        Map<String, dynamic>.from(data['schedule'] ?? {}),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
