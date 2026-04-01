import 'package:flutter_test/flutter_test.dart';
import 'package:sxdata/models/ai_models.dart';

void main() {
  group('TranscriptionResult', () {
    test('fromJson cria resultado correto', () {
      final json = {
        'text': 'Olá mundo',
        'confidence': 0.95,
        'language': 'pt-BR',
        'duration_ms': 3500,
      };

      final result = TranscriptionResult.fromJson(json);

      expect(result.text, 'Olá mundo');
      expect(result.confidence, 0.95);
      expect(result.language, 'pt-BR');
      expect(result.durationMs, 3500);
      expect(result.hasText, true);
      expect(result.isHighConfidence, true);
      expect(result.status, TranscriptionStatus.completed);
    });

    test('fromJson com erro retorna status error', () {
      final json = {
        'error': 'Áudio muito curto',
      };

      final result = TranscriptionResult.fromJson(json);

      expect(result.hasError, true);
      expect(result.hasText, false);
      expect(result.status, TranscriptionStatus.error);
    });

    test('toJson serializa corretamente', () {
      const result = TranscriptionResult(
        text: 'Teste',
        confidence: 0.8,
        status: TranscriptionStatus.completed,
      );

      final json = result.toJson();

      expect(json['text'], 'Teste');
      expect(json['confidence'], 0.8);
      expect(json['status'], 'completed');
    });

    test('copyWith preserva valores não alterados', () {
      const original = TranscriptionResult(
        text: 'Original',
        confidence: 0.9,
        status: TranscriptionStatus.completed,
      );

      final modified = original.copyWith(text: 'Modificado');

      expect(modified.text, 'Modificado');
      expect(modified.confidence, 0.9); // preservado
    });
  });

  group('InconsistencyAlert', () {
    test('fromJson cria alerta correto', () {
      final json = {
        'question_id': 5,
        'field_name': 'idade',
        'message': 'Idade inconsistente com data de nascimento',
        'suggestion': 'Verifique a data de nascimento',
        'severity': 'warning',
        'rule_type': 'contradiction',
      };

      final alert = InconsistencyAlert.fromJson(json);

      expect(alert.questionId, 5);
      expect(alert.message, contains('inconsistente'));
      expect(alert.severity, InconsistencySeverity.warning);
      expect(alert.isPending, true);
      expect(alert.isError, false);
    });

    test('severidade error é detectada', () {
      final json = {
        'question_id': 1,
        'field_name': 'campo',
        'message': 'Erro grave',
        'severity': 'error',
      };

      final alert = InconsistencyAlert.fromJson(json);
      expect(alert.isError, true);
    });
  });

  group('InconsistencyCheckResult', () {
    test('fromJson com alertas', () {
      final json = {
        'alerts': [
          {
            'question_id': 1,
            'field_name': 'nome',
            'message': 'Nome muito curto',
            'severity': 'warning',
          },
          {
            'question_id': 2,
            'field_name': 'idade',
            'message': 'Idade inválida',
            'severity': 'error',
          },
        ],
        'summary': '2 inconsistências encontradas',
      };

      final result = InconsistencyCheckResult.fromJson(json);

      expect(result.alerts.length, 2);
      expect(result.hasErrors, true);
      expect(result.hasWarnings, true);
      expect(result.summary, contains('2'));
    });

    test('empty é vazio', () {
      expect(InconsistencyCheckResult.empty.alerts, isEmpty);
      expect(InconsistencyCheckResult.empty.hasErrors, false);
    });
  });

  group('DataStandardization', () {
    test('fromJson cria padronização correta', () {
      final json = {
        'question_id': 3,
        'original_value': 'são paulo',
        'suggested_value': 'São Paulo',
        'type': 'capitalization',
        'confidence': 0.99,
      };

      final std = DataStandardization.fromJson(json);

      expect(std.originalValue, 'são paulo');
      expect(std.suggestedValue, 'São Paulo');
      expect(std.hasDifference, true);
      expect(std.standardizationType, 'capitalization');
    });

    test('hasDifference é false quando valores iguais', () {
      final std = DataStandardization(
        questionId: 1,
        originalValue: 'teste',
        suggestedValue: 'teste',
        standardizationType: 'cleanup',
      );

      expect(std.hasDifference, false);
    });
  });

  group('SmartFieldSuggestion', () {
    test('fromJson cria sugestão correta', () {
      final json = {
        'question_id': 10,
        'suggested_value': 'Masculino',
        'reason': 'Baseado no nome informado',
        'source': 'context',
        'confidence': 0.75,
      };

      final suggestion = SmartFieldSuggestion.fromJson(json);

      expect(suggestion.questionId, 10);
      expect(suggestion.suggestedValue, 'Masculino');
      expect(suggestion.source, 'context');
      expect(suggestion.applied, false);
    });
  });

  group('SmartFieldsResult', () {
    test('getSuggestionForQuestion retorna sugestão correta', () {
      final result = SmartFieldsResult(
        suggestions: [
          SmartFieldSuggestion(
            questionId: 1,
            suggestedValue: 'Valor 1',
            reason: 'Motivo 1',
          ),
          SmartFieldSuggestion(
            questionId: 2,
            suggestedValue: 'Valor 2',
            reason: 'Motivo 2',
          ),
        ],
      );

      expect(result.getSuggestionForQuestion(1)?.suggestedValue, 'Valor 1');
      expect(result.getSuggestionForQuestion(3), isNull);
    });
  });

  group('FollowUpSuggestion', () {
    test('fromJson cria sugestão de follow-up', () {
      final json = {
        'question_text': 'Pode descrever melhor?',
        'question_type': 'textarea',
        'reason': 'Resposta genérica detectada',
        'after_question_id': 5,
      };

      final suggestion = FollowUpSuggestion.fromJson(json);

      expect(suggestion.questionText, 'Pode descrever melhor?');
      expect(suggestion.questionType, 'textarea');
      expect(suggestion.reason, contains('genérica'));
      expect(suggestion.applied, false);
    });
  });

  group('AdaptiveNextQuestion', () {
    test('fromJson com dados completos', () {
      final json = {
        'next_question_id': 15,
        'reason': 'Resposta indica necessidade de aprofundamento',
        'is_ai_generated': true,
        'skip_question_ids': [12, 13],
      };

      final adaptive = AdaptiveNextQuestion.fromJson(json);

      expect(adaptive.nextQuestionId, 15);
      expect(adaptive.isAiGenerated, true);
      expect(adaptive.skipQuestionIds, [12, 13]);
    });
  });

  group('AiAuditEvent', () {
    test('toJson serializa evento corretamente', () {
      final event = AiAuditEvent(
        eventType: 'transcription_used',
        questionId: 5,
        questionnaireId: 1,
        metadata: {'confidence': 0.95},
      );

      final json = event.toJson();

      expect(json['event_type'], 'transcription_used');
      expect(json['question_id'], 5);
      expect(json['metadata']['confidence'], 0.95);
      expect(json['timestamp'], isNotNull);
    });
  });

  group('AiReportResult', () {
    test('fromJson com relatório completo', () {
      final json = {
        'title': 'Relatório de Pesquisa',
        'summary': 'Foram coletadas 150 respostas...',
        'key_findings': ['Alta satisfação', 'Baixa adesão'],
        'full_report': 'Relatório completo aqui...',
      };

      final report = AiReportResult.fromJson(json);

      expect(report.title, 'Relatório de Pesquisa');
      expect(report.keyFindings.length, 2);
      expect(report.fullReport, isNotNull);
    });

    test('empty é vazio', () {
      expect(AiReportResult.empty.title, isEmpty);
      expect(AiReportResult.empty.keyFindings, isEmpty);
    });
  });
}
