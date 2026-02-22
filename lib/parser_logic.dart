class ParserLogic {
  static const String blockSeparator = '**********----------**********';

  static final RegExp _separatorRegex = RegExp(r'\*+[-]+\*+');
  static final RegExp _numberRegex = RegExp(
    r'^[+-]?(?:\d+\.?\d*|\d*\.\d+)(?:[eE][+-]?\d+)?$',
  );

  // Parses mineral-style formula segments like:
  //   (Ca0.01Mg0.25Fe''0.63Mn0.12...)2SiO4
  //   cpx Na0.02Ca0.74Fe''0.58Mg0.53Fe'''0.09Ti0.01...
  // Only matches decimal values to avoid mis-parsing oxide headers (e.g. Al2O3).
  static final RegExp _formulaComponentRegex = RegExp(
    r"(Fe'''|Fe''|[A-Z][a-z]?)([0-9]*\.[0-9]+)",
  );

  /// Analyzes the MELTS file and returns detected phases with their parameters
  static Future<Map<String, Set<String>>> analyzeFile(
    String fileContent,
  ) async {
    final rawBlocks = fileContent.split(_separatorRegex);
    final blocks = rawBlocks.where((b) {
      final t = b.trim();
      if (t.isEmpty) return false;
      return t.contains('Temperature') ||
          RegExp(r'\bT\s*=\s*[0-9.+-]').hasMatch(t);
    }).toList();

    final phaseParameters = <String, Set<String>>{};

    for (var block in blocks) {
      final parsed = _parseBlockToMap(block);
      for (var entry in parsed.entries) {
        final phase = entry.key;
        final params = entry.value.keys;

        phaseParameters.putIfAbsent(phase, () => <String>{});
        phaseParameters[phase]!.addAll(params);
      }
    }

    return phaseParameters;
  }

  /// Main entry point to parse the MELTS file content.
  static Future<String> parse(
    String fileContent,
    List<String> selectedTags,
  ) async {
    // 1. Split into blocks
    // Using a regex to handle potential variations in the separator line
    final rawBlocks = fileContent.split(_separatorRegex);

    // 2. Filter valid blocks
    // MELTS output varies: some use "Temperature:", others use "T =".
    final blocks = rawBlocks.where((b) {
      final t = b.trim();
      if (t.isEmpty) return false;
      return t.contains('Temperature') ||
          RegExp(r'\bT\s*=\s*[0-9.+-]').hasMatch(t);
    }).toList();

    // 3. Process
    final rows = <String>[];
    rows.add(selectedTags.join(',')); // Header

    for (var block in blocks) {
      final parsed = _parseBlockToMap(block);
      final row = <String>[];

      for (var tag in selectedTags) {
        final parts = tag.split('.');
        if (parts.length < 2) {
          row.add('');
          continue;
        }
        final group = parts[0];
        final param = parts[1];

        // Retrieve values
        List<String> values = [];

        if (parsed.containsKey(group) && parsed[group]!.containsKey(param)) {
          values = parsed[group]![param]!;
        } else {
          // Fallback: sometimes "Liquid.Mass" is under "System.Liquid" or something, but strict is better.
        }

        if (values.isEmpty) {
          row.add('');
        } else {
          // Join multiple values with comma+space (e.g. "0.04, 32.57")
          final joinedValue = values.join(', ');
          // If the value contains a comma, wrap in quotes for proper CSV format
          if (joinedValue.contains(',')) {
            row.add('"$joinedValue"');
          } else {
            row.add(joinedValue);
          }
        }
      }
      rows.add(row.join(','));
    }

    return rows.join('\n');
  }

  static Map<String, Map<String, List<String>>> _parseBlockToMap(String block) {
    final data = <String, Map<String, List<String>>>{};

    void add(String group, String key, String val) {
      if (val.trim().isEmpty) return;
      data.putIfAbsent(group, () => {});
      data[group]!.putIfAbsent(key, () => []);

      data[group]![key]!.add(val.trim());
    }

    void addFrac(String group, String key, String val) {
      if (val.trim().isEmpty) return;
      final fracKey = '${key}_frac';
      data.putIfAbsent(group, () => {});
      data[group]!.putIfAbsent(fracKey, () => []);

      data[group]![fracKey]!.add(val.trim());
    }

    final lines = block.split('\n');

    void parseFormulaLineIntoCurrentSection(
      String line,
      String currentSection,
      bool isFromFractionated,
    ) {
      // Skip obviously non-formula lines.
      if (line.contains('=') || line.contains(':')) return;

      var work = line.trim();
      // Strip common prefixes like "cpx".
      work = work.replaceFirst(RegExp(r'^[a-z]+\s+', caseSensitive: false), '');

      // If wrapped in parentheses, only parse the parentheses content.
      final open = work.indexOf('(');
      final close = work.indexOf(')');
      if (open != -1 && close != -1 && close > open) {
        work = work.substring(open + 1, close);
      }

      final matches = _formulaComponentRegex.allMatches(work).toList();
      if (matches.length < 2) return; // avoid false positives

      for (final m in matches) {
        final rawKey = m.group(1)!;
        final rawVal = m.group(2)!;

        // Don't store oxygen atom counts (not part of UI tags).
        if (rawKey == 'O') continue;

        final key = switch (rawKey) {
          "Fe''" => 'Fe2+',
          "Fe'''" => 'Fe3+',
          _ => rawKey,
        };
        if (isFromFractionated) {
          addFrac(currentSection, key, rawVal);
        } else {
          add(currentSection, key, rawVal);
        }
      }
    }

    // Support both "Temperature:" and "T =" styles.
    final tempMatch1 = RegExp(
      r'Temperature\s*:\s*([0-9.+-]+)',
    ).firstMatch(block);
    if (tempMatch1 != null) add('System', 'Temperature', tempMatch1.group(1)!);
    final tempMatch2 = RegExp(r'\bT\s*=\s*([0-9.+-]+)').firstMatch(block);
    if (tempMatch2 != null) add('System', 'Temperature', tempMatch2.group(1)!);

    final pressMatch1 = RegExp(r'Pressure\s*:\s*([0-9.+-]+)').firstMatch(block);
    if (pressMatch1 != null) add('System', 'Pressure', pressMatch1.group(1)!);
    final pressMatch2 = RegExp(r'\bP\s*=\s*([0-9.+-]+)').firstMatch(block);
    if (pressMatch2 != null) add('System', 'Pressure', pressMatch2.group(1)!);

    // log fO2 variations
    final fo2Match1 = RegExp(r'log\s*fO2\s*:\s*([0-9.+-]+)').firstMatch(block);
    if (fo2Match1 != null) add('System', 'fO2', fo2Match1.group(1)!);
    final fo2Match2 = RegExp(
      r'log\(10\)\s*f\s*O2\s*=\s*([0-9.+-]+)',
      caseSensitive: false,
    ).firstMatch(block);
    if (fo2Match2 != null) add('System', 'fO2', fo2Match2.group(1)!);

    final viscosityMatch = RegExp(
      r'Viscosity\s+of\s+the\s+System\s*:\s*([0-9.+-]+)',
      caseSensitive: false,
    ).firstMatch(block);
    if (viscosityMatch != null) {
      add('System', 'viscosity', viscosityMatch.group(1)!);
    }
    // Some runs print: "Viscosity of the System cannot be computed."
    // In that case we intentionally leave System.viscosity empty.

    // --- State Machine for Sections ---
    String currentSection = 'System'; // Default to System context

    // Fixed sections that don't represent mineral phases
    final fixedSections = {'System', 'Liquid', 'Total Solids', 'Oxygen'};

    // Helper to detect and normalize phase names
    String? detectPhase(String line) {
      final lower = line.toLowerCase().trim();

      // Skip summary section headers
      if (lower.contains('summary of all fractionated')) return null;
      if (lower.contains('constraint flags')) return null;

      // Check fixed sections first (these are NOT mineral phases)
      if (lower.startsWith('total') && lower.contains('solid'))
        return 'Total Solids';
      if (lower.startsWith('liquid')) return 'Liquid';
      if (lower.startsWith('oxygen')) return 'Oxygen';
      if (lower.startsWith('system') && lower.contains('mass')) return 'System';
      if (lower.startsWith('viscosity of the system'))
        return null; // Not a phase header

      // Pattern for mineral phases: "phasename    mass = " or "phasename    density = "
      // This matches ANY mineral name followed by properties
      // Handles all 66 possible MELTS mineral phases dynamically
      final phaseMatch = RegExp(
        r'^([a-z][\w\s-]+?)\s{2,}(mass|density)\s*=',
        caseSensitive: false,
      ).firstMatch(line);

      if (phaseMatch != null) {
        var phaseName = phaseMatch.group(1)!.trim();

        // Skip if it looks like a section we already handled
        if (phaseName.toLowerCase() == 'title') return null;
        if (phaseName.toLowerCase() == 't') return null;

        // Capitalize first letter of each word for consistency
        phaseName = phaseName
            .split(' ')
            .map((word) {
              if (word.isEmpty) return word;
              return word[0].toUpperCase() + word.substring(1).toLowerCase();
            })
            .join(' ');

        // This is a mineral phase!
        return phaseName;
      }

      return null;
    }

    bool inFractionatedSummary = false;

    for (var i = 0; i < lines.length; i++) {
      var line = lines[i].trim();
      if (line.isEmpty) continue;

      final lower = line.toLowerCase();
      if (lower.contains('summary of all fractionated phases')) {
        inFractionatedSummary = true;
        continue;
      }

      // The summary section ends before system/oxygen/viscosity reporting.
      if (inFractionatedSummary &&
          (lower.startsWith('viscosity of the system') ||
              lower.startsWith('system') ||
              lower.startsWith('oxygen') ||
              lower.startsWith('total solids') ||
              lower.startsWith('liquid'))) {
        inFractionatedSummary = false;
      }

      // 1. Check for Section Change
      final detectedPhase = detectPhase(line);
      if (detectedPhase != null) {
        currentSection = detectedPhase;
      }

      // If the line is a phase/property line, keep parsing it (don't continue).

      // 2. Data Extraction

      // Determine which add function to use based on fractionated summary status
      final addFunc = inFractionatedSummary ? addFrac : add;

      // A. Oxygen keys contain spaces; handle explicitly.
      final oxygenMoles = RegExp(
        r'delta\s+moles\s*=\s*([0-9.eE+-]+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (oxygenMoles != null) {
        addFunc('Oxygen', 'delta moles', oxygenMoles.group(1)!);
      }
      final oxygenGrams = RegExp(
        r'delta\s+grams\s*=\s*([0-9.eE+-]+)',
        caseSensitive: false,
      ).firstMatch(line);
      if (oxygenGrams != null) {
        addFunc('Oxygen', 'delta grams', oxygenGrams.group(1)!);
      }

      // A2. Mineral formula lines (e.g., cpx Na0.02Ca0.74..., (Ca0.01Mg0.25Fe''0.63...)2SiO4)
      // Parse formula for ANY mineral phase (anything not in fixedSections)
      // This handles all 66 possible MELTS mineral phases dynamically
      if (!fixedSections.contains(currentSection)) {
        parseFormulaLineIntoCurrentSection(
          line,
          currentSection,
          inFractionatedSummary,
        );
      }

      // B. "Key: Value" pattern (older style)
      final colonMatch = RegExp(
        r'^([A-Za-z0-9.#+-]+)\s*:\s*([0-9.+-]+(?:[eE][+-]?[0-9]+)?)',
      ).firstMatch(line);
      if (colonMatch != null) {
        final key = colonMatch.group(1)!;
        final val = colonMatch.group(2)!;
        if (!(currentSection == 'System' &&
            (key == 'Temperature' || key == 'Pressure'))) {
          addFunc(currentSection, key, val);
        }
        continue;
      }

      // C. "key = value" assignments (common in your sample)
      for (final m in RegExp(
        r'([A-Za-z0-9.#+-]+)\s*=\s*([0-9.+-]+(?:[eE][+-]?[0-9]+)?)',
      ).allMatches(line)) {
        addFunc(currentSection, m.group(1)!, m.group(2)!);
      }

      // D. Two-line tables: headers on one line, numeric values on the next.
      if (i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        final headerTokens = _splitTokens(line);
        final valueTokens = _splitTokens(nextLine);

        final headerLooksLikeNames =
            headerTokens.length >= 3 &&
            headerTokens.every((t) => !_numberRegex.hasMatch(t));
        final valuesLookNumeric =
            valueTokens.length >= 3 &&
            valueTokens.every((t) => _numberRegex.hasMatch(t));

        if (headerLooksLikeNames && valuesLookNumeric) {
          final count = headerTokens.length < valueTokens.length
              ? headerTokens.length
              : valueTokens.length;

          // Many MELTS tables are 3+ columns (e.g., albite/anorthite/sanidine).
          if (count >= 3) {
            for (var k = 0; k < count; k++) {
              final header = headerTokens[k];
              final value = valueTokens[k];
              addFunc(currentSection, header, value);

              // Dynamic aliases for common end-members (works for any mineral phase)
              final h = header.toLowerCase();
              if (h == 'forsterite') addFunc(currentSection, 'Fo', value);
              if (h == 'fayalite') addFunc(currentSection, 'Fa', value);
            }
            i++; // Consume value line
            continue;
          }
        }
      }
    }

    return data;
  }

  static List<String> _splitTokens(String line) {
    return line
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
  }
}
