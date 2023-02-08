library newlines.repo;

import 'dart:convert';
import 'dart:io';

import 'package:pool/pool.dart';

class NewlineCheckReport {
  final List<String> okay;
  final List<String> needed;

  List<String> get all => <String>[]..addAll(needed)..addAll(okay);

  NewlineCheckReport(this.okay, this.needed);

  @override
  String toString() => "${needed.length} files need a newline out of ${all.length} total files";

  Map<String, dynamic> toJson() => <String, dynamic>{
    "okay": okay,
    "needed": needed
  };
}

class NewlinesUpdater {
  final Directory directory;

  NewlinesUpdater(this.directory);

  Future<void> clone(String url, String? ref, {bool updateIfExists = true}) async {
    final gitDirectory = Directory("${directory.path}/.git");
    if (await gitDirectory.exists()) {
      var result = await Process.run("git", [
        "fetch"
      ], workingDirectory: directory.absolute.path);

      var code = result.exitCode;
      if (code != 0) {
        throw "Failed to fetch repository ${url} (exit code ${code})";
      }

      result = await Process.run("git", [
        "reset",
        "--hard",
        ref != null ? ref : "HEAD"
      ], workingDirectory: directory.absolute.path);
      if (code != 0) {
        throw "Failed to reset repository to ref ${ref} (exit code ${code})";
      }
    } else {
      final args = <String>[
        "clone",
        url,
        directory.absolute.path,
        "--depth",
        "1"
      ];

      if (ref != null) {
        args.addAll([
          "-b",
          ref
        ]);
      }

      final result = await Process.run("git", args, runInShell: true);
      final code = await result.exitCode;
      if (code != 0) {
        throw "Failed to clone repository ${url} (exit code ${code})";
      }
    }
  }

  Future<List<String>> listAllPaths() async {
    final result = await Process.run("git", [
      "ls-files"
    ], workingDirectory: directory.absolute.path);

    final code = result.exitCode;
    if (result.exitCode != 0) {
      throw "Failed to list files (exit code ${code})";
    }

    return LineSplitter.split(result.stdout.toString()).where((e) => e.isNotEmpty).toList();
  }

  Future<bool> isPathText(String path) async {
    final result = await Process.run("git", [
      "diff",
      "--no-index",
      "--numstat",
      "/dev/null",
      path
    ], workingDirectory: directory.absolute.path);
    return result.stdout.toString().indexOf("-") != 0;
  }

  Future<NewlineCheckReport> report() async {
    var okay = <String>[];
    var needed = <String>[];

    final pool = Pool(50);
    var idCount = 1;
    final all = await listAllPaths();
    for (final path in all) {
      final id = idCount;
      pool.withResource(() async {
        if (!await isPathText(path)) {
          okay.add(path);
          return;
        }

        final file = File("${directory.absolute.path}/$path");

        if (await isNewlineNeeded(file)) {
          needed.add(path);
        } else {
          okay.add(path);
        }
      });
      idCount++;
    }
    await pool.close();
    return NewlineCheckReport(okay, needed);
  }

  Future<bool> isNewlineNeeded(File file) async {
    if (await FileSystemEntity.isDirectory(file.path) || !await file.exists()) {
      return false;
    }

    final size = await file.length();
    if (size == 0) {
      return false;
    }
    final read = file.openRead(size - 1);
    final chunk = await read.single;
    return chunk[0] != 0x0a;
  }

  Future<void> addNewlineToFile(File file) async {
    final write = file.openWrite();
    write.add(const [0x0a]);
    await write.close();
  }

  Future<String> revision({bool abbrv = false}) async {
    final args = <String>[
      "rev-parse"
    ];

    if (abbrv) {
      args.add("--abbrev-ref");
    }
    args.add("HEAD");
    final result = await Process.run("git", args, workingDirectory: directory.absolute.path);
    if (result.exitCode != 0) {
      throw "Failed to calculate revision (exit code ${result.exitCode})";
    }
    return result.stdout.toString().trim();
  }
}
