import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:universal_html/html.dart' as html;
import 'package:universal_io/io.dart';

import 'parser_logic.dart';

void main() {
  runApp(const MyApp());
}

const String geminiApiKey = String.fromEnvironment(
  'GEMINI_API_KEY',
  defaultValue: '',
);

class FileItem {
  final String path;
  final String name;
  final List<int>? bytes;
  bool isSelected;
  FileItem({
    required this.path,
    required this.name,
    this.bytes,
    this.isSelected = false,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MELTS Parser',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          surface: const Color(0xFFF8F9FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FA),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.black87),
          titleTextStyle: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class ParameterGroup {
  final String name;
  final List<String> parameters;
  const ParameterGroup(this.name, this.parameters);
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  _DottedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomePageState extends State<HomePage> {
  static const Map<String, List<String>> _phaseTemplates = {
    'System': [
      'Temperature',
      'Pressure',
      'fO2',
      'viscosity',
      'mass',
      'density',
      'G',
      'H',
      'S',
      'V',
      'Cp',
    ],
    'Liquid': [
      'mass',
      'density',
      'viscosity',
      'SiO2',
      'TiO2',
      'Al2O3',
      'Fe2O3',
      'Cr2O3',
      'FeO',
      'MnO',
      'MgO',
      'NiO',
      'CoO',
      'CaO',
      'Na2O',
      'K2O',
      'P2O5',
      'H2O',
      'CO2',
      'SO3',
      'Cl2O-1',
      'F2O-1',
      'Mg#',
    ],
    'Total Solids': ['mass', 'density', 'G', 'H', 'S', 'V', 'Cp'],
    'Oxygen': ['delta moles', 'delta grams', 'G', 'H', 'S', 'V', 'Cp'],
  };

  String? _folderPath;
  List<FileItem> _filesInFolder = [];

  bool _loading = false;
  String _status = '';
  String _csvPreview = '';
  final List<String> _selectedTags = [];
  List<ParameterGroup> _parameterGroups = [];

  final Map<String, Set<String>> _fracAvailability = {};

  bool _fileAnalyzed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.asset(
                'assets/images/apple-touch-icon.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 12),
            const Text('MELTS Parser'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey.shade200, height: 1),
        ),
      ),
      body: Row(
        children: [
          SizedBox(
            width: 400,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Text(
                          'DATA SOURCE',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildFileZone(),
                        if (_filesInFolder.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _buildFileBrowser(),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PARAMETERS',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.0,
                              ),
                            ),
                            if (_selectedTags.isNotEmpty)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _selectedTags.clear()),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text(
                                  'Clear all',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (!_fileAnalyzed && _filesInFolder.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'Select a folder with .out files to begin',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else if (!_fileAnalyzed &&
                            _getSelectedFiles().isNotEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else
                          ..._parameterGroups.map(_buildParameterGroupCard),
                      ],
                    ),
                  ),
                  // Bottom bar of left panel
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      color: Colors.white,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${_selectedTags.length} parameters selected',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed:
                              (_loading ||
                                  _selectedTags.isEmpty ||
                                  _getSelectedFiles().isEmpty)
                              ? null
                              : _parseAndPreview,
                          icon: _loading
                              ? Container(
                                  width: 20,
                                  height: 20,
                                  padding: const EdgeInsets.all(2),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: Text(
                            _loading ? 'Processing...' : 'Convert to CSV',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Vertical Divider
          Container(width: 1, color: Colors.grey.shade300),
          // RIGHT PANEL: Status & Preview
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FA),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusHeader(),
                  const SizedBox(height: 24),
                  Expanded(child: _buildPreviewArea()),
                  const SizedBox(height: 16),
                  if (_csvPreview.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _saveCsvToDevice(_csvPreview, generateFilename()),
                          icon: const Icon(Icons.download),
                          label: const Text('Save CSV'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String generateFilename() {
    final selected = _getSelectedFiles();
    if (selected.isEmpty) return 'melts_combined.csv';
    if (selected.length == 1) {
      final base = selected.first.name;
      final nameNoExt = base.contains('.') ? base.split('.').first : base;
      final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
      return '$nameNoExt-parsed-$ts.csv';
    }
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'melts_combined-$ts.csv';
  }

  Future<void> pickFiles() async {
    setState(_resetPickState);

    final res = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: kIsWeb, // Required for Web to get file content
    );
    if (res == null || res.files.isEmpty) return;

    final items =
        res.files
            .where((f) => f.path != null || f.bytes != null)
            .map(
              (f) => FileItem(
                path: f.path ?? f.name,
                name: f.name,
                bytes: f.bytes,
                isSelected: true,
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    setState(() {
      _filesInFolder = items;
      _status = '${items.length} file(s) selected';
    });

    await _analyzeSelectedFiles();
  }

  Future<void> pickFolder() async {
    if (kIsWeb) {
      _showSnack(
        'Folder selection is not supported on Web. Please select files directly.',
      );
      return;
    }

    setState(_resetPickState);

    final dir = await FilePicker.platform.getDirectoryPath();
    if (dir == null) return;

    setState(() {
      _folderPath = dir;
      _loading = true;
      _status = 'Scanning folder...';
    });

    try {
      final files = await Directory(dir)
          .list(recursive: false)
          .where((e) => e is File && e.path.toLowerCase().endsWith('.out'))
          .cast<File>()
          .toList();

      if (files.isEmpty) {
        setState(() {
          _loading = false;
          _status = 'No .out files found in folder';
        });
        _showSnack('No .out files found in selected folder');
        return;
      }

      final items =
          files
              .map(
                (f) => FileItem(
                  path: f.path,
                  name: f.path.split(Platform.pathSeparator).last,
                ),
              )
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));

      setState(() {
        _filesInFolder = items;
        _loading = false;
        _status = '${items.length} .out file(s) found';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Error scanning folder: $e';
      });
      _showSnack('Error scanning folder: $e');
    }
  }

  Future<void> _analyzeSelectedFiles() async {
    final selected = _getSelectedFiles();
    if (selected.isEmpty) return;

    setState(() {
      _loading = true;
      _status = 'Analyzing ${selected.length} file(s)...';
      _fileAnalyzed = false;
      _selectedTags.clear();
    });

    try {
      final merged = <String, Set<String>>{};
      for (final item in selected) {
        final text = item.bytes != null
            ? utf8.decode(item.bytes!)
            : await File(item.path).readAsString();
        final detected = await ParserLogic.analyzeFile(text);
        for (final entry in detected.entries) {
          merged.putIfAbsent(entry.key, () => <String>{});
          merged[entry.key]!.addAll(entry.value);
        }
      }

      final groups = <ParameterGroup>[];
      _fracAvailability.clear();

      for (final fixedPhase in ['System', 'Liquid', 'Total Solids', 'Oxygen']) {
        if (_phaseTemplates.containsKey(fixedPhase)) {
          groups.add(ParameterGroup(fixedPhase, _phaseTemplates[fixedPhase]!));

          if (merged.containsKey(fixedPhase)) {
            final fracParams = merged[fixedPhase]!
                .where((p) => p.endsWith('_frac'))
                .map((p) => p.substring(0, p.length - 5))
                .toSet();
            if (fracParams.isNotEmpty) {
              _fracAvailability[fixedPhase] = fracParams;
            }
          }
        }
      }

      final mineralPhases =
          merged.keys.where((k) => !_phaseTemplates.containsKey(k)).toList()
            ..sort();

      for (final phase in mineralPhases) {
        final allParams = merged[phase]!.toList();
        final baseParams = <String>[];
        final fracParams = <String>{};
        for (final param in allParams) {
          if (param.endsWith('_frac')) {
            fracParams.add(param.substring(0, param.length - 5));
          } else {
            baseParams.add(param);
          }
        }
        if (fracParams.isNotEmpty) {
          _fracAvailability[phase] = fracParams;
        }
        baseParams.sort();
        if (baseParams.isNotEmpty) {
          groups.add(ParameterGroup(phase, baseParams));
        }
      }

      setState(() {
        _parameterGroups = groups;
        _fileAnalyzed = true;
        _loading = false;
        _status =
            '${selected.length} file(s) analyzed · ${mineralPhases.length} mineral phases detected';
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _status = 'Analysis failed: $e';
      });
      _showSnack('Failed to analyze files: $e');
    }
  }

  Widget _buildFileBrowser() {
    final selectedCount = _getSelectedFiles().length;
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FILES  (${_filesInFolder.length})',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 1.0,
                  ),
                ),
                Row(
                  children: [
                    if (selectedCount > 0)
                      Text(
                        '$selectedCount selected',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.teal.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    TextButton(
                      onPressed: () {
                        final allSelected = _filesInFolder.every(
                          (f) => f.isSelected,
                        );
                        setState(() {
                          for (final f in _filesInFolder) {
                            f.isSelected = !allSelected;
                          }
                          _fileAnalyzed = false;
                          _parameterGroups.clear();
                        });
                        if (!allSelected) _analyzeSelectedFiles();
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(50, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        _filesInFolder.every((f) => f.isSelected)
                            ? 'Deselect all'
                            : 'Select all',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filesInFolder.length,
              itemBuilder: (context, index) {
                final file = _filesInFolder[index];
                return CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  title: Text(
                    file.name,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: file.isSelected,
                  onChanged: (val) {
                    setState(() {
                      file.isSelected = val ?? false;
                      _fileAnalyzed = false;
                      _parameterGroups.clear();
                    });
                    if (_getSelectedFiles().isNotEmpty) {
                      _analyzeSelectedFiles();
                    }
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileZone() {
    final hasFiles = _filesInFolder.isNotEmpty;
    final label = hasFiles
        ? (_folderPath != null
              ? _folderPath!.split(Platform.pathSeparator).last
              : '${_filesInFolder.length} file(s) selected')
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasFiles ? Colors.teal.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _DottedBorderPainter(
          color: hasFiles ? Colors.teal : Colors.grey.shade400,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                hasFiles
                    ? (_folderPath != null
                          ? Icons.folder_open
                          : Icons.description)
                    : Icons.upload_file,
                size: 36,
                color: hasFiles ? Colors.teal : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              if (hasFiles) ...[
                Text(
                  label!,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.teal.shade800,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_filesInFolder.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_filesInFolder.length} .out file(s)',
                    style: TextStyle(fontSize: 11, color: Colors.teal.shade600),
                  ),
                ],
              ] else
                Text(
                  'Select files or a folder',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: pickFiles,
                    icon: const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 16,
                    ),
                    label: const Text('Files'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: pickFolder,
                    icon: const Icon(Icons.folder_outlined, size: 16),
                    label: const Text('Folder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.teal.shade700,
                      side: BorderSide(color: Colors.teal.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParameterGroupCard(ParameterGroup group) {
    final visibleParams = group.parameters;
    final allSelected = visibleParams.every(
      (p) => _selectedTags.contains('${group.name}.$p'),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  group.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                InkWell(
                  onTap: () {
                    setState(() {
                      if (allSelected) {
                        for (var p in visibleParams) {
                          _selectedTags.remove('${group.name}.$p');
                        }
                      } else {
                        for (var p in visibleParams) {
                          final tag = '${group.name}.$p';
                          if (!_selectedTags.contains(tag)) {
                            _selectedTags.add(tag);
                          }
                        }
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      allSelected ? 'Deselect all' : 'Select all',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visibleParams.map((param) {
                final tag = '${group.name}.$param';
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(param),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  showCheckmark: false,
                  selectedColor: Colors.teal.shade100,
                  side: BorderSide.none,
                  backgroundColor: Colors.grey.shade100,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.teal.shade900 : Colors.black87,
                    fontSize: 12,
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewArea() {
    if (_csvPreview.isEmpty) {
      if (_loading) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome_motion,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'AI is processing your data...',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ],
          ),
        );
      }
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Data Generated Yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Folder → Files → Parameters → Convert',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final parsed = _parseCsvForPreview(_csvPreview);
    if (parsed.isEmpty) {
      return Center(
        child: Text(
          'Generated output is not valid CSV.',
          style: TextStyle(color: Colors.grey.shade500),
        ),
      );
    }

    final header = parsed.first;
    final rows = parsed.length > 1 ? parsed.sublist(1) : const <List<String>>[];
    final previewRows = rows.take(100).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Text(
              'PREVIEW (${rows.length} rows)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(Colors.white),
                  dataRowColor: WidgetStateProperty.all(Colors.white),
                  columnSpacing: 24,
                  columns: header
                      .map(
                        (h) => DataColumn(
                          label: Text(
                            h,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  rows: previewRows.map((row) {
                    final normalized = _normalizeRowLength(row, header.length);
                    return DataRow(
                      cells: normalized
                          .map(
                            (cell) => DataCell(
                              Text(
                                cell,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeader() {
    Widget content;
    if (_loading) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _status.isEmpty ? 'Processing...' : _status,
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else if (_csvPreview.isNotEmpty) {
      content = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Conversion Complete',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      content = Text(
        'Select a folder → pick files → choose parameters → convert.',
        style: TextStyle(color: Colors.grey.shade500),
      );
    }

    return Row(children: [Flexible(child: content)]);
  }

  bool _csvHasDataRows(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return false;

    final dataLines = lines.skip(1).where((l) => l.trim().isNotEmpty).toList();
    return dataLines.isNotEmpty;
  }

  String _escapeCsvCell(String cell) {
    if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
      return '"${cell.replaceAll('"', '""')}"';
    }
    return cell;
  }

  List<String> _expandTagsWithFrac(List<String> selectedTags) {
    final expanded = <String>[];

    for (final tag in selectedTags) {
      expanded.add(tag);

      final parts = tag.split('.');
      if (parts.length == 2) {
        final phase = parts[0];
        final param = parts[1];

        if (_fracAvailability.containsKey(phase) &&
            _fracAvailability[phase]!.contains(param)) {
          expanded.add('$phase.${param}_frac');
        }
      }
    }

    return expanded;
  }

  String? _extractGeminiText(List<dynamic> candidates) {
    for (final candidate in candidates) {
      if (candidate is! Map<String, dynamic>) continue;

      final fromContent = _textFromContent(candidate['content']);
      if (fromContent != null && fromContent.trim().isNotEmpty) {
        return fromContent.trim();
      }

      final direct = candidate['text'];
      if (direct is String && direct.trim().isNotEmpty) {
        return direct.trim();
      }
    }
    return null;
  }

  String _extractRelevantMeltsText(String content, {required int maxChars}) {
    if (content.length <= maxChars) return content;

    final separatorRegex = RegExp(r'\*+[-]+\*+');
    final blocks = content.split(separatorRegex);
    final candidates = blocks
        .where((b) => b.contains('Temperature') && b.trim().isNotEmpty)
        .toList();

    final source = candidates.isNotEmpty ? candidates : blocks;
    final buffer = StringBuffer();
    const joinSep = '\n**********----------**********\n';

    for (final block in source) {
      final next = (buffer.isEmpty ? '' : joinSep) + block.trim();
      if (buffer.length + next.length > maxChars) break;
      buffer.write(next);
    }

    if (buffer.isEmpty) {
      return content.substring(0, maxChars);
    }

    return buffer.toString();
  }

  List<FileItem> _getSelectedFiles() =>
      _filesInFolder.where((f) => f.isSelected).toList();

  Future<String> _invokeGeminiExtract(String content, List<String> tags) async {
    if (geminiApiKey.trim().isEmpty) {
      throw Exception(
        'Missing GEMINI_API_KEY. Run with --dart-define=GEMINI_API_KEY=YOUR_KEY',
      );
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$geminiApiKey',
    );

    final extractedText = _extractRelevantMeltsText(content, maxChars: 50000);

    final prompt =
        '''
  You are a strict CSV generator.

  Task:
  - Parse the MELTS output text and extract columns: ${tags.join(', ')}

  Rules:
  - Output ONLY valid CSV. No markdown, no commentary.
  - First row must be the header exactly equal to the column list above.
  - Each MELTS block corresponds to ONE CSV row.
  - If a value is missing, leave it empty.
  - Ensure each row has exactly ${tags.length} columns.

  MELTS text:
  $extractedText
  ''';

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {'temperature': 0.1},
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode != 200) {
      if (response.statusCode == 429) {
        debugPrint('Gemini 429 Body: ${response.body}');
        throw Exception(
          'Gemini Quota Exceeded (429). Check API key limits for this model.',
        );
      }
      throw Exception(
        'Gemini API Error (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);
    if (!data.containsKey('candidates')) {
      throw Exception('Invalid Gemini response: no candidates');
    }

    final text = _extractGeminiText(data['candidates']);
    if (text == null) throw Exception('No CSV generated from AI');

    final clean = text.replaceAll('```csv', '').replaceAll('```', '').trim();
    if (!_csvHasDataRows(clean)) {
      throw Exception(
        'Gemini returned no data rows. Try local parsing or adjust selected columns.',
      );
    }
    return clean;
  }

  List<String> _normalizeRowLength(List<String> row, int targetLength) {
    if (row.length == targetLength) return row;
    if (row.length > targetLength) return row.sublist(0, targetLength);
    final padded = List<String>.from(row);
    while (padded.length < targetLength) {
      padded.add('');
    }
    return padded;
  }

  Future<void> _parseAndPreview() async {
    final selectedFiles = _getSelectedFiles();
    if (selectedFiles.isEmpty) {
      _showSnack('Select at least one file first.');
      return;
    }
    if (_selectedTags.isEmpty) {
      _showSnack('Select at least one parameter.');
      return;
    }

    final hasGeminiKey = geminiApiKey.trim().isNotEmpty;
    final expandedTags = _expandTagsWithFrac(_selectedTags);

    final headerCols = ['Source File', ...expandedTags];

    setState(() {
      _loading = true;
      _status = 'Parsing ${selectedFiles.length} file(s)...';
      _csvPreview = '';
    });

    try {
      final allRows = <List<String>>[];

      for (var i = 0; i < selectedFiles.length; i++) {
        final item = selectedFiles[i];
        setState(() {
          _status = 'Processing ${i + 1}/${selectedFiles.length}: ${item.name}';
        });

        final text = item.bytes != null
            ? utf8.decode(item.bytes!)
            : await File(item.path).readAsString();

        String csv;
        try {
          csv = await ParserLogic.parse(text, expandedTags);

          final lineCount = const LineSplitter()
              .convert(csv)
              .where((l) => l.trim().isNotEmpty)
              .length;

          if (lineCount <= 1 && hasGeminiKey && selectedFiles.length == 1) {
            debugPrint(
              'ParserLogic returned no data rows for ${item.name}. Falling back to Gemini.',
            );
            setState(
              () =>
                  _status = 'Parsing failed locally, falling back to Gemini...',
            );
            final geminiCsv = await _invokeGeminiExtract(text, expandedTags);
            if (geminiCsv.trim().isNotEmpty) {
              csv = geminiCsv;
            }
          }
        } catch (e) {
          debugPrint('ParserLogic failed for ${item.name}: $e');
          if (hasGeminiKey && selectedFiles.length == 1) {
            setState(
              () =>
                  _status = 'Parsing failed locally, falling back to Gemini...',
            );
            csv = await _invokeGeminiExtract(text, expandedTags);
          } else {
            rethrow;
          }
        }

        final lines = const LineSplitter()
            .convert(csv)
            .where((l) => l.trim().isNotEmpty)
            .toList();

        for (var j = 1; j < lines.length; j++) {
          allRows.add([item.name, ..._parseCsvLine(lines[j])]);
        }
      }

      if (allRows.isEmpty) {
        throw Exception('No rows generated from any selected file.');
      }

      final buf = StringBuffer();
      buf.writeln(headerCols.map(_escapeCsvCell).join(','));
      for (final row in allRows) {
        buf.writeln(row.map(_escapeCsvCell).join(','));
      }

      setState(() {
        _csvPreview = buf.toString();
        _loading = false;
        _status =
            'Done · ${allRows.length} rows from ${selectedFiles.length} file(s)';
      });
    } catch (e, st) {
      debugPrint('ERROR in _parseAndPreview: $e\n$st');
      setState(() {
        _loading = false;
        _status = 'Error: $e';
      });
      _showSnack('Error: $e');
    }
  }

  List<List<String>> _parseCsvForPreview(String csv) {
    final lines = const LineSplitter()
        .convert(csv)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.isEmpty) return const <List<String>>[];

    final rows = <List<String>>[];
    for (final line in lines) {
      rows.add(_parseCsvLine(line));
    }

    if (rows.first.isEmpty) return const <List<String>>[];
    return rows;
  }

  List<String> _parseCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        if (inQuotes) {
          final nextIsQuote = i + 1 < line.length && line[i + 1] == '"';
          if (nextIsQuote) {
            buf.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          inQuotes = true;
        }
        continue;
      }

      if (ch == ',' && !inQuotes) {
        out.add(buf.toString());
        buf.clear();
        continue;
      }

      buf.write(ch);
    }

    out.add(buf.toString());
    return out;
  }

  void _resetPickState() {
    _csvPreview = '';
    _status = '';
    _selectedTags.clear();
    _fileAnalyzed = false;
    _filesInFolder.clear();
    _folderPath = null;
  }

  Future<String> _saveCsvToDevice(String csv, String name) async {
    if (kIsWeb) {
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..style.display = 'none'
        ..download = name;
      html.document.body!.children.add(anchor);
      anchor.click();
      html.document.body!.children.remove(anchor);
      html.Url.revokeObjectUrl(url);
      return name;
    }

    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: name,
      initialDirectory: _folderPath,
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (outputFile == null) {
      throw Exception('Save cancelled');
    }

    final file = File(outputFile);
    await file.writeAsString(csv, flush: true);
    return file.path;
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String? _textFromContent(dynamic content) {
    if (content is Map<String, dynamic>) {
      final text = _textFromParts(content['parts']);
      if (text != null && text.trim().isNotEmpty) {
        return text.trim();
      }
    }

    if (content is List) {
      final buffer = StringBuffer();
      for (final entry in content) {
        final partial = _textFromContent(entry);
        if (partial != null && partial.trim().isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(partial.trim());
        }
      }
      if (buffer.isNotEmpty) {
        return buffer.toString();
      }
    }

    return null;
  }

  String? _textFromParts(dynamic parts) {
    if (parts is! List) return null;
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.trim().isNotEmpty) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.write(text.trim());
        }
      }
    }
    return buffer.isEmpty ? null : buffer.toString();
  }
}
