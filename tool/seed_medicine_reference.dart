import 'dart:convert';
import 'dart:io';

/// Normalizer and seed data generator for Bangladesh medicine reference dataset.
/// Usage: dart run tool/seed_medicine_reference.dart [--output-json <path>] [--dry-run]
void main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  String? outputJsonPath;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--output-json') {
      outputJsonPath = args[i + 1];
    }
  }

  final medicineCsvFile = File('medicine_dataset/medicine.csv');
  if (!medicineCsvFile.existsSync()) {
    stderr.writeln('Error: medicine_dataset/medicine.csv not found.');
    exit(1);
  }

  stdout.writeln('Reading medicine dataset from ${medicineCsvFile.path}...');
  final lines = await medicineCsvFile.readAsLines();
  if (lines.isEmpty) {
    stderr.writeln('Error: CSV file is empty.');
    exit(1);
  }

  final List<Map<String, dynamic>> records = [];
  int validCount = 0;
  int priceExtractedCount = 0;

  // Header: brand id,brand name,type,slug,dosage form,generic,strength,manufacturer,package container,Package Size
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    final columns = _parseCsvLine(line);
    if (columns.length < 8) continue;

    final brandName = columns[1].trim();
    final dosageForm = columns[4].trim();
    final genericName = columns[5].trim();
    final strength = columns[6].trim();
    final manufacturer = columns[7].trim();
    final container = columns.length > 8 ? columns[8].trim() : '';

    if (brandName.isEmpty || genericName.isEmpty) continue;

    final price = _extractPriceBdt(container);
    if (price != null) priceExtractedCount++;

    final record = {
      'brandName': brandName,
      'genericName': genericName,
      'dosageForm': dosageForm.isNotEmpty ? dosageForm : null,
      'strength': strength.isNotEmpty ? strength : null,
      'manufacturer': manufacturer.isNotEmpty ? manufacturer : null,
      'unitPriceBdt': price,
      'searchName': brandName.toLowerCase().replaceAll(RegExp(r'\s+'), ' '),
      'source': 'medex_seed_2026',
      'lastUpdated': DateTime.now().toIso8601String(),
    };

    records.add(record);
    validCount++;
  }

  stdout.writeln('===========================================');
  stdout.writeln('Dataset Validation & Normalization Summary:');
  stdout.writeln('  Total CSV lines: ${lines.length - 1}');
  stdout.writeln('  Valid parsed medicine records: $validCount');
  stdout.writeln('  Records with extracted BDT prices: $priceExtractedCount');
  stdout.writeln('===========================================');

  if (outputJsonPath != null) {
    final outputFile = File(outputJsonPath);
    await outputFile.writeAsString(jsonEncode(records));
    stdout.writeln('Normalized reference data written to: ${outputFile.path}');
  }

  if (dryRun) {
    stdout.writeln('Dry run completed successfully. Zero credentials used.');
  }
}

/// Simple CSV line splitter handling quoted strings with commas.
List<String> _parseCsvLine(String line) {
  final List<String> result = [];
  final buffer = StringBuffer();
  bool inQuotes = false;

  for (var i = 0; i < line.length; i++) {
    final char = line[i];
    if (char == '"') {
      inQuotes = !inQuotes;
    } else if (char == ',' && !inQuotes) {
      result.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(char);
    }
  }
  result.add(buffer.toString());
  return result;
}

/// Extracts unit/pack price in BDT from text like "100 ml bottle: ৳ 40.12"
double? _extractPriceBdt(String containerText) {
  if (containerText.isEmpty) return null;
  final takaRegex = RegExp(r'[৳Tk\.]+\s*([\d\.]+)');
  final match = takaRegex.firstMatch(containerText);
  if (match != null) {
    final priceStr = match.group(1);
    if (priceStr != null) {
      return double.tryParse(priceStr);
    }
  }
  return null;
}
