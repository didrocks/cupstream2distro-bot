import 'package:logging/logging.dart';

/*
 * Setup a root Logger level (will be used in each isolates as well)
 */
void setupRootLogger(Level level) {
  Logger.root.level = level;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: [${rec.loggerName}] ${rec.time}: ${rec.message}');
  });
}