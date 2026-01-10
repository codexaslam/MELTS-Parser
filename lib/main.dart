import 'dart:convert';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

/// IMPORTANT: Replace with your API key
/// Get free Gemini API key from: https://aistudio.google.com/app/apikey
// const String geminiApiKey = 'AIzaSyCWs5WLLHWeZ4lTZCEsLPv8wevk1aKZuZ0';
const String geminiApiKey = 'AIzaSyDTCh2ak9Kp7_gG09ZOxkS6eZOA69rKzPc';

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

    // Fallback to solid line for simplicity as 'path_drawing' is not available
    // but the request was to look modern, a solid clean border is better than a broken one.
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomePageState extends State<HomePage> {
  String? _filePath;
  String? _fileName;
  bool _loading = false;
  bool _isDragging = false;
  String _status = '';
  String _csvPreview = '';
  final List<String> _selectedTags = [];

  final List<ParameterGroup> _parameterGroups = [
    ParameterGroup('System', [
      'Temperature',
      'Pressure',
      'fO2',
      'viscosity',
      'mass',
      'density',
      'G',
      'H',
    ]),
    ParameterGroup('Liquid', [
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
    ]),
    ParameterGroup('Olivine', [
      'mass',
      'density',
      'Mg',
      'Fe2+',
      'Fo',
      'G',
      'H',
    ]),
    ParameterGroup('Clinopyroxene', [
      'mass',
      'density',
      'Na',
      'Ca',
      'Fe2+',
      'Mg',
      'diopside',
      'buffonite',
      'G',
      'H',
    ]),
    ParameterGroup('Feldspar', [
      'mass',
      'density',
      'K',
      'Na',
      'Ca',
      'Al',
      'albite',
      'anorthite',
      'G',
      'H',
    ]),
    ParameterGroup('Total Solids', ['mass', 'density', 'G', 'H']),
    ParameterGroup('Oxygen', ['delta moles', 'delta grams', 'G']),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.science, color: Colors.teal, size: 20),
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
          // LEFT PANEL: Configurations (Input & Parameters)
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
                        const SizedBox(height: 32),
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
                                  _filePath == null)
                              ? null
                              : _parseAndSaveCsv,
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

  // --- Logic Helpers ---

  String generateFilename() {
    final base = _fileName ?? 'melts_input';
    final nameNoExt = base.contains('.') ? base.split('.').first : base;
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return '$nameNoExt-parsed-$timestamp.csv';
  }

  Future<void> pickFile() async {
    setState(() {
      _csvPreview = '';
      _status = '';
    });
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    if (res == null || res.files.isEmpty) return;
    final path = res.files.single.path;
    if (path == null) return;
    setState(() {
      _filePath = path;
      _fileName = res.files.single.name;
    });
  }

  Widget _buildFileZone() {
    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isNotEmpty) {
          final file = detail.files.first;
          setState(() {
            _filePath = file.path;
            _fileName = file.name;
            _csvPreview = '';
            _status = '';
          });
        }
      },
      onDragEntered: (detail) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (detail) {
        setState(() {
          _isDragging = false;
        });
      },
      child: InkWell(
        onTap: pickFile,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: _isDragging
                ? Colors.teal.shade100
                : (_filePath != null ? Colors.teal.shade50 : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isDragging
                  ? Colors.teal
                  : (_filePath != null ? Colors.teal : Colors.grey.shade300),
              style: BorderStyle.none,
              width: 1,
            ),
          ),
          child: CustomPaint(
            painter: _DottedBorderPainter(
              color: _isDragging
                  ? Colors.teal
                  : (_filePath != null ? Colors.teal : Colors.grey.shade400),
            ),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Icon(
                    _isDragging
                        ? Icons.file_download
                        : (_filePath != null
                              ? Icons.description
                              : Icons.upload_file),
                    size: 40,
                    color: _isDragging
                        ? Colors.teal
                        : (_filePath != null
                              ? Colors.teal
                              : Colors.grey.shade400),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fileName ?? 'Drag & Drop or Click to select .out file',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isDragging
                          ? Colors.teal.shade800
                          : (_filePath != null
                                ? Colors.teal.shade800
                                : Colors.grey.shade600),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_filePath != null && !_isDragging) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ready to process',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
              'Select file > Select params > Convert',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final lines = _csvPreview.split('\n');
    final header = lines.first.split(',');
    final rows = lines.skip(1).map((l) => l.split(',')).toList();
    final previewRows = rows.take(100).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              'PREVIEW (${lines.length - 1} rows)',
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
                    return DataRow(
                      cells: row
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
    return Row(
      children: [
        if (_loading)
          Container(
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
                Text(
                  _status.isEmpty ? 'Processing...' : _status,
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else if (_csvPreview.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  'Conversion Complete',
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            'To get started, select a file and parameters.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
      ],
    );
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

  Future<String> _invokeGeminiExtract(String text, List<String> tags) async {
    // Using gemini-2.5-flash-lite
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$geminiApiKey',
    );

    // Split text into blocks based on the MELTS separator
    // The separator is a sequence of asterisks, dashes, and asterisks.
    // We use a regex to handle varying lengths of these characters.
    final separatorRegex = RegExp(r'\*+[-]+\*+');
    final blocks = text.split(separatorRegex);
    final validBlocks = blocks.where((b) => b.trim().isNotEmpty).toList();

    // Process in chunks of blocks
    // 10 blocks per chunk is safe for token limits and context
    const blocksPerChunk = 10;
    final processedLines = <String>[];

    for (var i = 0; i < validBlocks.length; i += blocksPerChunk) {
      final end = (i + blocksPerChunk < validBlocks.length)
          ? i + blocksPerChunk
          : validBlocks.length;
      final chunkBlocks = validBlocks.sublist(i, end);

      // Reconstruct chunk with separators to help the model identify boundaries
      final chunkText = chunkBlocks.join('\n**********----------**********\n');

      if (chunkText.trim().isEmpty) continue;

      final prompt =
          """
You are a scientific data parser. Extract the following columns into CSV.
Columns: ${tags.join(', ')}

Rules:
- Output ONLY the data rows. Do NOT output the header row.
- Strictly follow the column order above.
- Process ALL data blocks found in the text.
- Each MELTS block (separated by **********----------**********) corresponds to ONE row.
- If a value is missing for a column, leave it empty (e.g. `val1,,val3`).
- Ensure each row has exactly ${tags.length} columns.
- Do NOT repeat rows. Stop when you have processed all blocks.
- Output ONLY CSV (no explanations, markdown, or extra text).

MELTS text:
$chunkText
""";

      final body = {
        "contents": [
          {
            "parts": [
              {"text": prompt},
            ],
          },
        ],
        "generationConfig": {"temperature": 0.0, "maxOutputTokens": 8192},
      };

      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(Duration(seconds: 120));

      if (resp.statusCode != 200) {
        throw Exception('Gemini API error: ${resp.statusCode} ${resp.body}');
      }

      final decoded = jsonDecode(resp.body);
      final candidates = decoded['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) {
        throw Exception('No response from Gemini');
      }

      var extracted = _extractGeminiText(candidates);
      if (extracted == null || extracted.isEmpty) {
        continue;
      }

      // Clean markdown
      extracted = extracted.replaceAll(
        RegExp(r'^```csv\s*', multiLine: true),
        '',
      );
      extracted = extracted.replaceAll(RegExp(r'^```\s*', multiLine: true), '');
      extracted = extracted.replaceAll(RegExp(r'```$', multiLine: true), '');
      extracted = extracted.trim();

      final chunkLines = extracted.split('\n');
      for (var j = 0; j < chunkLines.length; j++) {
        var line = chunkLines[j].trim();
        if (line.isEmpty) continue;

        // Skip if it looks like the header (contains the first tag name)
        if (j == 0 && line.contains(tags.first)) {
          continue;
        }

        // Simple CSV split
        final parts = line.split(',');
        String finalLine;

        // Fix length
        if (parts.length > tags.length) {
          // Truncate extra columns
          finalLine = parts.sublist(0, tags.length).join(',');
        } else if (parts.length < tags.length) {
          // Pad missing columns
          final padded = List<String>.from(parts);
          while (padded.length < tags.length) {
            padded.add('');
          }
          finalLine = padded.join(',');
        } else {
          finalLine = line;
        }

        // Dedup: prevent consecutive identical rows (common hallucination)
        if (processedLines.isNotEmpty && processedLines.last == finalLine) {
          continue;
        }

        processedLines.add(finalLine);
      }
    }

    final header = tags.join(',');
    return '$header\n${processedLines.join('\n')}';
  }

  Future<void> _parseAndSaveCsv() async {
    if (geminiApiKey == 'REPLACE_WITH_YOUR_GEMINI_API_KEY') {
      _showSnack(
        'Replace GEMINI_API_KEY with your key from https://aistudio.google.com/app/apikey',
      );
      return;
    }
    if (_filePath == null) {
      _showSnack('Pick a file first.');
      return;
    }
    if (_selectedTags.isEmpty) {
      _showSnack('Select at least one tag for columns.');
      return;
    }

    setState(() {
      _loading = true;
      _status = 'Reading file...';
      _csvPreview = '';
    });

    try {
      final text = await _readFileText();
      setState(() {
        _status = 'Sending to Google Gemini...';
      });

      final csv = await _invokeGeminiExtract(text, _selectedTags);

      setState(() {
        _csvPreview = csv;
        _status = 'Saving CSV...';
      });

      final savedPath = await _saveCsvToDevice(csv, generateFilename());
      setState(() {
        _status = 'Saved to: $savedPath';
      });
      _showSnack('CSV saved: $savedPath');
    } catch (e, st) {
      setState(() {
        _status = 'Error: ${e.toString()}';
      });
      debugPrint(st.toString());
      _showSnack('Error: ${e.toString()}');
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<String> _readFileText() async {
    if (_filePath == null) throw Exception('No file chosen');
    final file = File(_filePath!);
    return await file.readAsString();
  }

  Future<String> _saveCsvToDevice(String csv, String name) async {
    // Attempt to open the save dialog in the same directory as the input file
    String? initialDirectory;
    if (_filePath != null) {
      try {
        initialDirectory = File(_filePath!).parent.path;
      } catch (e) {
        debugPrint('Could not determine parent directory: $e');
      }
    }

    final String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save CSV',
      fileName: name,
      initialDirectory: initialDirectory,
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
