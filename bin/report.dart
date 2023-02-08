import 'dart:io';

import 'package:newlines/updater.dart';

Future<void> main(List<String> args) async {
  final url = args[0];
  final ref = args.length >= 2 ? args[0] : null;
  final uri = Uri.parse(url);
  final id = uri.host + "_" + uri.path.substring(1).replaceAll("/", "_").replaceAll(RegExp(r".git$"), "");
  final directory = Directory("${Directory.current.path}/cache/${id}");
  await directory.create(recursive: true);
  final updater = NewlinesUpdater(directory);
  await updater.clone(url, ref, updateIfExists: true);
  final report = await updater.report();
  print("[Report for URL ${url} branch ${await updater.revision(abbrv: true)} commit ${await updater.revision()}]");
  print("Total files: ${report.all.length} files");
  if (report.needed.isEmpty) {
    print("No files need newline.");
  } else {
    print("Newline needed on:");
    for (final path in report.needed) {
      print("  ${path}");
    }
  }
}
