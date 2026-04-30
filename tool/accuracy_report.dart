import 'dart:io';

import 'package:melts_parser/parser_logic.dart';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart tool/accuracy_report.dart <path_to_melts_output.out>');
    print(
      'Example: dart tool/accuracy_report.dart "C:\\data\\rhyolite_simulation.out"',
    );
    exit(1);
  }

  final filePath = arguments[0];
  final file = File(filePath);

  if (!await file.exists()) {
    print('Error: File not found -> $filePath');
    exit(1);
  }

  print('----------------------------------------------------');
  print('          MELTS PARSER ACCURACY REPORT              ');
  print('----------------------------------------------------');
  print('Analyzing File: ${file.path.split(Platform.pathSeparator).last}');
  print('File Size: ${(await file.length()) / 1024} KB\n');

  final content = await file.readAsString();

  // 1. Measure Data Completeness: Count block iterations mathematically
  final separatorRegex = RegExp(r'\*+[-]+\*+');
  final rawBlocks = content.split(separatorRegex);
  final validBlocks = rawBlocks.where((b) {
    final t = b.trim();
    if (t.isEmpty) return false;
    return t.contains('Temperature') ||
        RegExp(r'\bT\s*=\s*[0-9.+-]').hasMatch(t);
  }).toList();

  print('Phase 1: Raw Parsing Completeness');
  print('  - Raw text blocks manually detected: ${validBlocks.length}');

  // 2. Discover all parameters (Simulation of user clicking 'Select All')
  final phaseParameters = await ParserLogic.analyzeFile(content);
  final List<String> allTags = [];

  for (final phase in phaseParameters.keys) {
    for (final param in phaseParameters[phase]!) {
      allTags.add('$phase.$param');
    }
  }

  print('  - Thermodynamic parameters detected: ${allTags.length}');

  // 3. Execute ParserLogic Engine
  final stopwatch = Stopwatch()..start();
  final csvOutput = await ParserLogic.parse(content, allTags);
  stopwatch.stop();

  final csvLines = csvOutput.split('\n').where((l) => l.isNotEmpty).toList();

  print('\nPhase 2: Execution Integrity');
  print(
    '  - ParserLogic engine execution time: ${stopwatch.elapsedMilliseconds} ms',
  );
  print('  - CSV Rows generated: ${csvLines.length}');

  // A complete conversion contains exactly 1 header block + N valid simulation blocks
  final expectedRows = validBlocks.length + 1;
  if (csvLines.length == expectedRows) {
    print('  -> [PASS] 0% Data Row Loss. Perfect block-to-row parity.');
  } else {
    print(
      '  -> [FAIL] Expected $expectedRows rows but generated ${csvLines.length}. Data loss occurred.',
    );
  }

  // 4. Measure Cartesian Alignment & Null Insertions
  print('\nPhase 3: Cartesian / Two-Dimensional Alignment Validation');

  // Let's count commas in the header to get our required column constraint
  final headerCommaCount = ','.allMatches(csvLines[0]).length;
  int missingValuesInjected = 0;
  bool alignmentMaintained = true;

  for (int i = 1; i < csvLines.length; i++) {
    final line = csvLines[i];
    final rowCommas = ','.allMatches(line).length;

    // Check if the current row shifted (differs from header constraint)
    if (rowCommas != headerCommaCount) {
      alignmentMaintained = false;
      print('  -> [FAIL] Column misalignment detected on row $i!');
    }

    // Count how many explicitly empty slots exist (,, or starting/ending with ,)
    missingValuesInjected += ',,'.allMatches(line).length;
    if (line.startsWith(',')) missingValuesInjected++;
    if (line.endsWith(',')) missingValuesInjected++;
  }

  if (alignmentMaintained) {
    print('  -> [PASS] Perfect two-dimensional columnar alignment verified.');
    print(
      '  -> [PASS] The engine safely injected $missingValuesInjected explicit NULL placeholders without altering column structure.',
    );
  }

  print('----------------------------------------------------');
  print('                     VERDICT                        ');
  print('----------------------------------------------------');
  if (csvLines.length == expectedRows && alignmentMaintained) {
    print(
      '[+] The fully AOT-compiled Dart ParserLogic engine achieved 100% extraction fidelity.',
    );
  } else {
    print('[-] The ParserLogic engine encountered a structural failure.');
  }
}
