import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_models.dart';
import 'ai_api_service.dart';

/// Serviço de auditoria de eventos de IA.
/// Armazena eventos localmente e sincroniza com o backend quando possível.
class AiAuditService {
  static const String _eventsKey = 'ai_audit_events';
  static const int _maxLocalEvents = 500;

  /// Registra um evento de auditoria
  static Future<void> logEvent({
    required String eventType,
    int? questionId,
    int? questionnaireId,
    int? formId,
    Map<String, dynamic>? metadata,
  }) async {
    final event = AiAuditEvent(
      eventType: eventType,
      questionId: questionId,
      questionnaireId: questionnaireId,
      formId: formId,
      metadata: metadata,
    );

    // Salvar localmente
    await _saveEventLocally(event);

    // Tentar enviar ao backend (fire-and-forget)
    AiApiService.logAuditEvent(event).catchError((_) {
      // Falhou - evento já está salvo localmente
    });
  }

  /// Salva evento no storage local
  static Future<void> _saveEventLocally(AiAuditEvent event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey);
      List<Map<String, dynamic>> events = [];

      if (eventsJson != null) {
        events = (jsonDecode(eventsJson) as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList();
      }

      events.add(event.toJson());

      // Manter apenas os últimos N eventos
      if (events.length > _maxLocalEvents) {
        events = events.sublist(events.length - _maxLocalEvents);
      }

      await prefs.setString(_eventsKey, jsonEncode(events));
    } catch (e) {
      print('⚠️ Erro ao salvar evento de auditoria localmente: $e');
    }
  }

  /// Sincroniza eventos pendentes com o backend
  static Future<int> syncPendingEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey);

      if (eventsJson == null) return 0;

      final eventsList = (jsonDecode(eventsJson) as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();

      if (eventsList.isEmpty) return 0;

      final events = eventsList.map((e) => AiAuditEvent(
            eventType: e['event_type'] ?? '',
            questionId: e['question_id'],
            questionnaireId: e['questionnaire_id'],
            formId: e['form_id'],
            metadata: e['metadata'] as Map<String, dynamic>?,
            timestamp: DateTime.tryParse(e['timestamp'] ?? ''),
          )).toList();

      await AiApiService.logAuditEventsBatch(events);

      // Limpar eventos sincronizados
      await prefs.remove(_eventsKey);

      return events.length;
    } catch (e) {
      print('⚠️ Erro ao sincronizar eventos de auditoria: $e');
      return 0;
    }
  }

  /// Retorna contagem de eventos pendentes
  static Future<int> getPendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final eventsJson = prefs.getString(_eventsKey);
      if (eventsJson == null) return 0;
      return (jsonDecode(eventsJson) as List<dynamic>).length;
    } catch (_) {
      return 0;
    }
  }

  // Tipos de eventos padrão
  static const String eventTranscriptionUsed = 'transcription_used';
  static const String eventTranscriptionFailed = 'transcription_failed';
  static const String eventSuggestionAccepted = 'suggestion_accepted';
  static const String eventSuggestionRejected = 'suggestion_rejected';
  static const String eventSuggestionEdited = 'suggestion_edited';
  static const String eventInconsistencyShown = 'inconsistency_shown';
  static const String eventInconsistencyCorrected = 'inconsistency_corrected';
  static const String eventInconsistencyIgnored = 'inconsistency_ignored';
  static const String eventInconsistencyDeferred = 'inconsistency_deferred';
  static const String eventStandardizationAccepted = 'standardization_accepted';
  static const String eventStandardizationRejected = 'standardization_rejected';
  static const String eventSmartFieldApplied = 'smart_field_applied';
  static const String eventSmartFieldIgnored = 'smart_field_ignored';
  static const String eventFollowUpApplied = 'follow_up_applied';
  static const String eventFollowUpIgnored = 'follow_up_ignored';
  static const String eventAdaptiveRouteUsed = 'adaptive_route_used';
  static const String eventAdaptiveFallback = 'adaptive_fallback';
  static const String eventReformulationUsed = 'reformulation_used';
  static const String eventReportGenerated = 'report_generated';
  static const String eventAiUnavailable = 'ai_unavailable';
}
