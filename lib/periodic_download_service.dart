library periodic_download_service;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'package:cupstream2distrobot/utils.dart';

final Logger log = new Logger('PeriodicDownloadService');

/**
 * Return a stream of Strings corresponding to the [url] download every [seconds]
 * Work is done inside an isolate.
 * You can use a python download script with [useDownloadScript] if you have an issue
 * while fetching your data (like login loop in google spreadsheet).
 *
 * [logLevel] will be applied in the isolate process. Otherwise, it will use the default
 * log Level from the root Logger.
 */
Stream<String> periodicDownload(String url, int seconds, {bool useDownloadScript: false, Level logLevel}) {
  StreamController<String> controller;
  Timer timer;
  SendPort isolatePort = null;

  // Initialize log level.
  if (logLevel == null)
    logLevel = Logger.root.level;


  void start() {
    log.fine("Got a subscriber. Starting downloading $url every ${seconds}s");
    var receivePort = new ReceivePort();
    Isolate.spawn(_syncIsolate, receivePort.sendPort);

    var isFirstMessage = true;
    receivePort.listen((response) {
       if (isFirstMessage && response is SendPort) {
         // Send initial request.
         isolatePort = response;
         isolatePort.send(new _initInfo(url, seconds, useDownloadScript, logLevel));
       } else if (isFirstMessage) {
         throw new Exception("Expected first isolate message to be a SendPort");
       } else {
         // Emit event to stream.
         log.fine("Emit new download results");
         controller.add(response);
       }
       isFirstMessage = false;
    });
  }

  void stop() {
    log.fine("No subscriber. Stop the isolate and download service.");
    if (isolatePort == null)
      throw new Exception("Call stopping a non started isolate");
    // Ask background isolate to stop.
    isolatePort.send("stop");
  }

  controller = new StreamController<String>(
      onListen: start,
      onPause: stop,
      onResume: start,
      onCancel: stop);

  return controller.stream;
}

/*
 * The isolate method handling the communication with the other process and starting the timer.
 */
void _syncIsolate(SendPort mainPort) {
  var port = new ReceivePort();
  mainPort.send(port.sendPort);

  // Get the download script path.
  var rootDir = path.dirname(path.dirname(path.fromUri(Platform.script)));
  var downloadScript = path.join(rootDir, "lib", "periodic_download_service-src", "downloader");

  Timer downloaderTimer;
  var isFirstMessage = true;
  port.listen((message) {
    if (isFirstMessage && message is _initInfo) {
      // Init logging for this isolate.
      setupRootLogger(message.logLevel);
      log.finer("Isolate for download service started.");

      // Setup a period download and send that the main isolate.
      void _downloadAndSend() {
        _download(message.url, downloadScript: message.useDownloadScript? downloadScript : "")
            .then((result) => mainPort.send(result));
      }
      downloaderTimer = new Timer.periodic(new Duration(seconds: message.seconds), (_) {
        _downloadAndSend();
      });
      // Issue first request.
      _downloadAndSend();
    } else if (isFirstMessage) {
      throw new Exception("Expected first message sent to isolate to be an initInfo");
    } else if (message == "stop") {
      downloaderTimer.cancel();
      // Close the connection and thus, isolate.
      port.close();
      log.finer("Isolate for download service stopped.");
    } else {
      throw new Exception("Unexpected message from main isolate: $message");
    }
    isFirstMessage = false;
  });
}

/*
 * Download from url, eventually using the provided downloadScript.
 */
Future<String> _download(String url, {String downloadScript: ""}) {
  var completer = new Completer();
  log.finer("Download starting.");

  if(downloadScript != "") {
    log.finest("Start download script");
    Process.run(downloadScript, [url])
        .then((ProcessResult result) {
          if (result.exitCode != 0)
            throw("[${result.exitCode}]: ${result.stderr}");
          log.finest("Result from download script: ${result.stdout}");
          completer.complete(result.stdout);
        })
        .catchError((e) => log.warning("Download script returned: $e"));
  } else {
    log.finest("Start direct download");
    new HttpClient().getUrl(Uri.parse(url))
        .then((request) => request.close())
        .then((HttpClientResponse response) {
          if (response.statusCode != HttpStatus.OK)
            throw("Couldn't fetch the page, received error ${response.statusCode}");
          // Transform the string of bytes in a StringBuffer.
          response.transform(UTF8.decoder)
              .fold(new StringBuffer(), (buf, next) {
                buf.write(next);
                return buf;
              });
        })
        .then((StringBuffer buf) {
          var result = buf.toString();
          log.finest("Result from download script: ${result}");
          completer.complete(result);
        })
        .catchError((e) => log.warning("Download returned: $e"));
  }

  return completer.future;
}

/*
 * Class used to send initial data to the isolate.
 */
class _initInfo {
  final String url;
  final int seconds;
  final bool useDownloadScript;
  final Level logLevel;

  _initInfo(this.url, this.seconds, this.useDownloadScript, this.logLevel);
}