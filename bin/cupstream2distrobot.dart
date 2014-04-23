import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import "package:logging/logging.dart";

import "package:cupstream2distrobot/ircbot.dart";
import "package:cupstream2distrobot/periodic_download_service.dart" as downloadservice;
import "package:cupstream2distrobot/silomanager.dart" as silomanager;
import "package:cupstream2distrobot/utils.dart";

const USE_FILE = 'useFile';
const GOOGLE_DOC_URL = "https://docs.google.com/a/canonical.com/spreadsheet/ccc?key=0AuDk72Lpx8U5dFlCc1VzeVZzWmdBZS11WERjdVc3dmc&output=csv";

void main(List<String> arguments) {
  Level debugLevel = Level.INFO;
  final parser = new ArgParser()
      ..addOption(USE_FILE, abbr:'f', help: "Use this csv file instead of downloading online")
      ..addFlag("verbose", abbr: 'v', negatable: false, help: "Maximum debug info")
      ..addFlag("debug", abbr: 'd', negatable: false, help: "Moderate debug info")
      ..addFlag("help", abbr: 'h', negatable: false, help: "Display help info");

  var argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch(e) {
    print(e);
    _showHelpAndExit(parser, returncode: 1);
  }

  // setting up logging level
  if (argResults["debug"])
    debugLevel = Level.FINE;
  if (argResults["verbose"])
    debugLevel = Level.ALL;
  setupRootLogger(debugLevel);

  if (argResults["help"])
    _showHelpAndExit(parser);

  Stream<String> sourceStream;
  if (argResults[USE_FILE] != null) {
    Logger.root.info("Using ${argResults[USE_FILE]} as source");
    var file = new File(argResults[USE_FILE]);
    sourceStream = file.readAsString(encoding: const Utf8Codec()).asStream();
  }
  else {
    sourceStream = downloadservice.periodicDownload(GOOGLE_DOC_URL, 30, useDownloadScript: true);
  }

  // connect to IRC
  IRC connection = new IRC();

  // connect the stream and start the processing
  silomanager.run(sourceStream, connection);

}

void _showHelpAndExit(ArgParser parser, {int returncode: 0}) {
  print(parser.getUsage());
  exit(0);
}
