class ConditionalLogic {
  final ConditionalRule? visibility;
  final ConditionalRule? required;

  ConditionalLogic({
    this.visibility,
    this.required,
  });

  bool get hasRules => visibility != null || required != null;

  factory ConditionalLogic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return ConditionalLogic();

    return ConditionalLogic(
      visibility: json['visibility'] != null 
          ? ConditionalRule.fromJson(json['visibility']) 
          : null,
      required: json['required'] != null 
          ? ConditionalRule.fromJson(json['required']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (visibility != null) 'visibility': visibility!.toJson(),
      if (required != null) 'required': required!.toJson(),
    };
  }
}

class ConditionalRule {
  final String operator; // 'AND' ou 'OR'
  final List<ConditionalCondition> conditions;

  ConditionalRule({
    required this.operator,
    required this.conditions,
  });

  factory ConditionalRule.fromJson(Map<String, dynamic> json) {
    return ConditionalRule(
      operator: json['operator']?.toString().toUpperCase() ?? 'AND',
      conditions: (json['conditions'] as List? ?? [])
          .map((condition) => ConditionalCondition.fromJson(condition))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'operator': operator,
      'conditions': conditions.map((c) => c.toJson()).toList(),
    };
  }

  /// Avalia se a regra é verdadeira baseada nas respostas fornecidas
  bool evaluate(Map<int, dynamic> responses) {
    if (conditions.isEmpty) return true;

    final results = conditions.map((condition) => condition.evaluate(responses));

    if (operator.toUpperCase() == 'OR') {
      return results.any((result) => result);
    } else {
      // Default: AND
      return results.every((result) => result);
    }
  }
}

class ConditionalCondition {
  final int questionId;
  final String operator; // 'equals', 'not_equals', 'contains', 'not_contains', 'greater_than', 'less_than'
  final dynamic value;

  ConditionalCondition({
    required this.questionId,
    required this.operator,
    required this.value,
  });

  factory ConditionalCondition.fromJson(Map<String, dynamic> json) {
    return ConditionalCondition(
      questionId: _parseInt(json['question'] ?? json['question_id']), // CORREÇÃO: aceitar ambos os formatos
      operator: json['operator']?.toString() ?? 'equals',
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': questionId, // CORREÇÃO: usar 'question' como padrão
      'operator': operator,
      'value': value,
    };
  }

  /// Avalia se a condição é verdadeira baseada na resposta da pergunta
  bool evaluate(Map<int, dynamic> responses) {
    final response = responses[questionId];
    
    // Se não há resposta, considera false (exceto para alguns operadores específicos)
    if (response == null) {
      return operator == 'not_equals' || operator == 'not_contains';
    }

    switch (operator.toLowerCase()) {
      case 'equals':
        return _compareEquals(response, value);
      
      case 'not_equals':
        return !_compareEquals(response, value);
      
      case 'contains':
        return _compareContains(response, value);
      
      case 'not_contains':
        return !_compareContains(response, value);
      
      case 'greater_than':
        return _compareGreaterThan(response, value);
      
      case 'less_than':
        return _compareLessThan(response, value);
      
      case 'greater_than_or_equal':
        return _compareGreaterThanOrEqual(response, value);
      
      case 'less_than_or_equal':
        return _compareLessThanOrEqual(response, value);
      
      case 'is_empty':
        return _isEmpty(response);
      
      case 'is_not_empty':
        return !_isEmpty(response);
      
      default:
        print('⚠️ Operador não reconhecido: $operator');
        return false;
    }
  }

  bool _compareEquals(dynamic response, dynamic value) {
    // Para listas (checkbox), verificar se contém o valor
    if (response is List) {
      return response.contains(value?.toString());
    }
    
    return response?.toString() == value?.toString();
  }

  bool _compareContains(dynamic response, dynamic value) {
    if (response is List) {
      return response.any((item) => item?.toString().contains(value?.toString() ?? '') == true);
    }
    
    return response?.toString().contains(value?.toString() ?? '') == true;
  }

  bool _compareGreaterThan(dynamic response, dynamic value) {
    final responseNum = _parseNumber(response);
    final valueNum = _parseNumber(value);
    
    if (responseNum == null || valueNum == null) return false;
    
    return responseNum > valueNum;
  }

  bool _compareLessThan(dynamic response, dynamic value) {
    final responseNum = _parseNumber(response);
    final valueNum = _parseNumber(value);
    
    if (responseNum == null || valueNum == null) return false;
    
    return responseNum < valueNum;
  }

  bool _compareGreaterThanOrEqual(dynamic response, dynamic value) {
    final responseNum = _parseNumber(response);
    final valueNum = _parseNumber(value);
    
    if (responseNum == null || valueNum == null) return false;
    
    return responseNum >= valueNum;
  }

  bool _compareLessThanOrEqual(dynamic response, dynamic value) {
    final responseNum = _parseNumber(response);
    final valueNum = _parseNumber(value);
    
    if (responseNum == null || valueNum == null) return false;
    
    return responseNum <= valueNum;
  }

  bool _isEmpty(dynamic response) {
    if (response == null) return true;
    if (response is String) return response.trim().isEmpty;
    if (response is List) return response.isEmpty;
    return false;
  }

  double? _parseNumber(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

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
}

// Classe QuestionState para o FormProvider
class QuestionState {
  final bool visible;
  final bool required;
  final bool originalRequired;

  QuestionState({
    required this.visible,
    required this.required,
    required this.originalRequired,
  });

  @override
  String toString() => 'QuestionState(visible: $visible, required: $required, originalRequired: $originalRequired)';
}

// Classe ValidationResult para validações
class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });
}