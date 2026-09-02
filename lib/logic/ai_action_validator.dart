enum ValidatedActionType { addMedicine, addBuyItem }

class ValidatedMedicineAction {
  final String name;
  final String? dosage;
  final String? frequency;
  final int stock;

  ValidatedMedicineAction({
    required this.name,
    this.dosage,
    this.frequency,
    this.stock = 30,
  });
}

class ValidatedBuyItemAction {
  final String name;
  final int quantity;

  ValidatedBuyItemAction({
    required this.name,
    this.quantity = 1,
  });
}

class ValidatedAiAction {
  final ValidatedActionType type;
  final ValidatedMedicineAction? medicineAction;
  final ValidatedBuyItemAction? buyItemAction;

  ValidatedAiAction.medicine(ValidatedMedicineAction med)
      : type = ValidatedActionType.addMedicine,
        medicineAction = med,
        buyItemAction = null;

  ValidatedAiAction.buyItem(ValidatedBuyItemAction item)
      : type = ValidatedActionType.addBuyItem,
        medicineAction = null,
        buyItemAction = item;
}

class AiActionValidator {
  /// Validates a parsed JSON action map from AI responses.
  /// Returns a [ValidatedAiAction] if the action has valid required fields, or `null` if invalid.
  static ValidatedAiAction? validate(Map<String, dynamic> actionJson) {
    final actionStr = (actionJson['action'] as String?)?.toUpperCase() ?? '';

    if (actionStr == 'ADD_MEDICINE') {
      final name = (actionJson['name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      final dosage = (actionJson['dosage'] as String?)?.trim();
      final frequency = (actionJson['frequency'] as String?)?.trim();

      int stock = 30;
      final rawStock = actionJson['stock'];
      if (rawStock is int && rawStock > 0) {
        stock = rawStock;
      } else if (rawStock is num && rawStock > 0) {
        stock = rawStock.toInt();
      } else if (rawStock is String) {
        final parsed = int.tryParse(rawStock);
        if (parsed != null && parsed > 0) stock = parsed;
      }

      return ValidatedAiAction.medicine(
        ValidatedMedicineAction(
          name: name,
          dosage: dosage?.isNotEmpty == true ? dosage : null,
          frequency: frequency?.isNotEmpty == true ? frequency : null,
          stock: stock,
        ),
      );
    } else if (actionStr == 'ADD_BUY_ITEM') {
      final name = (actionJson['name'] as String? ?? '').trim();
      if (name.isEmpty) return null;

      int quantity = 1;
      final rawQty = actionJson['quantity'];
      if (rawQty is int && rawQty > 0) {
        quantity = rawQty;
      } else if (rawQty is num && rawQty > 0) {
        quantity = rawQty.toInt();
      } else if (rawQty is String) {
        final parsed = int.tryParse(rawQty);
        if (parsed != null && parsed > 0) quantity = parsed;
      }

      return ValidatedAiAction.buyItem(
        ValidatedBuyItemAction(
          name: name,
          quantity: quantity,
        ),
      );
    }

    return null;
  }
}
