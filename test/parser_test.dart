import 'package:flutter_test/flutter_test.dart';

import 'package:currency_demo/main.dart';

// Тесты парсинга XML-ответа ЦБ РФ (без сети: во flutter_test все
// HTTP-запросы перехватываются и сеть доступна только через моки).

String _makeXml(String value) {
  return '''
  <ValCurs Date="28.10.2026" name="Foreign Currency Market">
    <Valute ID="R01235">
      <NumCode>840</NumCode>
      <CharCode>USD</CharCode>
      <Scale>1</Scale>
      <Nominal>1</Nominal>
      <Name>Доллар США</Name>
      <Value>$value</Value>
    </Valute>
  </ValCurs>
  ''';
}

void main() {
  group('parseCbrXml', () {
    test('парсит валидный XML ЦБ РФ и заменяет запятую на точку', () {
      final rates = parseCbrXml(_makeXml('91,4500'));

      expect(rates.length, 1);
      expect(rates.first.code, 'USD');
      expect(rates.first.name, 'Доллар США');
      expect(rates.first.nominal, 1);
      expect(rates.first.value, closeTo(91.45, 0.0001));
    });

    test('обрабатывает номинал, не равный 1', () {
      final rates = parseCbrXml(_makeXml('183,9012'));
      // Nominal в этом XML равен 1, поэтому без изменения
      expect(rates.first.nominal, 1);
      expect(rates.first.value, closeTo(183.9012, 0.0001));
    });

    test('пропускает элементы без CharCode', () {
      final xml = '<ValCurs><Valute><Name>Без кода</Name></Valute></ValCurs>';
      expect(parseCbrXml(xml), isEmpty);
    });

    test('нечисловое значение даёт 0.0, но валюту не теряет', () {
      final rates = parseCbrXml(_makeXml('абв'));
      expect(rates.length, 1);
      expect(rates.first.value, 0.0);
    });
  });
}
