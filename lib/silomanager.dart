library silomanager;

import 'dart:async';

import 'package:irc_client/irc_client.dart';
import 'package:logging/logging.dart';

import "package:cupstream2distrobot/ircbot.dart";
import "package:cupstream2distrobot/silomanager-src/silo.dart";
import 'package:cupstream2distrobot/silomanager-src/csvdataparser.dart';


final Logger log = new Logger('SiloManager');
List<ActiveSilo> activeSilos = new List<ActiveSilo>();
List<UnassignedSilo> unassignedSilos = new List<UnassignedSilo>();

IRC ircConnection;

/**
 * Subscribe to the [source] stream to be able to parse it later on
 * Receive an IRC connection to subsribe an handler for additional
 * commands.
 */
void run(Stream<String> source, IRC _ircConnection) {
  ircConnection = _ircConnection;
  ircConnection.addHandler(new _SiloBotHandler());
  source.listen(_parseNewContent);
}

List<String> _separateContent(String parse, {useSlashSeparator: false, toLowerCase: false}) {
  var result = new List<String>();

  if (useSlashSeparator)
    parse = parse.split('/').join(" ");

  for (var entry in parse.split(',')) {
    for (var x in entry.split(" ")) {
      for (var y in x.split('\n')) {
        y = y.trim();
        result.add(toLowerCase? y.toLowerCase() : y);
      }
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
    var assignees = _separateContent(item[1], useSlashSeparator: true, toLowerCase: true);
    var description = item[0];
    var mps = _separateContent(item[5], toLowerCase: true);
    var sources = _separateContent(item[6], toLowerCase: true);
    var comment = item[3];
    var ready = (item[8] == 'Yes');

    var id = item[10];

    if (id.isEmpty) {
      var silo = new UnassignedSilo(line, assignees, description, mps,
                                    sources, comment, ready);
      newUnassignedSilos.add(silo);
      if (!(unassignedSilos.contains(silo)))
          silo.message.listen(ircConnection.sendMessage);
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
          silo.message.listen(ircConnection.sendMessage);
    }
  }

  activeSilos = newActiveSilos;
  unassignedSilos = newUnassignedSilos;
}

class _SiloBotHandler extends Handler {

  Map<String, dynamic> commands;

  _SiloBotHandler() {
    commands = {
      'inspect': _inspectSiloStatus,
      'status': _siloStatus,
      'where': _siloComponents,
      'who': _siloOwner
    };
  }

  List<dynamic> getAllSilos() {
    return new List<dynamic>()
        ..addAll(activeSilos)
        ..addAll(unassignedSilos);
  }

  void _inspectSiloStatus(String req, String channel, Connection cnx) =>
      _siloStatus(req, channel, cnx, inspect: true);

  void _siloStatus(String req, String channel, Connection cnx, {bool inspect: false}) {
    bool found = false;
    int lineNum = int.parse(req, onError: (req) {
      activeSilos.forEach((silo) {
        if (silo.siloName == req) {
          var message = silo.statusMessage;
          if (inspect)
            message = silo.statusRequest;
          cnx.sendMessage(channel, "$req status is: $message");
          found = true;
        }});
      return -1;
    });
    if (lineNum > -1)
      getAllSilos().forEach((silo) {
        if (silo.line == lineNum) {
          var message = silo.statusMessage;
          if (inspect)
            message = silo.statusRequest;
          cnx.sendMessage(channel, "line $lineNum status is: $message");
          found = true;
      }});
    if (!found)
      cnx.sendMessage(channel, "Couldn't find anything matching this status request: $req");
  }

  void _siloComponents(String req, String channel, Connection cnx) {
    var answer = new StringBuffer("Requests containing $req. ");
    bool found = false;
    getAllSilos().forEach((BaseSilo silo) {
      if (silo.mps.any((mp) => mp.contains("/$req/")) ||
          silo.sources.contains(req)) {
        found = true;
        if (silo is ActiveSilo)
          answer.write("In ${silo.siloName}. ");
        else if (silo is UnassignedSilo)
          answer.write("In request line ${silo.line}. ");
      }
    });
    if (!found)
      answer.write("Not found in any active or pending silos");
    cnx.sendMessage(channel, answer.toString());
  }

  void _siloOwner(String req, String channel, Connection cnx) {
    var answer = new StringBuffer("Requests by $req. ");
    bool found = false;
    getAllSilos().forEach((BaseSilo silo) {
      if(silo.assignee.contains(req)) {
        found = true;
        if (silo is ActiveSilo)
          answer.write("In ${silo.siloName}. ");
        else if (silo is UnassignedSilo)
          answer.write("In request line ${silo.line}. ");
      }
    });
    if (!found)
      answer.write("Not found in any active or pending silos");
    cnx.sendMessage(channel, answer.toString());
  }

  List<String> decipherCMD(String command, List<String> content) {
    int index = content.indexOf(command);
    if (index < 0 || index > content.length-2)
      return new List<String>();
    return content.getRange(++index, content.length).map((elem) => elem.toLowerCase()).toList();
  }

  bool onChannelMessage(String channel, String message, Connection cnx) {
    var sentence = message.split(':').join(' ').split(' ');
    bool oneCommandCalled = false;
    for (var command in commands.keys) {
      decipherCMD(command, sentence).forEach((arg) {
        if (arg != null && arg.isNotEmpty) {
          commands[command](arg.toLowerCase(), channel, cnx);
          oneCommandCalled = true;
        }
      });
    }
    if (!oneCommandCalled && message.contains(BOT_NAME))
      cnx.sendMessage(channel, "Sorry, your command hasn't been recognized ${HELP_MESSAGE}");
    return false;
  }

  bool onPrivateMessage(String user, String message, Connection cnx) =>
      onChannelMessage(user, message, cnx);
}