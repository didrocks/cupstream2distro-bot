library silomanager.ircbot;

import 'package:irc_client/irc_client.dart';

const CHANNEL = "#ubuntu-ci-choo-choo";

class IRC {
  IrcClient bot;
  Connection connect;

  IRC() {
    bot = new IrcClient("CI-SNCF");
    bot.realName = "CI Train bot";
    bot.handlers.add(new _BotHandler());
    connect = bot.connect("irc.freenode.net", 6667);
  }

  sendMessage(String message) {
    connect.sendMessage(CHANNEL, message);
  }
}

class _BotHandler extends Handler {
  bool onChannelMessage(String channel, String message, Connection cnx) {
    if (message.toLowerCase().contains("hello")) {
      cnx.sendMessage(channel, "Hey!");
    }
    return true;
  }

  bool onPrivateMessage(String user, String message, Connection cnx) {
    if (message.toLowerCase() == "help") {
      cnx.sendNotice(user, "I'm the kind CI Train bot!");
    }
    return true;
  }

  bool onConnection(Connection cnx) {
    cnx.join(CHANNEL);
    cnx.sendMessage(CHANNEL, "I'm baaack!");
    return true;
  }
}