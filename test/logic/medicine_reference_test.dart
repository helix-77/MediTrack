import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/models/generic_reference.dart';
import 'package:meditrack/models/medicine_reference.dart';

void main() {
  group('MedicineReference Tests', () {
    test('normalizes search name correctly', () {
      expect(
        MedicineReference.normalizeSearchName('  Napa   Extra 500mg  '),
        'napa extra 500mg',
      );
      expect(
        MedicineReference.normalizeSearchName('SECLO-20'),
        'seclo-20',
      );
    });

    test('serializes and deserializes properly from Map', () {
      final now = DateTime.now();
      final med = MedicineReference.fromMap({
        'brandName': 'Napa',
        'genericName': 'Paracetamol',
        'manufacturer': 'Beximco Pharmaceuticals Ltd.',
        'dosageForm': 'Tablet',
        'strength': '500 mg',
        'unitPriceBdt': 1.20,
        'searchName': 'napa',
        'source': 'medex_seed_2026',
        'lastUpdated': now,
      }, id: 'med_123');

      expect(med.id, 'med_123');
      expect(med.brandName, 'Napa');
      expect(med.genericName, 'Paracetamol');
      expect(med.unitPriceBdt, 1.20);
      expect(med.searchName, 'napa');

      final map = med.toMap();
      expect(map['brandName'], 'Napa');
      expect(map['genericName'], 'Paracetamol');
      expect(map['unitPriceBdt'], 1.20);
    });

    test('deserializes properly from SQLite row', () {
      final med = MedicineReference.fromSqlite({
        'id': 4077,
        'brand_name': 'A-Cold',
        'generic_name': 'Bromhexine Hydrochloride',
        'dosage_form': 'Syrup',
        'strength': '4 mg/5 ml',
        'manufacturer': 'ACME Laboratories Ltd.',
        'unit_price': 40.12,
        'search_name': 'a-cold bromhexine hydrochloride',
      });

      expect(med.id, '4077');
      expect(med.brandName, 'A-Cold');
      expect(med.genericName, 'Bromhexine Hydrochloride');
      expect(med.dosageForm, 'Syrup');
      expect(med.strength, '4 mg/5 ml');
      expect(med.manufacturer, 'ACME Laboratories Ltd.');
      expect(med.unitPriceBdt, 40.12);
      expect(med.searchName, 'a-cold bromhexine hydrochloride');
    });

    test('GenericReference deserializes properly from SQLite row', () {
      final generic = GenericReference.fromSqlite({
        'id': 31,
        'generic_name': 'Paracetamol',
        'drug_class': 'Analgesic, Antipyretic',
        'indication': 'Fever, Headache, Toothache',
        'pharmacology_desc': 'Paracetamol has analgesic and antipyretic properties...',
        'dosage_desc': 'Adults: 500 mg to 1 g every 4-6 hours.',
        'side_effects_desc': 'Rarely, hypersensitivity reactions may occur.',
      });

      expect(generic.id, 31);
      expect(generic.genericName, 'Paracetamol');
      expect(generic.drugClass, 'Analgesic, Antipyretic');
      expect(generic.indication, 'Fever, Headache, Toothache');
      expect(generic.pharmacologyDesc, contains('analgesic'));
      expect(generic.dosageDesc, contains('500 mg'));
      expect(generic.sideEffectsDesc, contains('hypersensitivity'));
    });

    test('sorts generic alternatives by price ascending', () {
      final now = DateTime.now();
      final list = [
        MedicineReference(
          id: '1',
          brandName: 'Expensive Paracetamol',
          genericName: 'Paracetamol',
          unitPriceBdt: 3.50,
          searchName: 'expensive paracetamol',
          lastUpdated: now,
        ),
        MedicineReference(
          id: '2',
          brandName: 'Cheapest Paracetamol',
          genericName: 'Paracetamol',
          unitPriceBdt: 0.80,
          searchName: 'cheapest paracetamol',
          lastUpdated: now,
        ),
        MedicineReference(
          id: '3',
          brandName: 'Standard Paracetamol',
          genericName: 'Paracetamol',
          unitPriceBdt: 1.20,
          searchName: 'standard paracetamol',
          lastUpdated: now,
        ),
        MedicineReference(
          id: '4',
          brandName: 'Unknown Price Paracetamol',
          genericName: 'Paracetamol',
          unitPriceBdt: null,
          searchName: 'unknown price paracetamol',
          lastUpdated: now,
        ),
      ];

      list.sort((a, b) {
        if (a.unitPriceBdt == null && b.unitPriceBdt == null) return 0;
        if (a.unitPriceBdt == null) return 1;
        if (b.unitPriceBdt == null) return -1;
        return a.unitPriceBdt!.compareTo(b.unitPriceBdt!);
      });

      expect(list[0].brandName, 'Cheapest Paracetamol');
      expect(list[1].brandName, 'Standard Paracetamol');
      expect(list[2].brandName, 'Expensive Paracetamol');
      expect(list[3].brandName, 'Unknown Price Paracetamol');
    });
  });
}
