import 'dart:io';

import 'package:args/args.dart';
import 'package:flutter_build_debian/dependencies.dart';
import 'package:flutter_build_debian/flutter_build_debian.dart';
import 'package:flutter_build_debian/usage.dart';
import 'package:flutter_build_debian/vars.dart';

const cmdDependencies = 'dependencies';
const cmdHelp = 'help';
const cmdCreate = 'create';
const cmdBuild = 'build';

void main(List<String> arguments) async {
  exitCode = 0;

  final parser = ArgParser()
    ..addCommand(cmdDependencies, DependencyFinder.getArgParser())
    ..addCommand(cmdHelp)
    ..addCommand(cmdCreate, FlutterToDebian.getArgParser())
    ..addCommand(cmdBuild, FlutterToDebian.getArgParser());

  ArgResults argResults = parser.parse(arguments);
  final restArgs = argResults.rest;

  if (argResults.command?.name == cmdDependencies) {
    await dependencies(argResults.command!);
  } else if (argResults.command?.name == cmdHelp) {
    usage(null); // TODO: use built in help function from ArgParser
  } else if (argResults.command == null ||
      argResults.command?.name == cmdBuild ||
      argResults.command?.name == cmdCreate) {
    stdout.write("\nchecking for debian 📦 in root project...");
    try {
      var flutterToDebian = await Vars.parseDebianYaml();
      if (flutterToDebian == null) {
        flutterToDebian = await Vars.parsePubspecYaml();
        if (flutterToDebian != null) {
          final deps = await DependencyFinder().run();
          flutterToDebian.debianControl =
              flutterToDebian.debianControl.copyWith(
            depends: deps.join(','),
          );
        }
      }

      if (flutterToDebian == null) {
        throw Exception("Couldn't find debian/debian.yaml or pubspec.yaml");
      }

      if (argResults.command != null) {
        // Apply build args
        final buildArgResults = argResults.command!;
        // final buildRestArgs = buildArgResults.rest;
        flutterToDebian.debianControl = flutterToDebian.debianControl.copyWith(
          version: buildArgResults[optBuildVersion],
        );
      }

      stdout.writeln("  ✅\n");
      stdout.writeln("start building debian package... ♻️  ♻️  ♻️\n");
      try {
        if (argResults.command?.name == cmdCreate) {
          await flutterToDebian.createDesktopDataFiles(isOverride: true);
          return;
        }

        final String execPath = await flutterToDebian.build();

        stdout.writeln("🔥🔥🔥 (debian 📦) build done successfully  ✅\n");
        stdout.writeln("😎 find your .deb at\n$execPath");
      } catch (e) {
        exitCode = 2;
        rethrow;
      }
    } catch (e) {
      exitCode = 2;
      rethrow;
    }
  } else {
    usage('Unknown arguments: $restArgs');
  }
}
