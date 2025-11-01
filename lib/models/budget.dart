
class Budget {
  final String id;
  final String category;
  final double limit;
  final double spent;
  final bool isCompulsory;

  Budget({
    required this.id,
    required this.category,
    required this.limit,
    required this.spent,
    required this.isCompulsory,
  });
}
