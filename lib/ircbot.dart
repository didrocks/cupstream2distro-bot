library silomanager.ircbot;

import 'dart:async';
import 'dart:io';

import 'package:irc_client/irc_client.dart';

const BOT_NAME = "CI-SNCF";
const BOT_QUIT_OWNER = "didrocks";
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
    connect = bot.connect("irc.freenode.net", 6667);
  }

  addHandler(Handler newHandler) => bot.handlers.add(newHandler);
  sendMessage(String message) => connect.sendMessage(CHANNEL, message);
}

class _BotHandler extends Handler {

  bool onPrivateMessage(String user, String message, Connection cnx) {
    if (message.toLowerCase() == "help") {
      cnx.sendMessage(user, HELP_MESSAGE);
    } else if (message.toLowerCase() == "quit" && user == BOT_QUIT_OWNER){
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
}