class ParserLogic {
  static const String blockSeparator = '**********----------**********';

  static final RegExp _separatorRegex = RegExp(r'\*+[-]+\*+');
  static final RegExp _numberRegex = RegExp(
    r'^[+-]?(?:\d+\.?\d*|\d*\.\d+)(?:[eE][+-]?\d+)?$',
  );

  static final RegExp _formulaComponentRegex = RegExp(
    r"(Fe'''|Fe''|[A-Z][a-z]?)([0-9]*\.[0-9]+)",
  );

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

  static Future<String> parse(
    String fileContent,
    List<String> selectedTags,
  ) async {
    final rawBlocks = fileContent.split(_separatorRegex);

    final blocks = rawBlocks.where((b) {
      final t = b.trim();
      if (t.isEmpty) return false;
      return t.contains('Temperature') ||
          RegExp(r'\bT\s*=\s*[0-9.+-]').hasMatch(t);
    }).toList();

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
          final joinedValue = values.join(', ');

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
      if (line.contains('=') || line.contains(':')) return;

      var work = line.trim();

      work = work.replaceFirst(RegExp(r'^[a-z]+\s+', caseSensitive: false), '');

      final open = work.indexOf('(');
      final close = work.indexOf(')');
      if (open != -1 && close != -1 && close > open) {
        work = work.substring(open + 1, close);
      }

      final matches = _formulaComponentRegex.allMatches(work).toList();
      if (matches.length < 2) return;

      for (final m in matches) {
        final rawKey = m.group(1)!;
        final rawVal = m.group(2)!;

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

    String currentSection = 'System'; //

    final fixedSections = {'System', 'Liquid', 'Total Solids', 'Oxygen'};

    String? detectPhase(String line) {
      final lower = line.toLowerCase().trim();

      if (lower.contains('summary of all fractionated')) return null;
      if (lower.contains('constraint flags')) return null;

      if (lower.startsWith('total') && lower.contains('solid')) {
        return 'Total Solids';
      }
      if (lower.startsWith('liquid')) {
        return 'Liquid';
      }
      if (lower.startsWith('oxygen')) {
        return 'Oxygen';
      }
      if (lower.startsWith('system') && lower.contains('mass')) {
        return 'System';
      }
      if (lower.startsWith('viscosity of the system')) return null;

      // Handles all 66 possible MELTS mineral phases dynamically
      final phaseMatch = RegExp(
        r'^([a-z][\w\s-]+?)\s{2,}(mass|density)\s*=',
        caseSensitive: false,
      ).firstMatch(line);

      if (phaseMatch != null) {
        var phaseName = phaseMatch.group(1)!.trim();

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

      if (inFractionatedSummary &&
          ((lower.startsWith('system') && lower.contains('mass')) ||
              lower.startsWith('oxygen'))) {
        inFractionatedSummary = false;
      }

      final detectedPhase = detectPhase(line);
      if (detectedPhase != null) {
        currentSection = detectedPhase;
      }

      final addFunc = inFractionatedSummary ? addFrac : add;

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

      if (!fixedSections.contains(currentSection)) {
        parseFormulaLineIntoCurrentSection(
          line,
          currentSection,
          inFractionatedSummary,
        );
      }

      if (lower.startsWith('wt%')) {
        final colonIdx = line.indexOf(':');
        final after = colonIdx >= 0 ? line.substring(colonIdx + 1) : line;
        for (final m in RegExp(
          r'([A-Za-z][A-Za-z0-9]*(?:[0-9])?[A-Za-z0-9]*)\s+([0-9.+-]+(?:[eE][+-]?[0-9]+)?)',
        ).allMatches(after)) {
          addFunc(currentSection, m.group(1)!, m.group(2)!);
        }
        continue;
      }
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

      for (final m in RegExp(
        r'([A-Za-z0-9.#+-]+)\s*=\s*([0-9.+-]+(?:[eE][+-]?[0-9]+)?)',
      ).allMatches(line)) {
        addFunc(currentSection, m.group(1)!, m.group(2)!);
      }

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

          if (count >= 3) {
            for (var k = 0; k < count; k++) {
              final header = headerTokens[k];
              final value = valueTokens[k];
              addFunc(currentSection, header, value);

              final h = header.toLowerCase();
              if (h == 'forsterite') addFunc(currentSection, 'Fo', value);
              if (h == 'fayalite') addFunc(currentSection, 'Fa', value);
            }
            i++;
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
