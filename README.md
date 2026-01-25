# melts_parser

Flutter desktop app to parse MELTS `.out` files into CSV.

## Run

This app calls the Gemini API. Provide your API key at runtime using `--dart-define`:

```bash
flutter run -d macos --dart-define=GEMINI_API_KEY=YOUR_KEY
```

If `GEMINI_API_KEY` is missing/empty, the app will fail with a clear error.
