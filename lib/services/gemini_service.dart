import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GeminiService {
  static const _apiKey = 'AIzaSyCnIF0S-c8dbmBkFTnNQ6VgzNvPAxgA66o';
  static const _uploadBase =
      'https://generativelanguage.googleapis.com/upload/v1beta/files';
  static const _generateBase =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  Future<int?> countLiftings(File videoFile) async {
    try {
      final fileUri = await _uploadFile(videoFile);
      if (fileUri == null) return null;
      return await _generateCount(fileUri);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _uploadFile(File file) async {
    final bytes = await file.readAsBytes();
    final fileSize = bytes.length;

    // 1. Initiate resumable upload
    final startRes = await http.post(
      Uri.parse('$_uploadBase?key=$_apiKey'),
      headers: {
        'X-Goog-Upload-Protocol': 'resumable',
        'X-Goog-Upload-Command': 'start',
        'X-Goog-Upload-Header-Content-Length': fileSize.toString(),
        'X-Goog-Upload-Header-Content-Type': 'video/mp4',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'file': {'display_name': 'lifting_video'}}),
    );
    final uploadUrl = startRes.headers['x-goog-upload-url'];
    if (uploadUrl == null) return null;

    // 2. Upload data
    final uploadRes = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Content-Length': fileSize.toString(),
        'X-Goog-Upload-Offset': '0',
        'X-Goog-Upload-Command': 'upload, finalize',
      },
      body: bytes,
    );
    if (uploadRes.statusCode != 200) return null;

    final data = jsonDecode(uploadRes.body) as Map<String, dynamic>;
    return (data['file'] as Map<String, dynamic>)['uri'] as String?;
  }

  Future<int?> _generateCount(String fileUri) async {
    final res = await http.post(
      Uri.parse('$_generateBase?key=$_apiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'contents': [
          {
            'parts': [
              {
                'file_data': {'mime_type': 'video/mp4', 'file_uri': fileUri}
              },
              {
                'text':
                    'この動画でサッカーボールのリフティングは何回行われていますか？数字のみで答えてください。判別できない場合は0と答えてください。'
              },
            ]
          }
        ]
      }),
    );
    if (res.statusCode != 200) return null;

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final text = ((((data['candidates'] as List)[0])['content'])['parts']
        as List)[0]['text'] as String;
    return int.tryParse(text.trim().replaceAll(RegExp(r'[^0-9]'), ''));
  }
}
