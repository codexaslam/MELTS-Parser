# Copilot instructions (melts_parser)

## Project overview

- Flutter desktop app that converts MELTS `.out` text into CSV.
- Two parsing paths:
  - **Gemini**: `lib/main.dart` calls `generateContent` and expects strict CSV output.
  - **Local parser (fallback/default)**: `lib/parser_logic.dart` deterministically parses blocks into a CSV.

## Key files

- `lib/main.dart`: UI (desktop two-panel layout), parameter/tag selection, file picking/drag-drop, preview + save, Gemini integration + fallback. **Dynamically builds parameter groups** based on detected phases in the file.
- `lib/parser_logic.dart`: MELTS parsing rules (block splitting, **dynamic phase detection**, key/value + 2-line table parsing). **Handles all 66 possible MELTS mineral phases** without hardcoding - any phase between Liquid and Total Solids is treated as a mineral.
- `test/parser_logic_test.dart`: canonical MELTS text shapes and edge cases (tables, missing viscosity, fractionated summary de-dupe, dynamic phase detection).
- `test/widget_test.dart`: smoke test that the app renders; sets a large window size for desktop layout.

## Developer workflows (macOS)

- Run (Gemini enabled): `flutter run -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY`
- Run (local only): `flutter run -d macos` (Gemini is skipped and local parsing is used)
- Tests: `flutter test`
- Lints: `flutter analyze`

## Project-specific conventions

- **Tag format**: `${Group}.${Param}` (example: `Liquid.SiO2`, `Oxygen.delta moles`).
- **Fixed groups**: `System`, `Liquid`, `Total Solids`, `Oxygen` - these have predefined parameter sets.
- **Dynamic mineral phases**: Any phase between Liquid and Total Solids is automatically detected as a mineral (e.g., Olivine, Clinopyroxene, Feldspar, Spinel, Quartz, etc.). **All 66 possible MELTS mineral phases are supported dynamically** without hardcoding.
- **Phase detection**: Pattern matching on `phasename    mass = ` or `phasename    density = ` lines identifies mineral phases.
- **Parsing behavior** in `ParserLogic._parseBlockToMap`:
  - MELTS blocks are split by the `*+[-]+*+` separator regex.
  - Reads `Temperature/Pressure/fO2/System.viscosity` via multiple patterns (`Temperature:` vs `T =`, `P =`, etc).
  - Parses `key: value`, `key = value`, and 2-line tables (header row then numeric row).
  - Captures **all** values per `(group, key)`. Duplicates (e.g. from immiscible phases or "Summary of all fractionated phases") are joined with a comma (e.g. `0.04, 0.47`).

## When adding a new extracted field

- For **fixed phases** (System, Liquid, Total Solids, Oxygen): Add the parameter to the template map in `main.dart` (`_phaseTemplates`).
- For **mineral phases**: No action needed! The dynamic detection will automatically discover any parameters present in the file.
- Add/extend a focused test in `test/parser_logic_test.dart` using a minimal MELTS snippet if adding new parsing patterns.

## Gemini integration notes

- `GEMINI_API_KEY` is read via `const String.fromEnvironment('GEMINI_API_KEY')`.
- Gemini failures/empty output must fall back to `ParserLogic.parse(...)` (keep this behavior; it’s relied on for offline use and quota errors).
