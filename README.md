# MELTS Parser

A Flutter desktop application designed to easily parse and convert MELTS `.out` text files into structured CSV formats.

The app features two parsing routes:

- **Local parser (Default)**: Deterministically parses MELTS data blocks into structured CSV data. It handles all 66 possible MELTS mineral phases dynamically without hardcoding.
- **Gemini AI parser(Fallback)**: Leverages the Gemini API for intelligent text-to-CSV extraction.

## Features

- **Dual-Pane Interface**: Desktop layout with parameter/tag selection, file upload, and preview + save functionalities.
- **Dynamic Phase Detection**: Automatically identifies and extracts data for any mineral phase (for example: Olivine, Clinopyroxene, Spinel) present in the text output.
- **Robust Parsing**: Extracts standard fixed groups (System, Liquid, Total Solids, Oxygen) and correctly handles duplicate parameters and inline multi-line tables.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- Desktop development enabled for your OS:
  - **macOS**: run `flutter config --enable-macos-desktop`
  - **Windows**: run `flutter config --enable-windows-desktop`

### Running the App

You can run the application with or without Gemini AI integration.

**1. Run local parser only (Offline)**
If you want to use the default robust local parser, simply run:

```bash
# For macOS
flutter run -d macos

# For Windows
flutter run -d windows
```

**2. Run with Gemini integration**
To enable the Gemini API parsing path, provide your API key at runtime using `--dart-define`:

```bash
# For macOS
flutter run -d macos --dart-define=GEMINI_API_KEY=YOUR_API_KEY

# For Windows
flutter run -d windows --dart-define=GEMINI_API_KEY=YOUR_API_KEY
```

_Note: If the Gemini parser fails, encounters quota errors, or if the API key is missing, the app automatically falls back to the reliable local parser logic._

### Testing & Linting

To run the unit and widget tests:

```bash
flutter test
```

To run the static code analyzer:

```bash
flutter analyze
```
