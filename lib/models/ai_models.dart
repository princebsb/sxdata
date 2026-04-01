/// Modelos de dados para funcionalidades de IA do SXDATA
/// Toda lógica de IA é processada no backend - o app apenas
/// envia contexto e recebe resultados.
library;

// ============================================================
// TRANSCRIÇÃO DE VOZ
// ============================================================

enum TranscriptionStatus {
  idle,
  recording,
  uploading,
  processing,
  completed,
  error,
}

class TranscriptionResult {
  final String? text;
  final double? confidence;
  final String? language;
  final int? durationMs;
  final String? errorMessage;
  final TranscriptionStatus status;

  const TranscriptionResult({
    this.text,
    this.confidence,
    this.language,
    this.durationMs,
    this.errorMessage,
    this.status = TranscriptionStatus.idle,
  });

  bool get hasText => text != null && text!.isNotEmpty;
  bool get hasError => errorMessage != null && errorMessage!.isNotEmpty;
  bool get isHighConfidence => confidence != null && confidence! >= 0.85;

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text']?.toString(),
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : null,
      language: json['language']?.toString(),
      durationMs: json['duration_ms'] is int ? json['duration_ms'] : null,
      errorMessage: json['error']?.toString(),
      status: json['error'] != null
          ? TranscriptionStatus.error
          : TranscriptionStatus.completed,
    );
  }

  Map<String, dynamic> toJson() => {
        'text': text,
        'confidence': confidence,
        'language': language,
        'duration_ms': durationMs,
        'error': errorMessage,
        'status': status.name,
      };

  TranscriptionResult copyWith({
    String? text,
    double? confidence,
    String? language,
    int? durationMs,
    String? errorMessage,
    TranscriptionStatus? status,
  }) {
    return TranscriptionResult(
      text: text ?? this.text,
      confidence: confidence ?? this.confidence,
      language: language ?? this.language,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }
}

// ============================================================
// DETECÇÃO DE INCONSISTÊNCIAS
// ============================================================

enum InconsistencySeverity {
  info,
  warning,
  error,
}

enum InconsistencyAction {
  pending,
  corrected,
  kept,
  reviewLater,
}

class InconsistencyAlert {
  final int questionId;
  final String fieldName;
  final String message;
  final String? suggestion;
  final InconsistencySeverity severity;
  final String? relatedQuestionId;
  final String? ruleType; // 'contradiction', 'date_mismatch', 'out_of_range', 'suspicious', 'gap'
  InconsistencyAction userAction;

  InconsistencyAlert({
    required this.questionId,
    required this.fieldName,
    required this.message,
    this.suggestion,
    this.severity = InconsistencySeverity.warning,
    this.relatedQuestionId,
    this.ruleType,
    this.userAction = InconsistencyAction.pending,
  });

  bool get isPending => userAction == InconsistencyAction.pending;
  bool get isError => severity == InconsistencySeverity.error;

