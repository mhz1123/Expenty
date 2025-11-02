
class SmsConfig {
  final String id;
  final String senderId;
  final List<String> debitKeywords;
  final List<String> creditKeywords;

  SmsConfig({
    required this.id,
    required this.senderId,
    required this.debitKeywords,
    required this.creditKeywords,
  });
}
