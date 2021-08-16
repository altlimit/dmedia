import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dmedia/background.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' as hp;
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:dmedia/util.dart';
import 'package:dmedia/models.dart';
import 'package:dio/dio.dart';

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
              .timeout(Duration(seconds: 5));
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
      if (data != null || method != null) {
        if (!isRelease) print('Payload: ' + json.encode(data));
        var m = http.post;
        if (method == 'PUT')
          m = http.put;
        else if (method == 'PATCH')
          m = http.patch;
        else if (method == 'DELETE') m = http.delete;
        resp = await m(uri, body: json.encode(data), headers: headers);
      } else {
        resp = await http.get(uri, headers: headers);
      }
      if (resp.statusCode != 200 || !isRelease) print('response: ' + resp.body);
      return resp.body.length > 0 ? json.decode(resp.body) : null;
    } on SocketException {
      Bg.emit({
        'task': 'client',
        'data': {'message': 'Not connected to internet'}
      });
      return {'error': 'connection failed'};
    } on TimeoutException {
      Bg.emit({
        'task': 'client',
        'data': {'message': 'Conntection timeout'}
      });
      return {'error': 'connection timeout'};
    } on FormatException {
      Bg.emit({
        'task': 'client',
        'data': {'message': 'Unexpected response'}
      });
      return {'error': 'unexpected response'};
    } on Exception catch (e) {
      print('Error: ' + e.toString());
      Bg.emit({
        'task': 'client',
        'data': {'message': 'Unknown error'}
      });
      return {'error': e.toString()};
    }
  }

  Future<dynamic> upload(String path,
      {Function(int, int, int, int)? onProgress,
      Function(FileStat)? onStat}) async {
    await init();

    final stat = await FileStat.stat(path);
    if (onStat != null) onStat(stat);
    final ext = p.extension(path).toLowerCase();
    var cType =
        MimeTypes.containsKey(ext) ? MimeTypes[ext] : lookupMimeType(path);
    if (cType != null &&
        (cType.startsWith('image/') || cType.startsWith('video/'))) {
      try {
        final dio = Dio(BaseOptions(headers: headers));
        var lastProgress = -1;
        final startTime = DateTime.now().millisecondsSinceEpoch;
        final response = await dio.post(selectedUrl + '/api/upload',
            data: await FormData.fromMap({
              'fallbackDate': Util.dateTimeToString(stat.modified),
              'file': await MultipartFile.fromFile(path,
                  filename: p.basename(path),
                  contentType: hp.MediaType.parse(cType))
            }), onSendProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            final newProgress = (received / total * 100).toInt();
            if (newProgress != lastProgress) {
              final duration =
                  (DateTime.now().millisecondsSinceEpoch - startTime) / 1000;
              lastProgress = newProgress;
              onProgress(lastProgress, received ~/ duration, received, total);
            }
          }
        }).timeout(Duration(hours: 24));
        return response.data;
      } on DioError catch (e) {
        Util.debug('Response: ${e.response}');
        return e.response?.data;
      }
    }
    return null;
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

  Future<List<Media>> getMediaList(
      {Map<String, String>? qs, Function(int)? onPages}) async {
    Map<String, dynamic> response = await request(
        '/api/media?' + (qs != null ? Uri(queryParameters: qs).query : ''));
    if (response['result'] != null) {
      if (onPages != null) onPages(response['pages'] as int);
      final List<dynamic> result = response['result'];
      return result.map((m) => Media.fromMap(m)).toList();
    }
    return [];
  }

  Future deleteMedia(List<int> id) async {
    await request('/api/media/${id.join('-')}', method: 'DELETE');
  }

  Future restoreMedia(List<int> id) async {
    await request('/api/media/${id.join('-')}/restore', method: 'PATCH');
  }
}
