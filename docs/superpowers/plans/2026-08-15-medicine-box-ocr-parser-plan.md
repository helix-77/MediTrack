# Medicine-box OCR parser implementation plan

## Objective

Extract the medicine-box OCR heuristics from `AddEditMedicineScreen` into a pure,
package-independent parser while preserving the current review-before-save workflow.

## Steps

1. Add `lib/logic/ocr_parser.dart` with `OcrTextLine`, `MedicineBoxOcrResult`, and
   `MedicineBoxOcrParser.parse`.
   - Accept text plus bounding-box height.
   - Parse expiry/manufacture dates from labeled lines and their immediate successors.
   - Parse batch, `b.no`, and lot values.
   - Select the largest-height safe medicine-name candidate.
   - Reject invalid dates and return null rather than guessing.
2. Add `test/logic/ocr_parser_test.dart` covering supported date formats, invalid dates,
   metadata line handling, batch forms, name selection/ties, and empty/noisy input.
3. Update `lib/screens/add_edit_medicine_screen.dart`.
   - Adapt ML Kit blocks/lines to `OcrTextLine`.
   - Apply parser results only to currently empty fields.
   - Remove inline regex heuristics.
   - Close `TextRecognizer` in `finally`.
   - Rebuild after setting the parsed expiry date.
4. Run the focused parser tests, `flutter analyze`, and the full Flutter test suite.
5. Review the diff to ensure no unrelated files or pre-existing worktree changes were
   altered.

## Files

- Create: `lib/logic/ocr_parser.dart`
- Create: `test/logic/ocr_parser_test.dart`
- Modify: `lib/screens/add_edit_medicine_screen.dart`

## Risk controls

- No dependency changes.
- No Firestore or Firebase changes.
- No automatic OCR persistence.
- Existing manually entered values are never overwritten.
- Manufacture date remains parser output only because the current medicine model has no
  manufacture-date field.
