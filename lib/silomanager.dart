library silomanager;

import 'dart:async';

import "package:cupstream2distrobot/silomanager-src/silo.dart";
import 'package:logging/logging.dart';
import 'package:cupstream2distrobot/silomanager-src/csvdataparser.dart';


final Logger log = new Logger('SiloManager');
var activeSilos = new List<ActiveSilo>();
var unassignedSilos = new List<UnassignedSilo>();

var sendMessageFunction;

/**
 * Subscribe to the [source] stream to be able to parse it later on
 */
void run(Stream<String> source, var _sendMessageFunction) {
  sendMessageFunction = _sendMessageFunction;
  source.listen(_parseNewContent);
}

List<String> _separateContent(String parse, {useSlashSeparator: false}) {
  var result = new List<String>();

  if (useSlashSeparator)
    parse = parse.split('/').join(" ");

  for (var entry in parse.split(',')) {
    for (var x in entry.split(" ")) {
      for (var y in x.split('\n'))
        result.add(y.trim());
    }
  }
  return result;
}

void _parseNewContent(String content) {
  log.fine("New download results received");

  var newActiveSilos =  new List<ActiveSilo>();
  var newUnassignedSilos =  new List<UnassignedSilo>();

  var value = new CsvDataParser(content, numLineToSkip: 3);
  var line = 3;
  for (var item in value) {
    line++;
    var assignees = _separateContent(item[1], useSlashSeparator: true);
    var description = item[0];
    var mps = _separateContent(item[5]);
    var sources = _separateContent(item[6]);
    var comment = item[3];
    var ready = (item[8] == 'Yes');

    var id = item[10];

    if (id.isEmpty) {
      var silo = new UnassignedSilo(line, assignees, description, mps,
                                    sources, comment, ready);
      newUnassignedSilos.add(silo);
      if (!(unassignedSilos.contains(silo)))
          silo.message.listen(sendMessageFunction);
    }
    else if(item[12] == "Landed") {
      // if it has landed and was in previous activeSilos list, update the status to trigger the pings
      var silo = activeSilos.firstWhere((silo) => id == silo.id,
                                        orElse: () => null);
      if(silo != null) {
        silo.status = new Status("Landed", "", true);
        silo.siloName = "";
      }
    }
    else {
      var newStatus = new Status(item[13], item[14], item[15] == "TRUE");

      var silo = new ActiveSilo(id, item[11], newStatus, line, assignees,
                                description, mps, sources, comment, ready);
      newActiveSilos.add(silo);
      if (!(activeSilos.contains(silo)))
          silo.message.listen(sendMessageFunction);
    }
  }

  activeSilos = newActiveSilos;
  unassignedSilos = newUnassignedSilos;
}
