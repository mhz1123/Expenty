
class SmsConfig {
  final String senderId;
  final List<String> debitKeywords;
  final List<String> creditKeywords;

  SmsConfig({
    required this.senderId,
    required this.debitKeywords,
    required this.creditKeywords,
  });
}
