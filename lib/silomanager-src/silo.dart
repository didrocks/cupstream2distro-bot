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
  bool publishable;

  operator ==(Status other) => message == other.message && publishable == other.publishable;

  Status(this.message, this.jobUrl, this.ping, this.publishable);
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
  get statusMessage;
  String get statusRequest => "at line $line. Requested by $assignee. Contains: $description for $mps and $sources. Current comment: $comment";


  BaseSilo(this.line, this.assignee, this.description, this.mps, this.sources,
           this.comment);

  void sendMessage(message) {
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
      sendMessage("$TRAIN_GUARDS: new silo set as ready at line $line. Description is: $description. It contains: $mps and $sources");
  }

  String get statusMessage => "unassigned. Ready is set to ${ready ? 'Yes': 'No'}";
  String get statusRequest => "Request " + super.statusRequest + " " + statusMessage;

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

  /**
   * Detach current element from cache
   */
  UnassignedSilo detachFromCache() => _cache.remove(this);
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
    sendMessage("${assignee.join(", ")}: silo $newSiloName is now assigned for $description");
    _siloName = newSiloName;
  }
  String _siloName;

  Status get status => _status;
  set status(Status newStatus) {
    if (status == newStatus)
      return;
    _status = newStatus;
    if (status.ping) {
      if (status.publishable) {
        sendMessage("$TRAIN_GUARDS ($siloName): ${status.message}");
      } else {
        sendMessage("${assignee.join(", ")} ($siloName): ${statusMessage}");
      }
    }
  }
  Status _status;

  String get statusMessage {
    var message = status.message;
    if (status.publishable)
      message += " and ready to publish";
    if (status.jobUrl.isNotEmpty)
      message += " (${_status.jobUrl})";
    return message;
  }

  String get statusRequest => "Silo $siloName. " + super.statusRequest;

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

  /**
   * Detach current element from cache
   */
  ActiveSilo detachFromCache() => _cache.remove(this);
}
