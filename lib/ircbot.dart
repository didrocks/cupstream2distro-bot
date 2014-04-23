library silomanager.ircbot;

import 'package:irc_client/irc_client.dart';

const BOT_NAME = "CI-SNCF";
const CHANNEL = "#ubuntu-ci-choo-choo";
const HELP_MESSAGE = "I notify about new events on the spreadsheet. You can as well use 'inspect [siloname|line]', 'status [siloname|line]', "
  "'where [component name]', 'who [lander name]' to get information on requests. You can PM me to get the answers without flooding the channel.";

class IRC {
  IrcClient bot;
  Connection connect;

  IRC() {
    bot = new IrcClient(BOT_NAME);
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
    }
    return false;
  }

  bool onConnection(Connection cnx) {
    cnx.join(CHANNEL);
    cnx.sendMessage(CHANNEL, "I'm baaack!");
    return false;
  }
}