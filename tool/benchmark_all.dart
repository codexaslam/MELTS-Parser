import 'dart:io';

import 'package:melts_parser/parser_logic.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tool/benchmark_all.dart <path_to_out_files_folder>');
    exit(1);
  }

  final folderPath = args[0];
  final apiKey = Platform.environment['GEMINI_API_KEY'] ?? '';

  if (apiKey.isEmpty) {
    print(
      'Warning: GEMINI_API_KEY environment variable is not set. Gemini benchmarks will fail.',
    );
  }

  final dir = Directory(folderPath);
  if (!await dir.exists()) {
    print('Folder not found: $folderPath');
    exit(1);
  }

  final outFiles = await dir
      .list(recursive: false)
      .where((e) => e is File && e.path.toLowerCase().endsWith('.out'))
      .cast<File>()
      .toList();

  if (outFiles.isEmpty) {
    print('No .out files found in $folderPath');
    exit(0);
  }

  print('\n=== Benchmarking ${outFiles.length} file(s) ===\n');

  for (final file in outFiles) {
    print('File: ${file.path.split(Platform.pathSeparator).last}');
    final text = await file.readAsString();
    final tags = await _getTags(text);

    // 1. Benchmark Local Parser
    final localStopwatch = Stopwatch()..start();
    try {
      final csv = await ParserLogic.parse(text, tags);
      localStopwatch.stop();
      print(
        '  -> Local Parser: ${localStopwatch.elapsedMilliseconds} ms (${csv.split('\n').length} lines)',
      );
    } catch (e) {
      localStopwatch.stop();
      print(
        '  -> Local Parser: Failed in ${localStopwatch.elapsedMilliseconds} ms - $e',
      );
    }

    // 2. Benchmark Gemini
    if (apiKey.isNotEmpty) {
      final geminiStopwatch = Stopwatch()..start();
      try {
        final csv = await _invokeGemini(text, tags, apiKey);
        geminiStopwatch.stop();
        print(
          '  -> Gemini API:   ${geminiStopwatch.elapsedMilliseconds} ms (${csv.split('\n').length} lines)',
        );
      } catch (e) {
        geminiStopwatch.stop();
        print(
          '  -> Gemini API:   Failed in ${geminiStopwatch.elapsedMilliseconds} ms - $e',
        );
      }
    }
    print('');
  }
}

Future<List<String>> _getTags(String text) async {
  final detected = await ParserLogic.analyzeFile(text);
  final tags = <String>[];
  for (final phase in detected.keys) {
    for (final param in detected[phase]!) {
      tags.add('$phase.$param');
      if (tags.length > 20)
        return tags; // limit tags to prevent massive token bloat
    }
  }
  return tags;
}

Future<String> _invokeGemini(
  String content,
  List<String> tags,
  String apiKey,
) async {
  final uri = Uri.parse(
    'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=$apiKey',
  );

  String extractedText = content;
  if (extractedText.length > 50000)
    extractedText = extractedText.substring(0, 50000);

  final prompt =
      '''You are a strict CSV generator. Extracted columns: \${tags.join(', ')}. Rules: ONLY valid CSV. text: \$extractedText''';

  final body =
      '{"contents":[{"parts":[{"text":${_jsonEncode(prompt)}}]}],"generationConfig":{"temperature":0.1}}';

  final request = await HttpClient().postUrl(uri);
  request.headers.add('Content-Type', 'application/json');
  request.write(body);
  final response = await request.close();
  final responseBody = await response
      .transform(SystemEncoding().decoder)
      .join();
  if (response.statusCode != 200)
    throw Exception('HTTP \${response.statusCode}');
  return responseBody;
}

String _jsonEncode(String str) {
  return '"${str.replaceAll('\\n', '\\\\n').replaceAll('"', '\\\\"')}"';
}
