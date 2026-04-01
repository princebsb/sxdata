import 'package:flutter_test/flutter_test.dart';
import 'package:sxdata/providers/ai_provider.dart';
import 'package:sxdata/models/ai_models.dart';

void main() {
  late AiProvider provider;

  setUp(() {
    provider = AiProvider();
  });

  tearDown(() {
    provider.dispose();
  });

  group('AiProvider - Estado Inicial', () {
    test('inicia com IA indisponível', () {
      expect(provider.isAiAvailable, false);
      expect(provider.isCheckingAvailability, false);
    });

    test('transcription status inicia idle', () {
      expect(provider.transcriptionStatus, TranscriptionStatus.idle);
      expect(provider.transcriptionResult.hasText, false);
    });

    test('inconsistência inicia vazio', () {
      expect(provider.inconsistencyResult.alerts, isEmpty);
      expect(provider.isCheckingInconsistencies, false);
    });

    test('padronização inicia vazio', () {
      expect(provider.standardizationResult.hasSuggestions, false);
      expect(provider.isStandardizing, false);
    });

    test('smart fields inicia vazio', () {
      expect(provider.smartFieldsResult.hasSuggestions, false);
      expect(provider.isLoadingSmartFields, false);
    });

    test('follow-up inicia vazio', () {
      expect(provider.followUpResult.hasSuggestions, false);
      expect(provider.isLoadingFollowUp, false);
    });

    test('modo adaptativo inicia desativado', () {
      expect(provider.useAdaptiveMode, false);
      expect(provider.adaptiveNext, isNull);
    });

    test('reformulação inicia desativada', () {
      expect(provider.useReformulatedQuestions, false);
      expect(provider.reformulatedQuestions, isEmpty);
    });
  });

  group('AiProvider - Inicialização', () {
    test('initForForm configura contexto', () {
      provider.initForForm(questionnaireId: 42, formId: 100);
      // Não temos acesso direto aos campos privados,
      // mas podemos verificar que não houve erro
      expect(provider.lastError, isNull);
    });

    test('clearFormContext limpa estado', () {
      provider.initForForm(questionnaireId: 1);
      provider.clearFormContext();
      expect(provider.inconsistencyResult.alerts, isEmpty);
      expect(provider.standardizationResult.hasSuggestions, false);
    });
  });

  group('AiProvider - Transcrição', () {
    test('setRecordingState muda status', () {
      provider.setRecordingState();
      expect(provider.transcriptionStatus, TranscriptionStatus.recording);
    });

    test('resetTranscription volta para idle', () {
      provider.setRecordingState();
      provider.resetTranscription();
      expect(provider.transcriptionStatus, TranscriptionStatus.idle);
    });
  });

  group('AiProvider - Inconsistências', () {
    test('getAlertsForQuestion retorna lista vazia sem alertas', () {
      final alerts = provider.getAlertsForQuestion(1);
      expect(alerts, isEmpty);
    });

    test('resolveInconsistency não falha sem alertas', () {
      // Deve ser seguro chamar sem alertas
      provider.resolveInconsistency(1, InconsistencyAction.kept);
      expect(provider.inconsistencyResult.alerts, isEmpty);
    });
  });

  group('AiProvider - Padronização', () {
    test('getStandardizationForQuestion retorna null sem dados', () {
      expect(provider.getStandardizationForQuestion(1), isNull);
    });

    test('acceptStandardization sem dados não falha', () {
      provider.acceptStandardization(1);
      expect(provider.standardizationResult.hasSuggestions, false);
    });

    test('rejectStandardization sem dados não falha', () {
      provider.rejectStandardization(1);
      expect(provider.standardizationResult.hasSuggestions, false);
    });
  });

  group('AiProvider - Modo Adaptativo', () {
    test('setAdaptiveMode alterna modo', () {
      provider.setAdaptiveMode(true);
      expect(provider.useAdaptiveMode, true);

      provider.setAdaptiveMode(false);
      expect(provider.useAdaptiveMode, false);
    });
  });

  group('AiProvider - Reformulação', () {
    test('toggleReformulatedQuestions alterna', () {
      provider.toggleReformulatedQuestions(true);
      expect(provider.useReformulatedQuestions, true);
    });

    test('getQuestionText retorna original sem reformulação', () {
      final text = provider.getQuestionText(1, 'Qual seu nome?');
      expect(text, 'Qual seu nome?');
    });
  });

  group('AiProvider - Follow-up', () {
    test('clearFollowUps limpa sugestões', () {
      provider.clearFollowUps();
      expect(provider.followUpResult.hasSuggestions, false);
    });

    test('applyFollowUp com índice inválido não falha', () {
      provider.applyFollowUp(99); // Índice fora do range
      // Não deve lançar exceção
    });
  });

  group('AiProvider - Relatórios', () {
    test('reportResult inicia vazio', () {
      expect(provider.reportResult.title, isEmpty);
      expect(provider.isGeneratingReport, false);
    });
  });
}
