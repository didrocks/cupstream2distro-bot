library silomanager.csvDataParser;

import 'dart:collection';

import "package:csvparser/csvparser.dart";
import "package:cupstream2distrobot/silomanager.dart" show log;

/*
 * Csv iterator, reading from data and returning
 * a list of String
 */
class CsvIter implements Iterator<List<String>> {
  final CsvParser cp;
  List<String> get current => cp.current.toList();

  CsvIter(String data, {int numLineToSkip: 0})
      : cp = new CsvParser(data) {
    log.finest("Parsing $data");
    log.fine("Skip first $numLineToSkip lines in Csv data");
    while (numLineToSkip > 0) {
      cp.moveNext();
      numLineToSkip--;
    }
  }

  bool moveNext() {
    return cp.moveNext();
  }

}

/*
 * CsvDataParser iterable, returning line by line a
 * list of String.
 */
class CsvDataParser extends IterableBase<List<String>> {
  Iterator<List<String>> iterator;

  CsvDataParser(String data, {int numLineToSkip: 0})
      : iterator = new CsvIter(data, numLineToSkip: numLineToSkip) {}
}
