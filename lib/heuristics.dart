library newlines.heuristics;

import 'dart:convert';
import 'dart:io';

import 'package:newlines/updater.dart';
import 'package:path/path.dart' as pathlib;

class HeuristicsFileLanguageHighProbabilityNewline {
  final String extension;
  final double confidence;

  HeuristicsFileLanguageHighProbabilityNewline(this.extension, this.confidence);
}

class HeuristicsFilePathAnalysis {
  final Map<String, Map<String, bool>> newlinesByExtension;

  HeuristicsFilePathAnalysis(this.newlinesByExtension);

  static HeuristicsFilePathAnalysis analyze(NewlineCheckReport report) {
    final newlinesByExtension = <String, Map<String, bool>>{};
    for (final path in report.all) {
      final extension = pathlib.extension(path);
      var map = newlinesByExtension[extension];
      if (map == null) {
        newlinesByExtension[extension] = map = <String, bool>{};
      }
      map[path] = report.needed.contains(path);
    }
    return HeuristicsFilePathAnalysis(newlinesByExtension);
  }

  bool isKnownRequiredNewlineExtension(String ext) {
    return const [
      ".cpp",
      ".cc",
      ".c++"
    ].contains(ext);
  }

  final _hashNamePattern = RegExp(r"(.*)-sha([0-9]+):(.*)");

  bool hasHashName(String path) {
    return path.contains(_hashNamePattern);
  }

  bool isVendorCode(String path) => path.startsWith("vendor/") || path.startsWith("third_party/");

  Map<String, HeuristicsFileLanguageHighProbabilityNewline> extensionsWithHighNewlineProbability({double confidenceThreshold = 50.1}) {
    final extensions = <String, HeuristicsFileLanguageHighProbabilityNewline>{};
    for (final extToFiles in newlinesByExtension.entries) {
      final ext = extToFiles.key;
      final files = extToFiles.value;
      final needed = files.entries.where((e) => e.value).length;
      final total = files.length;
      if (total <= 2) {
        continue;
      }
      final percentage = (needed / total) * 100.0;
      if (percentage >= confidenceThreshold) {
        extensions[ext] = HeuristicsFileLanguageHighProbabilityNewline(ext, percentage);
      }
    }
    return extensions;
  }
}

class HeuristicsFileCompositionAnalysis {
  final int totalSize;
  final int totalLines;
  final double averageLineLength;

  HeuristicsFileCompositionAnalysis(this.totalSize, this.totalLines, this.averageLineLength);

  static Future<HeuristicsFileCompositionAnalysis> analyze(File file) async {
    final size = await file.length();
    final stream = file.openRead();
    final roughLineCount = await stream.map((e) => e.where((c) => c == 0x0a).length).fold<int>(0,
            (previous, element) => previous + element);
    final averageLineLength = size / roughLineCount;
    return HeuristicsFileCompositionAnalysis(size, roughLineCount, averageLineLength);
  }

  bool get isBlobFile => averageLineLength > 300.0;
  bool get isLargeFile => totalSize > 65536;
}
