# Medicine-box OCR parser design

## Status

Approved design for the first implementation slice of the MediTrack OCR roadmap.

## Goal

Extract the medicine-box OCR heuristics currently embedded in
`lib/screens/add_edit_medicine_screen.dart` into a deterministic, pure, unit-testable
parser. This slice improves the existing printed-label scan without starting the larger
cloud prescription-OCR rebuild.

## Scope

In scope:

- A package-independent OCR input model containing recognized text and bounding-box
  height.
- A pure parser for medicine name, expiry date, manufacture date, and batch number.
- Conservative date and batch validation.
- Integration into `AddEditMedicineScreen` without changing its form or persistence model.
- Unit tests that run without camera, Firebase, platform channels, or ML Kit runtime.
- Safe ML Kit recognizer cleanup when image processing fails.

Out of scope:

- Prescription OCR or Gemini/Firebase AI Logic changes.
- Firestore, Firebase Storage, notification, or model schema changes.
- Brand-name lookup, spelling correction, generic-name inference, dosage interpretation,
  or automatic saving.
- A custom camera UI.

## Alternatives considered

### Structured parser only
The parser would accept ML Kit objects directly. This is concise but couples business
logic to the OCR package and makes pure tests less portable.

### Domain input adapter plus pure parser — selected
The screen adapts ML Kit lines to an app-owned `OcrTextLine` type. The parser depends only
on that type. This preserves bounding-box information while keeping parsing logic
platform-independent and easy to test.

### Parser directly over `RecognizedText`
The parser would inspect ML Kit blocks and lines internally. This is the fastest short-term
implementation but makes the domain layer dependent on ML Kit and harder to reuse.

## Architecture and data flow

```text
ML Kit RecognizedText
        |
        | screen-layer adapter
        v
List<OcrTextLine>
        |
        | MedicineBoxOcrParser.parse
        v
MedicineBoxOcrResult
        |
        | apply only to empty form fields
        v
AddEditMedicineScreen controllers
```

`lib/logic/ocr_parser.dart` will define:

- `OcrTextLine`: recognized text and bounding-box height only; the first implementation does not need positional metadata.
- `MedicineBoxOcrResult`: nullable name candidate, expiry date, manufacture date, batch
  number, and no business side effects.
- `MedicineBoxOcrParser.parse(List<OcrTextLine>)`.

The parser will not import Flutter, ML Kit, Firebase, or any other platform/API package.

## Parsing rules

### Dates

Expiry labels are `exp`, `expiry`, `exp date`, and `use before`. Manufacture labels are
`mfg`, `manufactured`, and `mfd`.

For each label, inspect the labeled OCR line and the immediately following OCR line. Use
the first valid date match in that window. Supported formats are:

- `DD/MM/YYYY`
- `DD-MM-YYYY`
- `MM/YYYY`
- `MM-YYYY`

Full dates become a `DateTime` with the captured day, month, and year. Month-only dates
become the first day of that month. Invalid calendar dates are rejected instead of being
allowed to roll over through Dart `DateTime` normalization. `/` and `-` are equivalent
separators.

Dates are not accepted from arbitrary unrelated lines, preventing dosage numbers or
unrelated dates from becoming an expiry value.

### Batch number

Recognize `batch`, `b.no`, and `lot`, with optional `:` or `.` punctuation. Capture the
first non-whitespace alphanumeric/hyphen token after the label. Ignore empty or
punctuation-only values.

### Medicine name candidate

- Ignore blank lines.
- Ignore lines containing recognized metadata labels.
- Ignore lines that are only a supported date or batch value.
- Choose the remaining line with the greatest bounding-box height.
- On ties, preserve OCR order.
- Return `null` if there is no safe candidate.

Preserve original candidate and batch casing/spacing except for trimming. Do not perform
lookup, correction, or inference.

## Screen integration

`AddEditMedicineScreen._scanBoxPhoto()` will retain camera selection, ML Kit invocation,
loading state, error feedback, and the existing review-before-save behavior.

After recognition, it will adapt ML Kit blocks/lines to `OcrTextLine` instances and call the
pure parser. It will then apply results non-destructively:

- Fill name only if the name field is empty.
- Fill batch only if the batch field is empty.
- Set expiry only if no expiry is already selected.
- Preserve manufacture date in the parser result, but do not write it to the form because
  the current `Medicine` model has no manufacture-date field.
- Never auto-save an OCR result.

The inline `_applyOcrHeuristics` method will be removed. The recognizer will be closed in a
`finally` block so failures do not leak the ML Kit resource.

## Failure handling

- Camera cancellation: no-op.
- Recognition exception: show the existing error SnackBar and leave form values unchanged.
- Successful scan with no useful fields: show the review prompt without fabricated values.
- Parser failure or invalid individual value: treat that value as absent; do not crash or
  overwrite existing user input.
- No OCR text or metadata is logged or sent to a network service.

## Testing strategy

Create `test/logic/ocr_parser_test.dart` using direct `OcrTextLine` fixtures. Tests will
cover:

- All supported full-date and month-only formats.
- Expiry/manufacture labels on the same line and on the next line.
- Invalid dates and unrelated dates.
- Batch, `b.no`, and lot forms.
- Largest-height name selection and deterministic ties.
- Exclusion of metadata/date/batch lines from name selection.
- Empty and noisy OCR input.

Screen-level behavior will be validated by static analysis and the existing test suite; the
pure parser tests provide the regression protection for the extracted logic without
requiring platform setup.

## Validation

Run:

```bash
flutter test test/logic/ocr_parser_test.dart
flutter analyze
flutter test
```

The implementation is limited to:

```text
lib/logic/ocr_parser.dart
lib/screens/add_edit_medicine_screen.dart
test/logic/ocr_parser_test.dart
```

No dependency or Firebase configuration changes are expected.
