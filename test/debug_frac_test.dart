import 'package:flutter_test/flutter_test.dart';
import 'package:melts_parser/parser_logic.dart';

void main() {
  test('Debug: Check _frac column behavior with real data', () async {
    const sample = '''
**********----------**********
Title: dummy

T = 1208.36 (C)  P = 1.000 (kbars)

clinopyroxene    mass = 2.96 (gm)  density = 3.21 (gm/cc)
                 G = -48386.42 (J)  H = -37995.88 (J)
           diopside clinoenstatit  hedenbergite
              50.12         21.16         16.72

feldspar         mass = 2.84 (gm)  density = 2.67 (gm/cc)
                 G = -49403.51 (J)  H = -39085.95 (J)
             albite     anorthite      sanidine
              21.36         78.52          0.12

Summary of all fractionated phases: (total mass = 1.90 grams)

feldspar         mass = 1.90 (gm)  density = 2.67 (gm/cc)
                 G = -33087.64 (J)  H = -26183.21 (J)
             albite     anorthite      sanidine
              20.28         79.61          0.11

Viscosity of the System: 2.47 (log 10 poise)

System           mass = 100.00 (gm)  density = 2.73 (gm/cc)

**********----------**********
''';

    final tags = [
      'System.Temperature',
      'Clinopyroxene.mass',
      'Clinopyroxene.mass_frac',
      'Feldspar.mass',
      'Feldspar.mass_frac',
      'Feldspar.albite',
      'Feldspar.albite_frac',
      'Feldspar.anorthite',
      'Feldspar.anorthite_frac',
    ];

    final csv = await ParserLogic.parse(sample, tags);

    print('\n=== CSV OUTPUT ===');
    print(csv);
    print('\n=== PARSED DATA ===');

    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    expect(
      lines.length,
      greaterThanOrEqualTo(2),
      reason: 'Should have header + data rows',
    );

    final header = lines[0].split(',');
    final data = lines[1].split(',');

    print('Header: $header');
    print('Data: $data');
    print('\n=== COLUMN BREAKDOWN ===');

    for (var i = 0; i < header.length && i < data.length; i++) {
      print('${header[i].padRight(30)} = ${data[i]}');
    }

    // Verify expectations
    print('\n=== VERIFICATION ===');

    // Clinopyroxene appears ONLY before "Summary" - so mass goes in normal column, _frac should be empty
    expect(
      data[1],
      '2.96',
      reason: 'Clinopyroxene.mass should be 2.96 (before Summary)',
    );
    expect(
      data[2],
      '',
      reason:
          'Clinopyroxene.mass_frac should be empty (not in fractionated section)',
    );

    // Feldspar appears BOTH before and after "Summary"
    expect(
      data[3],
      '2.84',
      reason: 'Feldspar.mass should be 2.84 (before Summary)',
    );
    expect(
      data[4],
      '1.90',
      reason: 'Feldspar.mass_frac should be 1.90 (in fractionated section)',
    );

    expect(
      data[5],
      '21.36',
      reason: 'Feldspar.albite should be 21.36 (before Summary)',
    );
    expect(
      data[6],
      '20.28',
      reason: 'Feldspar.albite_frac should be 20.28 (in fractionated section)',
    );

    expect(
      data[7],
      '78.52',
      reason: 'Feldspar.anorthite should be 78.52 (before Summary)',
    );
    expect(
      data[8],
      '79.61',
      reason:
          'Feldspar.anorthite_frac should be 79.61 (in fractionated section)',
    );

    print('✓ All verifications passed!');
  });
}
