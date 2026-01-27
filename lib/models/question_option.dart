class QuestionOption {
  final int id;
  final String optionText;
  final String? optionValue;
  final int orderIndex;

  QuestionOption({
    required this.id,
    required this.optionText,
    this.optionValue,
    required this.orderIndex,
  });

  // Método auxiliar para converter string em int
  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      if (value.isEmpty || value == 'null') return 0;
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  factory QuestionOption.fromJson(Map<String, dynamic> json) {
    print('🔘 === PARSING OPTION ===');
    print('🔘 JSON keys: ${json.keys.toList()}');
    print('🔘 Full JSON: $json');

    try {
      // Detectar qual campo usar para o texto (pode vir como 'text' ou 'option_text')
      String optionText = '';
      if (json['option_text'] != null) {
        optionText = json['option_text'].toString();
        print('🔘 Using option_text: $optionText');
      } else if (json['text'] != null) {
        optionText = json['text'].toString();
        print('🔘 Using text: $optionText');
      } else {
        print('⚠️ NO TEXT FIELD FOUND in option JSON!');
      }

      // Tratar o valor da opção - se estiver vazio, usar o texto
      String? optionValue;
      if (json['option_value'] != null) {
        optionValue = json['option_value'].toString();
        print('🔘 Found option_value: $optionValue');
      } else if (json['value'] != null) {
        optionValue = json['value'].toString();
        print('🔘 Found value: $optionValue');
      }

      if (optionValue != null && optionValue.trim().isEmpty) {
        optionValue = null; // Se for string vazia, usar null para usar o texto
        print('🔘 option_value is empty, will use text');
      }

      // Detectar qual campo usar para order
      int orderIndex = 0;
      if (json['order_index'] != null) {
        orderIndex = _parseInt(json['order_index']);
        print('🔘 Using order_index: $orderIndex');
      } else if (json['order'] != null) {
        orderIndex = _parseInt(json['order']);
        print('🔘 Using order: $orderIndex');
      }

      final option = QuestionOption(
        id: _parseInt(json['id']),
        optionText: optionText,
        optionValue: optionValue,
        orderIndex: orderIndex,
      );

      print('✅ Option parsed successfully: "${option.optionText}" (value: ${option.optionValue ?? 'using text'})');
      return option;

    } catch (e, stackTrace) {
      print('❌ Error in QuestionOption.fromJson: $e');
      print('📋 Stack trace: $stackTrace');
      print('📋 JSON data: $json');
      rethrow;
    }
  }

  // Método toJson() necessário para serialização
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'option_text': optionText,
      'option_value': optionValue,
      'order_index': orderIndex,
    };
  }

  @override
  String toString() {
    return 'QuestionOption{id: $id, text: $optionText, value: ${optionValue ?? "null"}}';
  }
}