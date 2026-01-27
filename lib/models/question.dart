import 'dart:convert';

import 'question_option.dart';
import 'conditional_logic.dart';

class Question {
  final int id;
  final int questionnaireId;
  final String questionText;
  final String questionType;
  final bool isRequired;
  final int orderIndex;
  final Map<String, dynamic>? conditionalLogic;
  final List<QuestionOption> options;

  // Propriedades computadas para lógica condicional
  ConditionalLogic? _parsedLogic;

  Question({
    required this.id,
    required this.questionnaireId,
    required this.questionText,
    required this.questionType,
    required this.isRequired,
    required this.orderIndex,
    this.conditionalLogic,
    this.options = const [],
  });

  /// Retorna a lógica condicional parseada
  ConditionalLogic? get parsedConditionalLogic {
    _parsedLogic ??= ConditionalLogic.fromJson(conditionalLogic);
    return _parsedLogic;
  }

  /// Verifica se a pergunta tem lógica condicional
  bool get hasConditionalLogic {
    return parsedConditionalLogic?.hasRules == true;
  }

  /// Verifica se tem regras de visibilidade
  bool get hasVisibilityRules {
    return parsedConditionalLogic?.visibility != null;
  }

  /// Verifica se tem regras de obrigatoriedade
  bool get hasRequiredRules {
    return parsedConditionalLogic?.required != null;
  }

  /// Retorna um resumo da lógica condicional para debug
  String get conditionalLogicSummary {
    final logic = parsedConditionalLogic;
    if (logic == null || !logic.hasRules) return 'Nenhuma lógica';

    final parts = <String>[];

    if (logic.visibility != null) {
      final condCount = logic.visibility!.conditions.length;
      final operator = logic.visibility!.operator;
      parts.add('Visibilidade: $condCount condição(ões) com $operator');
    }

    if (logic.required != null) {
      final condCount = logic.required!.conditions.length;
      final operator = logic.required!.operator;
      parts.add('Obrigatória: $condCount condição(ões) com $operator');
    }

    return parts.join(' | ');
  }

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

  // Método auxiliar para converter string em bool (lidando com 't'/'f')
  static bool _parseBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) {
      return value.toLowerCase() == 't' ||
          value.toLowerCase() == 'true' ||
          value == '1';
    }
    if (value is int) return value == 1;
    return false;
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    print('📄 === PARSING QUESTION ===');
    print('📄 Question text: ${json['question_text']}');
    print('📄 Question type: ${json['question_type']}');
    print('📄 Full JSON: $json');

    try {
      // Parse das opções
      List<QuestionOption> optionsList = [];

      print('📘 Checking for options in JSON...');
      if (json['options'] != null) {
        final optionsData = json['options'];
        print('📘 Options data type: ${optionsData.runtimeType}');
        print('📘 Options data: $optionsData');

        if (optionsData is List) {
          print('📘 Found ${optionsData.length} options in list');

          for (int i = 0; i < optionsData.length; i++) {
            try {
              final optionData = optionsData[i];
              print('📘 Processing option $i: $optionData (type: ${optionData.runtimeType})');

              if (optionData is Map<String, dynamic>) {
                print('📘 Option $i keys: ${optionData.keys.toList()}');
                print('📘 Option $i text field: ${optionData['option_text']} or ${optionData['text']}');

                final option = QuestionOption.fromJson(optionData);
                optionsList.add(option);
                print('✅ Option $i parsed successfully: ${option.optionText}');
              } else {
                print('⚠️ Option $i is not a Map, it is: ${optionData.runtimeType}');
              }
            } catch (e, stackTrace) {
              print('❌ Error parsing option $i: $e');
              print('📋 Stack: $stackTrace');
              print('📋 Option data: ${optionsData[i]}');
            }
          }
        } else {
          print('⚠️ Options is not a List, it is: ${optionsData.runtimeType}');
        }
      } else {
        print('⚠️ NO OPTIONS FIELD IN JSON!');
      }

      // Parse da lógica condicional
      Map<String, dynamic>? conditionalLogicData;
      if (json['conditional_logic'] != null) {
        try {
          final dynamic rawValue = json['conditional_logic'];
          
          // Debug: verificar o tipo que está chegando
          print('🔍 Tipo recebido: ${rawValue.runtimeType}');
          print('🔍 Valor: $rawValue');
          
          if (rawValue is String && rawValue.isNotEmpty) {
            // Decodificar string JSON
            final decoded = jsonDecode(rawValue);
            conditionalLogicData = Map<String, dynamic>.from(decoded);
          } else if (rawValue is Map) {
            // Já é Map, converter para Map<String, dynamic>
            conditionalLogicData = Map<String, dynamic>.from(rawValue);
          }

          if (conditionalLogicData != null) {
            print('🔧 Lógica condicional processada: $conditionalLogicData');
          }
        } catch (e) {
          print('⚠️ Erro ao processar lógica condicional: $e');
          conditionalLogicData = null;
        }
      }

      final question = Question(
        id: _parseInt(json['id']),
        questionnaireId: _parseInt(json['questionnaire_id']),
        questionText: json['question_text']?.toString() ?? '',
        questionType: json['question_type']?.toString() ?? 'text',
        isRequired: _parseBool(json['is_required']),
        orderIndex: _parseInt(json['order_index']),
        conditionalLogic: conditionalLogicData,
        options: optionsList,
      );

      print(
        '✅ Question parsed successfully: ${question.questionText} (type: ${question.questionType}, options: ${question.options.length}, hasLogic: ${question.hasConditionalLogic})',
      );

      // Debug da lógica condicional
      if (question.hasConditionalLogic) {
        print('🔧 Lógica condicional: ${question.conditionalLogicSummary}');
      }

      return question;
    } catch (e, stackTrace) {
      print('❌ Error in Question.fromJson: $e');
      print('📋 Stack trace: $stackTrace');
      print('📋 JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionnaire_id': questionnaireId,
      'question_text': questionText,
      'question_type': questionType,
      'is_required': isRequired,
      'order_index': orderIndex,
      'conditional_logic': conditionalLogic,
      'options': options.map((option) => option.toJson()).toList(),
    };
  }

  /// Cria uma cópia da pergunta com novos valores
  Question copyWith({
    int? id,
    int? questionnaireId,
    String? questionText,
    String? questionType,
    bool? isRequired,
    int? orderIndex,
    Map<String, dynamic>? conditionalLogic,
    List<QuestionOption>? options,
  }) {
    return Question(
      id: id ?? this.id,
      questionnaireId: questionnaireId ?? this.questionnaireId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      isRequired: isRequired ?? this.isRequired,
      orderIndex: orderIndex ?? this.orderIndex,
      conditionalLogic: conditionalLogic ?? this.conditionalLogic,
      options: options ?? this.options,
    );
  }

  @override
  String toString() {
    return 'Question{id: $id, text: $questionText, type: $questionType, optionsCount: ${options.length}, hasLogic: $hasConditionalLogic}';
  }
}
