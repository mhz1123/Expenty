
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

  Budget copyWith({
    String? id,
    String? category,
    double? limit,
    double? spent,
    bool? isCompulsory,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      limit: limit ?? this.limit,
      spent: spent ?? this.spent,
      isCompulsory: isCompulsory ?? this.isCompulsory,
    );
  }
}
