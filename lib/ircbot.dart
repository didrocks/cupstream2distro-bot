library silomanager.ircbot;

import 'dart:async';
import 'dart:io';

import 'package:irc_client/irc_client.dart';
import 'package:logging/logging.dart';


import 'package:cupstream2distrobot/silomanager-src/silo.dart';
final Logger log = new Logger('SiloManager');

const BOT_NAME = "CI-SNCF";
var CHANNEL = "#ubuntu-ci-choo-choo";
const HELP_MESSAGE = "I notify about new events on the spreadsheet. You can as well use 'inspect [siloname|line]', 'status [siloname|line]', "
  "'where [component name]', 'who [lander name]' to get information on requests. You can PM me to get the answers without flooding the channel.";

class IRC {
  IrcClient bot;
  Connection connect;

  IRC({bool testmode: false}) {
    if (testmode) {
      CHANNEL += "-test";
    }
    bot = new IrcClient(BOT_NAME + (testmode ? "-test" : ""));
    bot.realName = "CI Train bot";
    bot.handlers.add(new _BotHandler());
    log.fine("Connecting bot to IRC");
    connect = bot.connect("irc.freenode.net", 6667);
  }

  addHandler(Handler newHandler) => bot.handlers.add(newHandler);
  sendMessage(String message) => connect.sendMessage(CHANNEL, message);
}

class _BotHandler extends Handler {

  bool onPrivateMessage(String user, String message, Connection cnx) {
    if (message.toLowerCase() == "help") {
      cnx.sendMessage(user, HELP_MESSAGE);
    } else if (message.toLowerCase() == "quit" && BOT_OWNERS.contains(user)){
      cnx.sendMessage(CHANNEL, "Bye: quitting was requested. Will be back soon.");
      cnx.close();
      new Future(() => exit(0));
    }
    return false;
  }

  bool onConnection(Connection cnx) {
    cnx.join(CHANNEL);
    cnx.sendMessage(CHANNEL, "I'm baaack!");
    return false;
  }

  bool onDisconnection(Connection cnx) {
    log.warning("Disconnected, waiting for 30s and trying to reconnect if not quitting beforehand");
    new Timer(const Duration(seconds: 30), () => cnx.connect());
    return true;
  }

}