import 'dart:async';
import "package:logging/logging.dart";

import "package:cupstream2distrobot/periodic_download_service.dart" as downloadservice;
import "package:cupstream2distrobot/silomanager.dart" as silomanager;
import "package:cupstream2distrobot/utils.dart";

void main() {
  // setting up logging level
  setupRootLogger(Level.FINE);

  Stream<String> backendStream =
      downloadservice.periodicDownload("https://docs.google.com/a/canonical.com/spreadsheet/ccc?key=0AuDk72Lpx8U5dFlCc1VzeVZzWmdBZS11WERjdVc3dmc&output=csv",
                                       30, useDownloadScript: true);
  /*StreamSubscription<String> subscription = backendStream.listen(print);
  new Timer(const Duration(seconds: 10), subscription.pause);
  new Timer(const Duration(seconds: 20), subscription.resume);*/

  silomanager.run();

}
