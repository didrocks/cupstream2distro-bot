library silomanager;

import 'dart:convert';
import 'dart:io';

import "package:cupstream2distrobot/silomanager-src/silo.dart";
import 'package:logging/logging.dart';
import 'package:cupstream2distrobot/silomanager-src/csvdataparser.dart';


final Logger log = new Logger('SiloManager');


void run() {

  var file = new File('/home/didrocks/work/cupstream2distrobot/testcontent.csv');
  file.readAsString(encoding: const Utf8Codec())
      .then((content) {
      var value = new CsvDataParser(content);
      for (var i in value) {
        log.warning(i.toString());
      }
      });


  /*var activeSilos = new List<Silo>();

  activeSilos..add(new Silo("1"))
             ..add(new Silo("1"))
             ..add(new Silo("2"));

  print(identical(activeSilos[0], activeSilos[1]));
  print(identical(activeSilos[0], activeSilos[2]));
  print(identical(activeSilos[1], activeSilos[2]));*/
}