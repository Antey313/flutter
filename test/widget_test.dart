import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:currency_demo/main.dart';

// Тест UI-состояний экрана. Сеть во flutter_test недоступна: HTTP-запрос
// перехватывается и завершается ошибкой, поэтому экран должен показать
// состояние ошибки с кнопкой «Попробовать снова».

void main() {
  testWidgets('экран показывает состояние ошибки, если запрос не удался',
      (tester) async {
    await tester.pumpWidget(const MyApp());

    // Сначала должно быть состояние загрузки
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Даём запросу завершиться ошибкой
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    // Появилось сообщение об ошибке и кнопка повтора
    expect(find.textContaining('Ошибка'), findsOneWidget);
    expect(find.text('Попробовать снова'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
