class FoodItem {
  FoodItem({
    this.id,
    required this.name,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.carb,
    required this.fat,
    required this.source,
    this.confidence,
  });

  final String? id;
  String name;
  String quantity;
  double calories;
  double protein;
  double carb;
  double fat;
  String source; // 'ai' | 'user_edited'
  String? confidence; // 'high' | 'low' — only meaningful for unsaved AI results

  factory FoodItem.fromGemini(Map<String, dynamic> json) {
    return FoodItem(
      name: json['name'] as String,
      quantity: json['quantity'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carb: (json['carb'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      source: 'ai',
      confidence: json['confidence'] as String?,
    );
  }

  Map<String, dynamic> toInsertRow(String mealEntryId) => {
        'meal_entry_id': mealEntryId,
        'name': name,
        'quantity': quantity,
        'calories': calories,
        'protein': protein,
        'carb': carb,
        'fat': fat,
        'source': source,
      };
}
