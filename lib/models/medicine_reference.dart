import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineReference {
  final String id;
  final String brandName;
  final String genericName;
  final String? manufacturer;
  final String? dosageForm;
  final String? strength;
  final double? unitPriceBdt;
  final String searchName; // lower-case normalized name for prefix queries
  final String source; // e.g. "medex_seed_2026"
  final DateTime lastUpdated;

  MedicineReference({
    required this.id,
    required this.brandName,
    required this.genericName,
    this.manufacturer,
    this.dosageForm,
    this.strength,
    this.unitPriceBdt,
    required this.searchName,
    this.source = 'medex_seed_2026',
    required this.lastUpdated,
  });

  static String normalizeSearchName(String brandName) {
    return brandName.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Map<String, dynamic> toMap() {
    return {
      'brandName': brandName,
      'genericName': genericName,
      'manufacturer': manufacturer,
      'dosageForm': dosageForm,
      'strength': strength,
      'unitPriceBdt': unitPriceBdt,
      'searchName': searchName,
      'source': source,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  factory MedicineReference.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};
    return MedicineReference(
      id: snapshot.id,
      brandName: data['brandName'] as String? ?? '',
      genericName: data['genericName'] as String? ?? '',
      manufacturer: data['manufacturer'] as String?,
      dosageForm: data['dosageForm'] as String?,
      strength: data['strength'] as String?,
      unitPriceBdt: (data['unitPriceBdt'] as num?)?.toDouble(),
      searchName: data['searchName'] as String? ?? '',
      source: data['source'] as String? ?? 'medex_seed_2026',
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory MedicineReference.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return MedicineReference(
      id: id,
      brandName: data['brandName'] as String? ?? '',
      genericName: data['genericName'] as String? ?? '',
      manufacturer: data['manufacturer'] as String?,
      dosageForm: data['dosageForm'] as String?,
      strength: data['strength'] as String?,
      unitPriceBdt: (data['unitPriceBdt'] as num?)?.toDouble(),
      searchName: data['searchName'] as String? ??
          normalizeSearchName(data['brandName'] as String? ?? ''),
      source: data['source'] as String? ?? 'medex_seed_2026',
      lastUpdated: data['lastUpdated'] is Timestamp
          ? (data['lastUpdated'] as Timestamp).toDate()
          : (data['lastUpdated'] is DateTime
              ? data['lastUpdated'] as DateTime
              : DateTime.now()),
    );
  }
}
