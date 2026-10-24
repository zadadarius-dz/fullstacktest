import 'package:intl/intl.dart';

final NumberFormat _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final NumberFormat _number = NumberFormat.decimalPattern('id_ID');
final DateFormat _dateTime = DateFormat('dd/MM/yyyy HH:mm');

String formatCurrency(num value) => _currency.format(value);

String formatNumber(num value) => _number.format(value);

String formatDateTime(DateTime? value) =>
    value == null ? '-' : _dateTime.format(value.toLocal());
