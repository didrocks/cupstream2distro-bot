library silomanager.silo;

import 'dart:async';

import "package:cupstream2distrobot/silomanager.dart" show log;

part "const.dart";


/*
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

/*
 * Common silo content between
 */
abstract class BaseSilo {
  int line;
  List<String> assignee;
  String description;
  List<String> mps;
  List<String> sources;
  List<String> comment;

  StreamController _messageController = new StreamController.broadcast();
  bool _ready;

  bool get ready => _ready;
  set ready(bool isready) {
    if (_ready == isready)
      return;
    _ready = isready;
    if(_ready)
      _sendMessage("$TRAIN_GUARDS_IRC_NICKNAME_STRING: new silo set as ready at line $line. Description is: $description. It contains: $mps and $sources");
  }

  Stream get message => _messageController.stream;

  BaseSilo(this.line, this.assignee, this.description, this.mps, this.sources,
           this.comment, bool isReady) {
    // trigger an event if is already ready when constructed
    ready = isReady;
  }

  void _sendMessage(message) => _messageController.add(message);

}

//   model.fetchDone.listen((_) => doCoolStuff(model));

class UnassignedSilo extends BaseSilo {
  String id; // artificial ID generated from sources and mps
  static Map<String, UnassignedSilo> _cache;

  factory UnassignedSilo(line, assignee, description, mps, sources, comment, ready) {
    if (_cache == null) {
      _cache = {};
    }
    id = sources.toString(mps.join("") + sources.join(""));

    if (!_cache.containsKey(id)) {
      final silo = new UnassignedSilo._internal(line, assignee, description, mps, sources, comment, ready);
      _cache[id] = silo;
    }
    return _cache[id];
  }

  UnassignedSilo._internal(line, assignee, description, mps, sources, comment, ready)
      : super(line, assignee, description, mps, sources, comment, ready);
}


// TODO: handling freeing an active silo
/*
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
      _sendMessage("$TRAIN_GUARDS_IRC_NICKNAME_STRING, ${assignee.join(", ")}: silo $_siloName is now been freed. It contained: $description");
    else
      _sendMessage("${assignee.join(", ")}: silo $_siloName is now assigned for $description");
    _siloName = newSiloName;
  }
  String _siloName;

  Status get status => _status;
  set status(Status newStatus) {
    if (status == newStatus)
      return;
    _status = newStatus;
    if (status.ping)
      _sendMessage("${assignee.join(", ")} ($siloName): ${_status.message}");
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
          ..comment = comment
          ..ready = ready;
    }
    return silo;
  }

  ActiveSilo._internal(this.id, this._siloName, _status, line, assignee,
                       description, mps, sources, comment, ready)
      : super(line, assignee, description, mps, sources, comment, ready) {
    // ping about the status if the status worthes it
    status = _status;
  }
}
