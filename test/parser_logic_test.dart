import 'package:flutter_test/flutter_test.dart';
import 'package:melts_parser/parser_logic.dart';

void main() {
  test('ParserLogic parses sample MELTS block (T=/P=/tables)', () async {
    const sample = '''
**********----------**********
Title: dummy

T = 1208.36 (C)  P = 1.000 (kbars)  log(10) f O2 = -8.13  delta HM = -5.52  NNO = -0.67  QFM = 0.00  COH = 2.19  IW = 3.51

Liquid           mass = 92.29 (gm)  density = 2.72 (gm/cc)  viscosity = 2.34 (log 10 poise)     (analysis in wt %)
        G = -1479164.64 (J)  H = -1115606.48 (J)
        SiO2   TiO2  Al2O3  Fe2O3  Cr2O3    FeO    MnO    MgO    NiO    CoO    CaO   Na2O    K2O   P2O5    H2O    CO2    SO3 Cl2O-1  F2O-1
       50.38   1.17  14.41   1.82   0.00   9.16   0.20   8.19   0.00   0.00  12.46   1.92   0.18   0.11   0.00   0.00   0.00   0.00   0.00

clinopyroxene    mass = 2.96 (gm)  density = 3.21 (gm/cc)
           diopside clinoenstatit  hedenbergite alumino-buffo     buffonite      essenite       jadeite
              50.12         21.16         16.72          7.11         -5.82          9.65          1.06

Oxygen           delta moles = -1.64025e-05  delta grams = -0.000524861

**********----------**********
''';

    final tags = <String>[
      'System.Temperature',
      'System.Pressure',
      'System.fO2',
      'Liquid.mass',
      'Liquid.SiO2',
      'Clinopyroxene.diopside',
      'Oxygen.delta moles',
      'Oxygen.delta grams',
    ];

    final csv = await ParserLogic.parse(sample, tags);
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();

    // header + at least one row
    expect(lines.length, greaterThanOrEqualTo(2));

    final header = lines.first;
    expect(header, tags.join(','));

    final row = lines[1];
    expect(row, contains('1208.36'));
    expect(row, contains('1.000'));
    expect(row, contains('-8.13'));
    expect(row, contains('92.29'));
    expect(row, contains('50.38'));
    expect(row, contains('50.12'));
    expect(row, contains('-1.64025e-05'));
    expect(row, contains('-0.000524861'));
  });

  test(
    'ParserLogic parses liquid/system/oxygen block (real-file shape)',
    () async {
      const sample = '''
**********----------**********
Title: dummy

T = 1218.36 (C)  P = 1.000 (kbars)  log(10) f O2 = -8.02  delta HM = -5.51  NNO = -0.67  QFM = 0.00  COH = 2.20  IW = 3.50

Liquid           mass = 100.00 (gm)  density = 2.71 (gm/cc)  viscosity = 2.32 (log 10 poise)     (analysis in wt %)
        G = -1612710.39 (J)  H = -1214563.89 (J)
        SiO2   TiO2  Al2O3  Fe2O3  Cr2O3    FeO    MnO    MgO    NiO    CoO    CaO   Na2O    K2O   P2O5    H2O    CO2    SO3 Cl2O-1  F2O-1
       50.33   1.08  14.99   1.73   0.00   8.61   0.18   8.07   0.00   0.00  12.85   1.89   0.16   0.10   0.00   0.00   0.00   0.00   0.00

Viscosity of the System: 2.32 (log 10 poise)

System           mass = 100.00 (gm)  density = 2.71 (gm/cc)
                 G = -1612710.39 (J)  H = -1214563.89 (J)

Oxygen           delta moles = 4.94396e-17  delta grams = 1.58201e-15

**********----------**********
''';

      final tags = <String>[
        'System.Temperature',
        'System.Pressure',
        'System.fO2',
        'System.viscosity',
        'System.mass',
        'Liquid.mass',
        'Liquid.viscosity',
        'Liquid.SiO2',
        'Liquid.Cl2O-1',
        'Oxygen.delta moles',
        'Oxygen.delta grams',
      ];

      final csv = await ParserLogic.parse(sample, tags);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();

      expect(lines.length, greaterThanOrEqualTo(2));
      expect(lines.first, tags.join(','));

      final row = lines[1];
      expect(row, contains('1218.36'));
      expect(row, contains('1.000'));
      expect(row, contains('-8.02'));
      expect(row, contains('2.32'));
      expect(row, contains('100.00'));
      expect(row, contains('50.33'));
      expect(row, contains('4.94396e-17'));
      expect(row, contains('1.58201e-15'));
    },
  );

  test('ParserLogic parses 3-column tables and missing viscosity', () async {
    const sample = '''
**********----------**********
Title: dummy

T = 1003.36 (C)  P = 1.000 (kbars)  log(10) f O2 = -10.77

feldspar         mass = 0.12 (gm)  density = 2.60 (gm/cc)     (analysis in mole %)
             albite     anorthite      sanidine
              61.45         36.88          1.67

Viscosity of the System cannot be computed.

System           mass = 100.09 (gm)  density = 2.97 (gm/cc)

Oxygen           delta moles = 0.00289129  delta grams = 0.0925178

**********----------**********
''';

    final tags = <String>[
      'System.Temperature',
      'System.Pressure',
      'System.fO2',
      'System.viscosity',
      'Feldspar.mass',
      'Feldspar.albite',
      'Feldspar.anorthite',
      'Feldspar.sanidine',
      'Oxygen.delta moles',
      'Oxygen.delta grams',
    ];

    final csv = await ParserLogic.parse(sample, tags);
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();

    expect(lines.length, greaterThanOrEqualTo(2));
    expect(lines.first, tags.join(','));

    final row = lines[1];
    expect(row, contains('1003.36'));
    expect(row, contains('1.000'));
    expect(row, contains('-10.77'));
    // viscosity is intentionally empty when it cannot be computed
    expect(row, isNot(contains('cannot be computed')));

    expect(row, contains('0.12'));
    expect(row, contains('61.45'));
    expect(row, contains('36.88'));
    expect(row, contains('1.67'));

    expect(row, contains('0.00289129'));
    expect(row, contains('0.0925178'));
  });

  test('ParserLogic separates duplicates into _frac columns', () async {
    const sample = '''
**********----------**********
Title: dummy

T = 1003.36 (C)  P = 1.000 (kbars)  log(10) f O2 = -10.77

olivine          mass = 0.04 (gm)  density = 4.04 (gm/cc)     (analysis in mole %)
                 G = -413.35 (J)  H = -306.21 (J)

Summary of all fractionated phases: (total mass = 90.48 grams)

olivine          mass = 0.47 (gm)  density = 3.99 (gm/cc)     (analysis in mole %)
                 G = -4859.21 (J)  H = -3627.75 (J)

Viscosity of the System cannot be computed.

System           mass = 100.09 (gm)  density = 2.97 (gm/cc)

**********----------**********
''';

    final tags = <String>[
      'System.Temperature',
      'Olivine.mass',
      'Olivine.mass_frac',
      'Olivine.density',
      'Olivine.density_frac',
      'Olivine.H',
      'Olivine.H_frac',
      'System.mass',
    ];

    final csv = await ParserLogic.parse(sample, tags);
    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    expect(lines.length, greaterThanOrEqualTo(2));

    final row = lines[1];
    expect(row, contains('1003.36'));

    // Original columns contain only values from before "Summary of all fractionated phases"
    final parts = row.split(',');
    expect(parts[1], '0.04'); // Olivine.mass
    expect(parts[2], '0.47'); // Olivine.mass_frac
    expect(parts[3], '4.04'); // Olivine.density
    expect(parts[4], '3.99'); // Olivine.density_frac
    expect(parts[5], '-306.21'); // Olivine.H
    expect(parts[6], '-3627.75'); // Olivine.H_frac
  });

  test(
    'ParserLogic stores olivine from fractionated summary in _frac columns when missing above',
    () async {
      const sample = '''
**********----------**********
Title: dummy

T = 1003.36 (C)  P = 1.000 (kbars)  log(10) f O2 = -10.77

Summary of all fractionated phases: (total mass = 90.48 grams)

olivine          mass = 0.47 (gm)  density = 3.99 (gm/cc)     (analysis in mole %)
                 G = -4859.21 (J)  H = -3627.75 (J)

System           mass = 100.09 (gm)  density = 2.97 (gm/cc)

**********----------**********
''';

      final tags = <String>[
        'System.Temperature',
        'Olivine.mass',
        'Olivine.mass_frac',
        'Olivine.density',
        'Olivine.density_frac',
        'Olivine.H',
        'Olivine.H_frac',
      ];

      final csv = await ParserLogic.parse(sample, tags);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, greaterThanOrEqualTo(2));

      final row = lines[1];
      expect(row, contains('1003.36'));

      // Normal columns should be empty, _frac columns should have the values
      final parts = row.split(',');
      expect(parts[1], ''); // Olivine.mass - empty
      expect(parts[2], '0.47'); // Olivine.mass_frac
      expect(parts[3], ''); // Olivine.density - empty
      expect(parts[4], '3.99'); // Olivine.density_frac
      expect(parts[5], ''); // Olivine.H - empty
      expect(parts[6], '-3627.75'); // Olivine.H_frac
    },
  );

  test('ParserLogic dynamically detects all phases in file', () async {
    const sample = '''
**********----------**********
Title: dummy

T = 1208.36 (C)  P = 1.000 (kbars)  log(10) f O2 = -8.13

Liquid           mass = 92.29 (gm)  density = 2.72 (gm/cc)

clinopyroxene    mass = 2.96 (gm)  density = 3.21 (gm/cc)
           diopside clinoenstatit  hedenbergite
              50.12         21.16         16.72

feldspar         mass = 2.84 (gm)  density = 2.67 (gm/cc)
             albite     anorthite      sanidine
              21.36         78.52          0.12

quartz           mass = 1.50 (gm)  density = 2.65 (gm/cc)
                 G = -1000.00 (J)  H = -800.00 (J)

Total solids     mass = 7.30 (gm)  density = 2.80 (gm/cc)

System           mass = 100.00 (gm)  density = 2.73 (gm/cc)

Oxygen           delta moles = -1.64025e-05  delta grams = -0.000524861

**********----------**********
''';

    final detected = await ParserLogic.analyzeFile(sample);

    expect(detected.keys, contains('System'));
    expect(detected.keys, contains('Liquid'));
    expect(detected.keys, contains('Clinopyroxene'));
    expect(detected.keys, contains('Feldspar'));
    expect(detected.keys, contains('Quartz'));
    expect(detected.keys, contains('Total Solids'));
    expect(detected.keys, contains('Oxygen'));

    // Check that Clinopyroxene has expected parameters
    expect(detected['Clinopyroxene'], contains('mass'));
    expect(detected['Clinopyroxene'], contains('density'));
    expect(detected['Clinopyroxene'], contains('diopside'));

    // Check that Quartz was detected with its parameters
    expect(detected['Quartz'], contains('mass'));
    expect(detected['Quartz'], contains('G'));
    expect(detected['Quartz'], contains('H'));
  });

  test(
    'ParserLogic captures multiple occurrences of same mineral in one block',
    () async {
      const sample = '''
**********----------**********
Title: dummy

T = 1003.36 (C)  P = 1.000 (kbars)  log(10) f O2 = -10.77

whitlockite      mass = 0.01 (gm)  density = 3.18 (gm/cc)
                 G = -106.09 (J)  H = -86.14 (J)  S = 0.02 (J/K)  V = 0.00 (cc)  Cp = 0.01 (J/K)  

clinopyroxene    mass = 2.96 (gm)  density = 3.21 (gm/cc)
                 G = -48386.42 (J)  H = -37995.88 (J)  S = 7.01 (J/K)  V = 0.92 (cc)  Cp = 3.55 (J/K)  
           diopside clinoenstatit  hedenbergite
              50.12         21.16         16.72

Total solids     mass = 5.80 (gm)  density = 2.92 (gm/cc)

Summary of all fractionated phases: (total mass = 90.48 grams)

clinopyroxene    mass = 32.57 (gm)  density = 3.28 (gm/cc)
                 G = -503227.48 (J)  H = -412101.41 (J)  S = 71.39 (J/K)  V = 9.92 (cc)  Cp = 37.98 (J/K)  
           diopside clinoenstatit  hedenbergite
              31.02         28.26         28.04

whitlockite      mass = 0.01 (gm)  density = 3.18 (gm/cc)
                 G = -136.11 (J)  H = -110.52 (J)  S = 0.02 (J/K)  V = 0.00 (cc)  Cp = 0.01 (J/K)  

System           mass = 100.09 (gm)  density = 2.97 (gm/cc)

**********----------**********
''';

      final tags = <String>[
        'System.Temperature',
        'Clinopyroxene.mass',
        'Clinopyroxene.mass_frac',
        'Clinopyroxene.Cp',
        'Clinopyroxene.Cp_frac',
        'Clinopyroxene.diopside',
        'Clinopyroxene.diopside_frac',
        'Whitlockite.mass',
        'Whitlockite.mass_frac',
        'Whitlockite.Cp',
        'Whitlockite.Cp_frac',
      ];

      final csv = await ParserLogic.parse(sample, tags);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, greaterThanOrEqualTo(2));

      final row = lines[1];
      final parts = row.split(',');

      // Clinopyroxene values should be separated
      expect(parts[1], '2.96'); // Clinopyroxene.mass
      expect(parts[2], '32.57'); // Clinopyroxene.mass_frac
      expect(parts[3], '3.55'); // Clinopyroxene.Cp
      expect(parts[4], '37.98'); // Clinopyroxene.Cp_frac
      expect(parts[5], '50.12'); // Clinopyroxene.diopside
      expect(parts[6], '31.02'); // Clinopyroxene.diopside_frac

      // Whitlockite values should be separated
      expect(parts[7], '0.01'); // Whitlockite.mass
      expect(parts[8], '0.01'); // Whitlockite.mass_frac
      expect(parts[9], '0.01'); // Whitlockite.Cp
      expect(parts[10], '0.01'); // Whitlockite.Cp_frac
    },
  );
}
