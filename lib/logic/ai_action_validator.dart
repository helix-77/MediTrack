enum ValidatedActionType {
  addMedicine,
  updateMedicine,
  deleteMedicine,
  addBuyItem,
  updateBuyItem,
  deleteBuyItem,
}

class ValidatedMedicineAction {
  final String name;
  final String? dosage;
  final String? frequency;
  final int stock;
  final String? medicineId;

  ValidatedMedicineAction({
    required this.name,
    this.dosage,
    this.frequency,
    this.stock = 30,
    this.medicineId,
  });
}

class ValidatedBuyItemAction {
  final String name;
  final int quantity;
  final String? itemId;

  ValidatedBuyItemAction({
    required this.name,
    this.quantity = 1,
    this.itemId,
  });
}

class ValidatedAiAction {
  final ValidatedActionType type;
  final ValidatedMedicineAction? medicineAction;
  final ValidatedBuyItemAction? buyItemAction;
  final Map<String, dynamic> data;

  ValidatedAiAction.medicine(ValidatedMedicineAction med, {Map<String, dynamic>? raw})
      : type = ValidatedActionType.addMedicine,
        medicineAction = med,
        buyItemAction = null,
        data = raw ?? {};

  ValidatedAiAction.buyItem(ValidatedBuyItemAction item, {Map<String, dynamic>? raw})
      : type = ValidatedActionType.addBuyItem,
        medicineAction = null,
        buyItemAction = item,
        data = raw ?? {};

  ValidatedAiAction.generic(this.type, this.data)
      : medicineAction = null,
        buyItemAction = null;
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
        raw: actionJson,
      );
    } else if (actionStr == 'UPDATE_MEDICINE') {
      final name = (actionJson['name'] as String? ?? '').trim();
      final medicineId = (actionJson['medicineId'] as String? ?? '').trim();
      if (name.isEmpty && medicineId.isEmpty) return null;

      return ValidatedAiAction.generic(
        ValidatedActionType.updateMedicine,
        actionJson,
      );
    } else if (actionStr == 'DELETE_MEDICINE') {
      final name = (actionJson['name'] as String? ?? '').trim();
      final medicineId = (actionJson['medicineId'] as String? ?? '').trim();
      if (name.isEmpty && medicineId.isEmpty) return null;

      return ValidatedAiAction.generic(
        ValidatedActionType.deleteMedicine,
        actionJson,
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
        raw: actionJson,
      );
    } else if (actionStr == 'UPDATE_BUY_ITEM') {
      final name = (actionJson['name'] as String? ?? '').trim();
      final itemId = (actionJson['itemId'] as String? ?? '').trim();
      if (name.isEmpty && itemId.isEmpty) return null;

      return ValidatedAiAction.generic(
        ValidatedActionType.updateBuyItem,
        actionJson,
      );
    } else if (actionStr == 'DELETE_BUY_ITEM') {
      final name = (actionJson['name'] as String? ?? '').trim();
      final itemId = (actionJson['itemId'] as String? ?? '').trim();
      if (name.isEmpty && itemId.isEmpty) return null;

      return ValidatedAiAction.generic(
        ValidatedActionType.deleteBuyItem,
        actionJson,
      );
    }

    return null;
  }
}
