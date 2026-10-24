import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockmate_mobile/core/utils/formatters.dart';
import 'package:stockmate_mobile/widgets/async_state.dart';
import 'package:stockmate_mobile/widgets/section_card.dart';

void main() {
  group('formatters', () {
    test('formatCurrency memakai format Rupiah tanpa desimal', () {
      expect(formatCurrency(1250000), 'Rp 1.250.000');
    });

    test('formatNumber memakai pemisah ribuan', () {
      expect(formatNumber(1500), '1.500');
    });

    test('formatDateTime mengembalikan tanda hubung untuk null', () {
      expect(formatDateTime(null), '-');
    });
  });

  group('widget', () {
    testWidgets('InlineMessage menampilkan pesan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: InlineMessage(message: 'Terjadi kesalahan')),
        ),
      );

      expect(find.text('Terjadi kesalahan'), findsOneWidget);
    });

    testWidgets('StockBadge menampilkan jumlah stok', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StockBadge(stock: 4, minStock: 10),
          ),
        ),
      );

      expect(find.text('4'), findsOneWidget);
    });
  });
}
