import 'dart:io';

import 'package:newlines/heuristics.dart';
import 'package:newlines/updater.dart';
import 'package:path/path.dart' as pathlib;

Future<Directory> getCacheDirectory() async {
  final overrideCachePath = Platform.environment["NEWLINES_CACHE_PATH"];
  if (overrideCachePath != null) {
    return Directory(overrideCachePath).absolute;
  } else {
    return Directory("${Directory.current.path}/cache").absolute;
  }
}

Future<void> main(List<String> args) async {
  final url = args[0];
  final ref = args.length >= 2 ? args[0] : null;
  final uri = Uri.parse(url);
  final id = uri.host + "_" + uri.path
      .substring(1)
      .replaceAll("/", "_")
      .replaceAll(RegExp(r".git$"), "");
  final directoryCache = await getCacheDirectory();
  final directory = Directory("${directoryCache.path}/${id}");
  await directory.create(recursive: true);
  final updater = NewlinesUpdater(directory);
  await updater.clone(url, ref, updateIfExists: true);
  final report = await updater.report();
  await printFullReport(url, updater, report);
}

Future<void> printFullReport(String url, NewlinesUpdater updater, NewlineCheckReport report) async {
  final abbrv = await updater.revision(abbrv: true);
  final commit = await updater.revision();
  print("[Report for URL ${url} branch ${abbrv} commit ${commit}]");
  print("Total files: ${report.all.length} files");
  if (report.needed.isEmpty) {
    print("No files need newline.");
  } else {
    print("Newline needed on:");
    final pathAnalysis = HeuristicsFilePathAnalysis.analyze(report);
    final highNewlineProbabilityExtensions = pathAnalysis.extensionsWithHighNewlineProbability();
    for (final path in report.needed) {
      final compositionAnalysis = await HeuristicsFileCompositionAnalysis.analyze(updater.file(path));

      final ext = pathlib.extension(path);

      var strength = "LOW";

      final match = highNewlineProbabilityExtensions[ext];
      if (match != null) {
        strength = "(${match.confidence.toStringAsPrecision(2)}%) HIGH";
      }

      if (pathAnalysis.isKnownRequiredNewlineExtension(ext)) {
        strength = "REQ";
      }

      if (compositionAnalysis.isBlobFile) {
        strength = "BLOB LOW";
      }

      if (pathAnalysis.hasHashName(path)) {
        strength = "HASHED LOW";
      }

      if (compositionAnalysis.isLargeFile) {
        strength = "LARGE LOW";
      }

      if (pathAnalysis.isVendorCode(path)) {
        strength += "VENDOR ${strength}";
      }

      print("  ${strength} ${path}");
    }
  }
}