  factory InconsistencyAlert.fromJson(Map<String, dynamic> json) {
    return InconsistencyAlert(
      questionId: json['question_id'] is int
          ? json['question_id']
          : int.tryParse(json['question_id']?.toString() ?? '') ?? 0,
      fieldName: json['field_name']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      suggestion: json['suggestion']?.toString(),
      severity: _parseSeverity(json['severity']?.toString()),
      relatedQuestionId: json['related_question_id']?.toString(),
      ruleType: json['rule_type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'field_name': fieldName,
        'message': message,
        'suggestion': suggestion,
        'severity': severity.name,
        'related_question_id': relatedQuestionId,
        'rule_type': ruleType,
        'user_action': userAction.name,
      };

  static InconsistencySeverity _parseSeverity(String? value) {
    switch (value?.toLowerCase()) {
      case 'error':
        return InconsistencySeverity.error;
      case 'info':
        return InconsistencySeverity.info;
      default:
        return InconsistencySeverity.warning;
    }
  }
}

class InconsistencyCheckResult {
  final List<InconsistencyAlert> alerts;
  final bool hasErrors;
  final bool hasWarnings;
  final String? summary;

  const InconsistencyCheckResult({
    this.alerts = const [],
    this.hasErrors = false,
    this.hasWarnings = false,
    this.summary,
  });

  factory InconsistencyCheckResult.fromJson(Map<String, dynamic> json) {
    final alertsList = (json['alerts'] as List<dynamic>?)
            ?.map((a) =>
                InconsistencyAlert.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    return InconsistencyCheckResult(
      alerts: alertsList,
      hasErrors: alertsList.any((a) => a.isError),
      hasWarnings: alertsList.any(
          (a) => a.severity == InconsistencySeverity.warning),
      summary: json['summary']?.toString(),
    );
  }

  static const empty = InconsistencyCheckResult();
}

// ============================================================
// CORREÇÃO E PADRONIZAÇÃO DE DADOS
// ============================================================

class DataStandardization {
  final int questionId;
  final String originalValue;
  final String suggestedValue;
  final String standardizationType; // 'capitalization', 'phone_mask', 'address', 'city_state', 'spelling', 'cleanup'
  final double confidence;
  bool accepted;

  DataStandardization({
    required this.questionId,
    required this.originalValue,
    required this.suggestedValue,
    required this.standardizationType,
    this.confidence = 0.0,
    this.accepted = false,
  });

  bool get hasDifference => originalValue != suggestedValue;

  factory DataStandardization.fromJson(Map<String, dynamic> json) {
    return DataStandardization(
      questionId: json['question_id'] is int
          ? json['question_id']
          : int.tryParse(json['question_id']?.toString() ?? '') ?? 0,
      originalValue: json['original_value']?.toString() ?? '',
      suggestedValue: json['suggested_value']?.toString() ?? '',
      standardizationType: json['type']?.toString() ?? 'cleanup',
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'original_value': originalValue,
        'suggested_value': suggestedValue,
        'type': standardizationType,
        'confidence': confidence,
        'accepted': accepted,
      };
}

class StandardizationResult {
  final List<DataStandardization> suggestions;
  final int totalFields;
  final int fieldsWithSuggestions;

  const StandardizationResult({
    this.suggestions = const [],
    this.totalFields = 0,
    this.fieldsWithSuggestions = 0,
  });

  bool get hasSuggestions => suggestions.isNotEmpty;

  factory StandardizationResult.fromJson(Map<String, dynamic> json) {
    return StandardizationResult(
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) =>
                  DataStandardization.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      totalFields: json['total_fields'] is int ? json['total_fields'] : 0,
      fieldsWithSuggestions: json['fields_with_suggestions'] is int
          ? json['fields_with_suggestions']
          : 0,
    );
  }

  static const empty = StandardizationResult();
}

// ============================================================
// PREENCHIMENTO INTELIGENTE
// ============================================================

class SmartFieldSuggestion {
  final int questionId;
  final String suggestedValue;
  final String reason;
  final String source; // 'context', 'history', 'pattern', 'metadata'
  final double confidence;
  bool applied;

  SmartFieldSuggestion({
    required this.questionId,
    required this.suggestedValue,
    required this.reason,
    this.source = 'context',
    this.confidence = 0.0,
    this.applied = false,
  });

  factory SmartFieldSuggestion.fromJson(Map<String, dynamic> json) {
    return SmartFieldSuggestion(
      questionId: json['question_id'] is int
          ? json['question_id']
          : int.tryParse(json['question_id']?.toString() ?? '') ?? 0,
      suggestedValue: json['suggested_value']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      source: json['source']?.toString() ?? 'context',
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'suggested_value': suggestedValue,
        'reason': reason,
        'source': source,
        'confidence': confidence,
        'applied': applied,
      };
}

class SmartFieldsResult {
  final List<SmartFieldSuggestion> suggestions;

  const SmartFieldsResult({this.suggestions = const []});

  bool get hasSuggestions => suggestions.isNotEmpty;

  SmartFieldSuggestion? getSuggestionForQuestion(int questionId) {
    try {
      return suggestions.firstWhere((s) => s.questionId == questionId);
    } catch (_) {
      return null;
    }
  }

  factory SmartFieldsResult.fromJson(Map<String, dynamic> json) {
    return SmartFieldsResult(
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) =>
                  SmartFieldSuggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static const empty = SmartFieldsResult();
}

// ============================================================
// SUGESTÕES APROVADAS PELO PAINEL
// ============================================================

/// Sugestão de preenchimento aprovada manualmente pelo painel administrativo.
/// Vem do endpoint GET /api/ai/approved-suggestions?questionnaire_id={id}
class ApprovedSuggestion {
  final int questionId;
  final String suggestedValue;
  final double? confidence;
  final String? rationale;

  const ApprovedSuggestion({
    required this.questionId,
    required this.suggestedValue,
    this.confidence,
    this.rationale,
  });

  bool get isHighConfidence => confidence != null && confidence! >= 0.85;

  factory ApprovedSuggestion.fromJson(Map<String, dynamic> json) {
    final context = json['context'];
    return ApprovedSuggestion(
      questionId: json['question_id'] is int
          ? json['question_id']
          : int.tryParse(json['question_id']?.toString() ?? '') ?? 0,
      suggestedValue: json['suggested_value']?.toString() ?? '',
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : null,
      rationale: context is Map ? context['rationale']?.toString() : null,
    );
  }
}

// ============================================================
// REFORMULAÇÃO DE PERGUNTAS
// ============================================================

class ReformulatedQuestion {
  final int questionId;
  final String originalText;
  final String reformulatedText;
  final String style; // 'simplified', 'accessible', 'technical', 'neutral'

  const ReformulatedQuestion({
    required this.questionId,
    required this.originalText,
    required this.reformulatedText,
    this.style = 'simplified',
  });

  factory ReformulatedQuestion.fromJson(Map<String, dynamic> json) {
    return ReformulatedQuestion(
      questionId: json['question_id'] is int
          ? json['question_id']
          : int.tryParse(json['question_id']?.toString() ?? '') ?? 0,
      originalText: json['original_text']?.toString() ?? '',
      reformulatedText: json['reformulated_text']?.toString() ?? '',
      style: json['style']?.toString() ?? 'simplified',
    );
  }

  Map<String, dynamic> toJson() => {
        'question_id': questionId,
        'original_text': originalText,
        'reformulated_text': reformulatedText,
        'style': style,
      };
}

// ============================================================
// QUESTIONÁRIO ADAPTATIVO
// ============================================================

class AdaptiveNextQuestion {
  final int? nextQuestionId;
  final String reason;
  final bool isAiGenerated;
  final List<int>? skipQuestionIds;
  final String? fallbackRule;

  const AdaptiveNextQuestion({
    this.nextQuestionId,
    this.reason = '',
    this.isAiGenerated = false,
    this.skipQuestionIds,
    this.fallbackRule,
  });

  factory AdaptiveNextQuestion.fromJson(Map<String, dynamic> json) {
    return AdaptiveNextQuestion(
      nextQuestionId: json['next_question_id'] is int
          ? json['next_question_id']
          : int.tryParse(json['next_question_id']?.toString() ?? ''),
      reason: json['reason']?.toString() ?? '',
      isAiGenerated: json['is_ai_generated'] == true,
      skipQuestionIds: (json['skip_question_ids'] as List<dynamic>?)
          ?.map((e) => e is int ? e : int.tryParse(e.toString()) ?? 0)
          .toList(),
      fallbackRule: json['fallback_rule']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'next_question_id': nextQuestionId,
        'reason': reason,
        'is_ai_generated': isAiGenerated,
        'skip_question_ids': skipQuestionIds,
        'fallback_rule': fallbackRule,
      };
}

// ============================================================
// FOLLOW-UP SUGERIDO
// ============================================================

class FollowUpSuggestion {
  final String questionText;
  final String questionType;
  final String reason;
  final int? afterQuestionId;
  final List<String>? options;
  final bool isRequired;
  bool applied;

  FollowUpSuggestion({
    required this.questionText,
    this.questionType = 'text',
    required this.reason,
    this.afterQuestionId,
    this.options,
    this.isRequired = false,
    this.applied = false,
  });

  factory FollowUpSuggestion.fromJson(Map<String, dynamic> json) {
    return FollowUpSuggestion(
      questionText: json['question_text']?.toString() ?? '',
      questionType: json['question_type']?.toString() ?? 'text',
      reason: json['reason']?.toString() ?? '',
      afterQuestionId: json['after_question_id'] is int
          ? json['after_question_id']
          : int.tryParse(json['after_question_id']?.toString() ?? ''),
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      isRequired: json['is_required'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'question_text': questionText,
        'question_type': questionType,
        'reason': reason,
        'after_question_id': afterQuestionId,
        'options': options,
        'is_required': isRequired,
        'applied': applied,
      };
}

class FollowUpResult {
  final List<FollowUpSuggestion> suggestions;

  const FollowUpResult({this.suggestions = const []});

  bool get hasSuggestions => suggestions.isNotEmpty;

  factory FollowUpResult.fromJson(Map<String, dynamic> json) {
    return FollowUpResult(
      suggestions: (json['suggestions'] as List<dynamic>?)
              ?.map((s) =>
                  FollowUpSuggestion.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static const empty = FollowUpResult();
}

// ============================================================
// EVENTO DE AUDITORIA
// ============================================================

class AiAuditEvent {
  final String eventType; // 'transcription_used', 'suggestion_accepted', 'suggestion_rejected', etc.
  final int? questionId;
  final int? questionnaireId;
  final int? formId;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  AiAuditEvent({
    required this.eventType,
    this.questionId,
    this.questionnaireId,
    this.formId,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'event_type': eventType,
        'question_id': questionId,
        'questionnaire_id': questionnaireId,
        'form_id': formId,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ============================================================
// RELATÓRIOS IA
// ============================================================

class AiReportResult {
  final String title;
  final String summary;
  final List<String> keyFindings;
  final List<Map<String, dynamic>>? charts;
  final String? fullReport;

  const AiReportResult({
    this.title = '',
    this.summary = '',
    this.keyFindings = const [],
    this.charts,
    this.fullReport,
  });

  factory AiReportResult.fromJson(Map<String, dynamic> json) {
    return AiReportResult(
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      keyFindings: (json['key_findings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      charts: (json['charts'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList(),
      fullReport: json['full_report']?.toString(),
    );
  }

  static const empty = AiReportResult();
}
