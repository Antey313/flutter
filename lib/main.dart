import 'package:flutter/material.dart';
import 'package:enough_convert/enough_convert.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// Достаём charset из Content-Type (у ЦБ это windows-1251).
String? _charsetOf(http.Response response) {
  final contentType = response.headers['content-type'] ?? '';
  final match = RegExp(r'charset=([^\s;]+)', caseSensitive: false)
      .firstMatch(contentType);
  return match?.group(1)?.toLowerCase().replaceAll('"', '');
}

/// Декодируем тело ответа в правильной кодировке.
///
/// Нюанс: ЦБ отдаёт XML в windows-1251, а Dart под капотом знает только
/// UTF-8/Latin-1/ASCII — при прямом response.body русские названия валют
/// превращаются в «кракозябры» («Àâñòðàëèéñêèé äîëëàð»).
String decodeBody(http.Response response) {
  final charset = _charsetOf(response);

  // windows-1251 среди встроенных кодировок Dart нет, поэтому enough_convert
  if (charset != null &&
      (charset.contains('1251') || charset.contains('1250'))) {
    return const Windows1251Codec(allowInvalid: false)
        .decode(response.bodyBytes);
  }

  // Для стандартных кодировок (UTF-8 и др.) подойдёт response.body,
  // пакет http сам применяет charset из Content-Type
  return response.body;
}

/// Модель курса валюты из XML-ответа ЦБ РФ.
class CurrencyRate {
  final String code;
  final String name;
  final double value;
  final int nominal;

  const CurrencyRate({
    required this.code,
    required this.name,
    required this.value,
    required this.nominal,
  });
}

/// Вспомогательная функция: вернуть текст первого дочернего элемента с именем
/// [name] или [fallback], если элемента нет.
String _elementText(XmlElement parent, String name, String fallback) {
  final elements = parent.findElements(name);
  if (elements.isEmpty) return fallback;
  return elements.first.innerText.trim();
}

/// Парсим XML-строку от ЦБ РФ в список [CurrencyRate].
List<CurrencyRate> parseCbrXml(String xmlString) {
  final doc = XmlDocument.parse(xmlString);
  final valutes = doc.findAllElements('Valute');
  final List<CurrencyRate> result = [];

  for (final valute in valutes) {
    final code = _elementText(valute, 'CharCode', '');
    final name = _elementText(valute, 'Name', 'Неизвестно');
    final nominalText = _elementText(valute, 'Nominal', '1');
    final valueText = _elementText(valute, 'Value', '0');

    // ЦБ использует запятую, Dart хочет точку
    final double value = double.tryParse(valueText.replaceAll(',', '.')) ?? 0.0;
    final int nominal = int.tryParse(nominalText) ?? 1;

    if (code.isNotEmpty) {
      result.add(CurrencyRate(
        code: code,
        name: name,
        value: value,
        nominal: nominal,
      ));
    }
  }
  return result;
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const CurrencyScreen(),
    );
  }
}

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});

  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  List<CurrencyRate> _rates = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    try {
      final response = await http.get(
        Uri.parse('https://cbr.ru/scripts/XML_Daily.asp'),
      );

      if (response.statusCode != 200) {
        throw Exception('Статус: ${response.statusCode}');
      }

      final rates = parseCbrXml(decodeBody(response));
      setState(() {
        _rates = rates;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Повторная попытка загрузки (кнопка «Попробовать снова»).
  void _retry() {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    _fetchRates();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Курсы валют ЦБ РФ')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Center(
                child: Column(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    Text('Ошибка: $_error'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Попробовать снова'),
                    ),
                  ],
                ),
              ),
            if (!_isLoading && _error == null)
              Expanded(
                child: ListView.builder(
                  itemCount: _rates.length,
                  itemBuilder: (context, index) {
                    final r = _rates[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text(r.code)),
                        title: Text(r.name),
                        subtitle: Text('${r.nominal} ${r.code} = ${r.value.toStringAsFixed(2)} ₽'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
