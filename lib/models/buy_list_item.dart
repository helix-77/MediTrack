import 'package:cloud_firestore/cloud_firestore.dart';

class BuyListItem {
  final String id;
  final String? medicineId;
  final String name;
  final int quantityToBuy;
  final double? estimatedPrice;
  final bool isPurchased;
  final bool isAutoLowStock;
  final int? currentStockAtAdd;
  final String? dosageForm;
  final String? notes;
  final DateTime createdAt;

  BuyListItem({
    required this.id,
    this.medicineId,
    required this.name,
    this.quantityToBuy = 1,
    this.estimatedPrice,
    this.isPurchased = false,
    this.isAutoLowStock = false,
    this.currentStockAtAdd,
    this.dosageForm,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'medicineId': medicineId,
      'name': name,
      'quantityToBuy': quantityToBuy,
      'estimatedPrice': estimatedPrice,
      'isPurchased': isPurchased,
      'isAutoLowStock': isAutoLowStock,
      'currentStockAtAdd': currentStockAtAdd,
      'dosageForm': dosageForm,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BuyListItem.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return BuyListItem(
      id: snapshot.id,
      medicineId: data['medicineId'] as String?,
      name: data['name'] as String? ?? 'Medicine',
      quantityToBuy: data['quantityToBuy'] as int? ?? 1,
      estimatedPrice: (data['estimatedPrice'] as num?)?.toDouble(),
      isPurchased: data['isPurchased'] as bool? ?? false,
      isAutoLowStock: data['isAutoLowStock'] as bool? ?? false,
      currentStockAtAdd: data['currentStockAtAdd'] as int?,
      dosageForm: data['dosageForm'] as String?,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  BuyListItem copyWith({
    String? id,
    String? medicineId,
    String? name,
    int? quantityToBuy,
    double? estimatedPrice,
    bool? isPurchased,
    bool? isAutoLowStock,
    int? currentStockAtAdd,
    String? dosageForm,
    String? notes,
    DateTime? createdAt,
  }) {
    return BuyListItem(
      id: id ?? this.id,
      medicineId: medicineId ?? this.medicineId,
      name: name ?? this.name,
      quantityToBuy: quantityToBuy ?? this.quantityToBuy,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
      isPurchased: isPurchased ?? this.isPurchased,
      isAutoLowStock: isAutoLowStock ?? this.isAutoLowStock,
      currentStockAtAdd: currentStockAtAdd ?? this.currentStockAtAdd,
      dosageForm: dosageForm ?? this.dosageForm,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
