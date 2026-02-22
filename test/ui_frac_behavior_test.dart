import 'package:flutter_test/flutter_test.dart';
import 'package:melts_parser/parser_logic.dart';

void main() {
  test('UI shows only base params, parsing auto-adds _frac', () async {
    const sample = '''
**********----------**********
Title: dummy

T = 1208.36 (C)  P = 1.000 (kbars)

clinopyroxene    mass = 2.96 (gm)  density = 3.21 (gm/cc)
           diopside clinoenstatit  hedenbergite
              50.12         21.16         16.72

feldspar         mass = 2.84 (gm)  density = 2.67 (gm/cc)
             albite     anorthite      sanidine
              21.36         78.52          0.12

Summary of all fractionated phases: (total mass = 1.90 grams)

feldspar         mass = 1.90 (gm)  density = 2.67 (gm/cc)
             albite     anorthite      sanidine
              20.28         79.61          0.11

Viscosity of the System: 2.47 (log 10 poise)

System           mass = 100.00 (gm)
**********----------**********
''';

    // Step 1: Analyze to see what's detected
    final detected = await ParserLogic.analyzeFile(sample);

    print('\n=== DETECTED (analyzeFile returns both base and _frac) ===');
    detected.forEach((phase, params) {
      print('$phase: ${params.toList()..sort()}');
    });

    // Step 2: Simulate UI filtering (what app will show to user)
    final uiParams = <String, List<String>>{};
    detected.forEach((phase, params) {
      final base = params.where((p) => !p.endsWith('_frac')).toList()..sort();
      if (base.isNotEmpty) uiParams[phase] = base;
    });

    print('\n=== UI SHOWS (only base params, no _frac) ===');
    uiParams.forEach((phase, params) {
      print('$phase: $params');
    });

    // Step 3: User selects only base tags
    final userSelected = [
      'System.Temperature',
      'Feldspar.mass',
      'Feldspar.albite',
    ];

    print('\n=== USER SELECTS ===');
    print(userSelected);

    // Step 4: Auto-expand with _frac
    final fracAvail = <String, Set<String>>{};
    detected.forEach((phase, params) {
      final fracs = params
          .where((p) => p.endsWith('_frac'))
          .map((p) => p.substring(0, p.length - 5))
          .toSet();
      if (fracs.isNotEmpty) fracAvail[phase] = fracs;
    });

    final expanded = <String>[];
    for (final tag in userSelected) {
      expanded.add(tag);
      final parts = tag.split('.');
      if (parts.length == 2) {
        if (fracAvail[parts[0]]?.contains(parts[1]) ?? false) {
          expanded.add('${parts[0]}.${parts[1]}_frac');
        }
      }
    }

    print('\n=== AUTO-EXPANDED (what gets parsed) ===');
    print(expanded);

    // Step 5: Parse
    final csv = await ParserLogic.parse(sample, expanded);

    print('\n=== CSV ===');
    print(csv);

    final lines = csv.split('\n').where((l) => l.isNotEmpty).toList();
    final header = lines[0].split(',');
    final data = lines[1].split(',');

    print('\n=== COLUMNS ===');
    for (var i = 0; i < header.length; i++) {
      print('${header[i].padRight(25)} = ${data[i]}');
    }

    // Verify
    expect(userSelected.length, 3);
    expect(expanded.length, 5); // 2 auto-added
    expect(header, [
      'System.Temperature',
      'Feldspar.mass',
      'Feldspar.mass_frac',
      'Feldspar.albite',
      'Feldspar.albite_frac',
    ]);
    expect(data[0], '1208.36');
    expect(data[1], '2.84');
    expect(data[2], '1.90');
    expect(data[3], '21.36');
    expect(data[4], '20.28');

    print(
      '\n✓ SUCCESS: User selects base params, CSV has both base and _frac!',
    );
  });
}
