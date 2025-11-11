import 'package:intl/intl.dart';

/// Utilitário para formatar datas ISO 8601 em uma representação amigável.
String formatDateTimeIso(String isoString) {
  try {
    final parsed = DateTime.parse(isoString).toLocal();
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    final formatted = formatter.format(parsed);
    return '$formatted (${parsed.timeZoneName})';
  } catch (_) {
    return isoString;
  }
}
