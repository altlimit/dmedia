import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as hp;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:dmedia/util.dart';
import 'package:dmedia/models.dart';

class Client {
  Account account;
  String selectedUrl = "";
  late Map<String, String> headers;

  Client(this.account) {
    headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Basic ' +
          base64Encode(utf8.encode('${account.username}:${account.password}'))
    };
  }

  Future<void> init() async {
    if (selectedUrl.length == 0) {
      var urls = account.serverUrl.split("|");
      for (var i = 0; i < urls.length; i++) {
        if (selectedUrl.length == 0) {
          var resp = await http
              .get(Uri.parse(urls[i] + '/status'))
              .timeout(Duration(seconds: 1));
          if (resp.statusCode == 200) {
            selectedUrl = urls[i];
            break;
          }
        }
      }
    }
  }

  Future<dynamic> request(String path, {dynamic data, String? method}) async {
    http.Response resp;
    try {
      await init();
      var uri = Uri.parse(selectedUrl + path);
      if (data != null) {
        if (!isRelease) print('Payload: ' + json.encode(data));
        var m = http.post;
        if (method == 'PUT')
          m = http.put;
        else if (method == 'DELETE') m = http.delete;
        resp = await m(uri, body: json.encode(data), headers: headers);
      } else {
        resp = await http.get(uri, headers: headers);
      }
      if (resp.statusCode != 200 || !isRelease) print('response: ' + resp.body);
      return resp.body.length > 0 ? json.decode(resp.body) : null;
    } on SocketException {
      print('Not connected to internet');
      return {'error': 'connection failed'};
    } on TimeoutException {
      print('Not connected to internet');
      return {'error': 'connection timeout'};
    } on FormatException {
      return {'error': 'unexpected response'};
    } on Exception catch (e) {
      print('Error: ' + e.toString());
      return {'error': e.toString()};
    }
  }

  Future<int> upload(String path) async {
    try {
      await init();
      final uri = Uri.parse(selectedUrl + '/api/upload');
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(headers);
      final stat = await FileStat.stat(path);
      request.fields['fallbackDate'] = Util.dateTimeToString(stat.modified);
      var cType = lookupMimeType(path);
      if (cType != null &&
          (cType.startsWith('image/') || cType.startsWith('video/'))) {
        request.files.add(http.MultipartFile.fromBytes(
            'file', await File.fromUri(Uri.parse(path)).readAsBytes(),
            filename: p.basename(path),
            contentType: hp.MediaType.parse(cType)));

        var response = await request.send();
        if (response.statusCode == 200) {
          return int.parse(await response.stream.bytesToString());
        } else if (!isRelease) {
          print('Response: ' + await response.stream.bytesToString());
        }
      }
      return 0;
    } catch (e) {
      print('Error: ' + e.toString());
      return 0;
    }
  }

  Map<String, String>? checkError(Map<String, dynamic>? data) {
    if (data != null &&
        data.containsKey('error') &&
        data.containsKey('params') &&
        data['error'] == 'validation') {
      return (data['params'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
    }
    return data != null && data.containsKey('error')
        ? {'message': data['error']}
        : null;
  }
}
