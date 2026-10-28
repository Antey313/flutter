// Запускается через: dart run bin/check_encoding.dart
// ignore_for_file: avoid_print
import 'package:enough_convert/enough_convert.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  final response =
      await http.get(Uri.parse('https://cbr.ru/scripts/XML_Daily.asp'));
  print('status: ${response.statusCode}');
  print('content-type: ${response.headers['content-type']}');

  final decoded = const Windows1251Codec(allowInvalid: false)
      .decode(response.bodyBytes);
  print('первые 400 символов после декодирования windows-1251:');
  print(decoded.substring(0, 400));
}
