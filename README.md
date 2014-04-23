cupstream2distro-bot
====================

A dart experiment for an IRC bot on cupstream2distro

It handles asynchronous download from a file or a spreadsheet to compute the silo and requests manager.
It  notify about new events on the spreadsheet in an IRC channel.

You can as well use some public or private commands to get live information on requests, like:
 * help
 * inspect [siloname|line]
 * status [siloname|line]
 * where [component name]
 * who [lander name]

They can be issued publicly (but help, to avoid flooding a channel) or privately.
