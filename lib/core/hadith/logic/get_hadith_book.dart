import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart' as dio;
import 'package:nabd/core/hadith/data/books.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

getBookByName(bookFileName) async {
  var book;
  var appDir = await path_provider.getTemporaryDirectory();

  if (File("${appDir.path}/$bookFileName").existsSync()) {
    File file = File("${appDir.path}/$bookFileName");

    String jsonData = await file.readAsString();
    book = json.decode(jsonData);
  }

  return book;
}

downloadBook(bookFileName) async {
  var appDir = await path_provider.getTemporaryDirectory();
  // getTemporaryDirectory لا يحتاج أي إذن (App-private storage)

  await dio.Dio().download(
      "$baseHadithUrl/$bookFileName", "${appDir.path}/$bookFileName",
      options: dio.Options(
          headers: {HttpHeaders.acceptEncodingHeader: "*"}), // disable gzip
      onReceiveProgress: (received, total) {
    if (total != -1) {
      print("${(received / total * 100).toStringAsFixed(0)}%");
    }
  });
}
