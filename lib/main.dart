import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

/// IMPORTANT: Replace with your API key
/// Get free Gemini API key from: https://aistudio.google.com/app/apikey
// const String geminiApiKey = 'AIzaSyCWs5WLLHWeZ4lTZCEsLPv8wevk1aKZuZ0';
const String geminiApiKey = 'AIzaSyDTCh2ak9Kp7_gG09ZOxkS6eZOA69rKzPc';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State createState() => _HomePageState();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MELTS → CSV (Gemini)',
      theme: ThemeData(primarySwatch: Colors.teal),
      home: HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ParameterGroup {
  final String name;
  final List<String> parameters;
  const ParameterGroup(this.name, this.parameters);
}

class _HomePageState extends State<HomePage> {
  String? _filePath;
  String? _fileName;
  bool _loading = false;
  String _status = '';
  String _csvPreview = '';
  List<String> _selectedTags = [];

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
      appBar: AppBar(title: Text('MELTS → CSV (Gemini)')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton.icon(
              onPressed: pickFile,
              icon: Icon(Icons.attach_file),
              label: Text(
                _fileName == null ? 'Pick .out / .txt file' : 'Change file',
              ),
            ),
            SizedBox(height: 8),
            Text('Selected: ${_fileName ?? "None"}'),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _openTagSelector,
              icon: Icon(Icons.view_column),
              label: Text('Select tags (${_selectedTags.length})'),
            ),
            SizedBox(height: 6),
            Text(
              'Tags: ${_selectedTags.isEmpty ? "(none)" : _selectedTags.join(", ")}',
            ),
            SizedBox(height: 18),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _parseAndSaveCsv,
                  icon: Icon(Icons.cloud_upload),
                  label: Text('Parse & Save CSV'),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _csvPreview.isNotEmpty
                      ? () => _showPreviewFull(context)
                      : null,
                  icon: Icon(Icons.preview),
                  label: Text('Open CSV Preview'),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildPreviewArea(),
            SizedBox(height: 12),
            Text('Status: $_status'),
            SizedBox(height: 20),
            Text(
              'Lightweight app (~100 MB). Uses Google Gemini API. Requires internet.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildPreviewArea() {
    if (_loading) {
      return Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text(_status),
        ],
      );
    }
    if (_csvPreview.isNotEmpty) {
      final previewLines = _csvPreview.split('\n').take(20).join('\n');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CSV Preview (first 20 lines):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.grey.shade100,
            width: double.infinity,
            constraints: const BoxConstraints(maxHeight: 200),
            child: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SelectableText(
                  previewLines,
                  style: TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return SizedBox.shrink();
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

  Future<void> _openTagSelector() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final chosen = Set<String>.from(_selectedTags);
        return StatefulBuilder(
          builder: (c, setStateLocal) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                top: 16,
              ),
              child: SafeArea(
                child: Container(
                  height: MediaQuery.of(ctx).size.height * 0.8,
                  padding: EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Text(
                        'Select Parameters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _parameterGroups.length,
                          itemBuilder: (context, index) {
                            final group = _parameterGroups[index];
                            return ExpansionTile(
                              title: Text(group.name),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                    vertical: 8.0,
                                  ),
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: group.parameters.map((param) {
                                      final tag = '${group.name}.$param';
                                      final selected = chosen.contains(tag);
                                      return ChoiceChip(
                                        label: Text(param),
                                        selected: selected,
                                        onSelected: (sel) {
                                          setStateLocal(() {
                                            if (sel) {
                                              chosen.add(tag);
                                            } else {
                                              chosen.remove(tag);
                                            }
                                          });
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, null),
                            child: Text('Cancel'),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.pop(ctx, chosen.toList()),
                            child: Text('Apply'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedTags = result;
      });
    }
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

  void _showPreviewFull(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('CSV'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _csvPreview,
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
        ],
      ),
    );
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
