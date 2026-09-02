import '../models/generic_reference.dart';
import '../models/medicine_reference.dart';
import 'medicine_database_service.dart';

class MedicineReferenceService {
  final MedicineDatabaseService _dbService = MedicineDatabaseService();

  /// Searches the medicine reference database by brand or generic name using local SQLite FTS5.
  Future<List<MedicineReference>> searchMedicines(
    String query, {
    int limit = 30,
  }) async {
    return await _dbService.searchMedicines(query, limit: limit);
  }

  /// Finds other brands sharing the same generic name, sorted by price ascending (cheapest first).
  Future<List<MedicineReference>> getAlternativesForGeneric(
    String genericName, {
    String? excludeBrandId,
    int limit = 25,
  }) async {
    return await _dbService.getAlternativesForGeneric(
      genericName,
      excludeBrandId: excludeBrandId,
      limit: limit,
    );
  }

  /// Retrieves full generic details (pharmacology, indications, dosage, side effects).
  Future<GenericReference?> getGenericDetails(String genericName) async {
    return await _dbService.getGenericDetails(genericName);
  }
}
