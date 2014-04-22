library silomanager.silo;

import 'dart:async';

import "package:cupstream2distrobot/silomanager.dart" show log;

part "const.dart";


/**
 * Different available status. We discare the jobUrl or ping
 * as an identifier.
 */
class Status {
  String message;
  String jobUrl;
  bool ping;

  operator ==(Status other) => message == other.message;

  Status(this.message, this.jobUrl, this.ping);
}

/**
 * Common silo content between
 */
abstract class BaseSilo {
  int line;
  List<String> assignee;
  String description;
  List<String> mps;
  List<String> sources;
  String comment;

  StreamController _messageController = new StreamController.broadcast();

  Stream get message => _messageController.stream;

  BaseSilo(this.line, this.assignee, this.description, this.mps, this.sources,
           this.comment);

  void _sendMessage(message) {
    log.fine("Sending: $message");
    _messageController.add(message);
  }

}

//   model.fetchDone.listen((_) => doCoolStuff(model));
/**
 * Unassigned silos
 */
class UnassignedSilo extends BaseSilo {
  String id; // artificial ID generated from sources and mps
  static Map<String, UnassignedSilo> _cache;

  bool _ready;

  bool get ready => _ready;
  set ready(bool isready) {
    if (_ready == isready)
      return;
    _ready = isready;
    if(_ready)
      _sendMessage("$TRAIN_GUARDS_IRC_NICKNAME_STRING: new silo set as ready at line $line. Description is: $description. It contains: $mps and $sources");
  }


  factory UnassignedSilo(line, assignee, description, mps, sources, comment, ready) {
    if (_cache == null) {
      _cache = {};
    }
    var id = mps.join("") + sources.join("");

    var silo;
    if (!_cache.containsKey(id)) {
      silo = new UnassignedSilo._internal(id, line, assignee, description, mps, sources, comment, ready);
      _cache[id] = silo;
    }
    else {
      silo = _cache[id]
          ..line = line
          ..assignee = assignee
          ..description = description
          ..mps = mps
          ..sources = sources
          ..comment = comment
          ..ready = ready;
    }
    return silo;
  }

  UnassignedSilo._internal(id, line, assignee, description, mps, sources, comment, isReady)
      : super(line, assignee, description, mps, sources, comment) {
    this.id = id;
    // trigger an event if is already ready when constructed
    scheduleMicrotask(() => this.ready = isReady);
    log.finer("Build a new unassigned silo for line: $line, $assignee, $description, $mps, $sources");
  }
}


/**
 * Active and assigned silo class name
 */
class ActiveSilo extends BaseSilo {
  String id;
  static Map<String, ActiveSilo> _cache;

  String get siloName => _siloName;
  set siloName(String newSiloName) {
    if (_siloName == newSiloName)
      return;
    if (newSiloName.isEmpty && _siloName.isNotEmpty)
      _sendMessage("$TRAIN_GUARDS_IRC_NICKNAME_STRING, ${assignee.join(", ")}: silo $newSiloName has now been freed. It contained: $description");
    else
      _sendMessage("${assignee.join(", ")}: silo $newSiloName is now assigned for $description");
    _siloName = newSiloName;
  }
  String _siloName;

  Status get status => _status;
  set status(Status newStatus) {
    if (status == newStatus)
      return;
    _status = newStatus;
    var message = "${assignee.join(", ")} ($siloName): ${_status.message}";
    if (_status.jobUrl.isNotEmpty)
      message += " (${_status.jobUrl})";
    if (status.ping)
      _sendMessage(message);
  }
  Status _status;

  factory ActiveSilo(id, _siloName, _status, line, assignee,
                     description, mps, sources, comment, ready) {
    if (_cache == null) {
      _cache = {};
    }

    var silo;
    if (!_cache.containsKey(id)) {
      silo = new ActiveSilo._internal(id, _siloName, _status, line, assignee,
                                            description, mps, sources, comment, ready);
      _cache[id] = silo;
    }
    // just refresh fields
    else {
      silo = _cache[id]
          ..siloName = _siloName
          ..status = _status
          ..line = line
          ..assignee = assignee
          ..description = description
          ..mps = mps
          ..sources = sources
          ..comment = comment;
    }
    return silo;
  }

  ActiveSilo._internal(this.id, this._siloName, _status, line, assignee,
                       description, mps, sources, comment, ready)
      : super(line, assignee, description, mps, sources, comment) {
    // ping about the status if the status worthes it
    scheduleMicrotask(() => status = _status);
    log.finer("Build a new active silo for $id, silo: $siloName, $assignee, line: $line");
  }
}
