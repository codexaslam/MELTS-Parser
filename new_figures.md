# New Figures for MELTS Parser Thesis

## 1. Performance Bar Chart (Mermaid format)

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#a7c1e3', 'secondaryColor': '#f1a3a3', 'tertiaryColor': '#fff'}}}%%
xychart-beta
    title "Performance Benchmark: Local Parser vs. Gemini API (ms)"
    x-axis ["FC", "EC-FF", "FC-FF", "EC", "EM", "EM-FF", "FM"]
    y-axis "Execution Time (ms)" 0 --> 1200
    bar [31, 7, 13, 12, 37, 9, 10]
    bar [1153, 569, 991, 386, 1106, 981, 692]
```

## 2. Sequence Diagram for the Fallback Mechanism (Local First)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant UI as Flutter View
    participant Controller as App Controller
    participant Regex as Local ParserLogic
    participant Gemini as Gemini API

    User->>UI: Uploads MELTS .out file
    UI->>Controller: Triggers Parsing Pipeline
    Controller->>Regex: Executes Deterministic Parsing

    alt Regex Success
        Regex-->>Controller: Returns structured Map/Arrays
    else Parsing Exception or Unwanted Event (e.g., empty row)
        Regex-->>Controller: Throws Exception
        Controller->>Gemini: Triggers Fallback (Zero-shot prompt + raw text)
        Gemini-->>Controller: Async Returns formatted CSV Data
    end

    Controller->>UI: Updates State (setState)
    UI-->>User: Displays structured tabular data
```

## 3. Dart Isolate / Threading Diagram

```mermaid
flowchart TD
    subgraph UI Thread [Main UI Thread]
        A[File Uploaded] --> B["Trigger compute()"]
        F[Receive structured data message] --> G["setState() updates DataTable"]
    end

    subgraph Background Isolate [Memory-Isolated Worker Thread]
        C[Receive raw file bytes] --> D[Execute regex parsing logic]
        D --> E[Serialize into Dart Maps/Arrays]
    end

    B -- Spawns & Passes Data --> C
    E -- Returns Message --> F
```

## 4. State Management Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle: App Launched

    Idle --> Ingesting: User uploads .out file
    Ingesting --> Parsing: File loaded into memory

    Parsing --> UpdatingState: Background parsing completes
    UpdatingState --> DynamicCheckboxes: Extract discovered phases (Spinel, Olivine...)
    DynamicCheckboxes --> RenderPreview: User selects checkboxes
    RenderPreview --> Serializing: User clicks "Save CSV"
    Serializing --> [*]: File saved to disk
```
