import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/ai_models.dart';
import '../services/ai_api_service.dart';
import '../services/ai_audit_service.dart';

/// Provider central para funcionalidades de IA no SXDATA.
/// Gerencia estado de transcrição, inconsistências, sugestões,
/// padronização, questionário adaptativo e follow-ups.
///
/// Toda lógica de IA é processada no backend.
/// Este provider gerencia apenas o estado no app.
class AiProvider extends ChangeNotifier {
  // ============================================================
  // ESTADO GERAL
  // ============================================================
  bool _isAiAvailable = false;
  bool get isAiAvailable => _isAiAvailable || _isDemoMode;

  bool _isCheckingAvailability = false;
  bool get isCheckingAvailability => _isCheckingAvailability;

  // Modo de demonstração - permite testar UI sem backend
  bool _isDemoMode = false;
  bool get isDemoMode => _isDemoMode;

  // Contexto do formulário atual
  int? _currentQuestionnaireId;
  int? _currentFormId;

  // ============================================================
  // TRANSCRIÇÃO DE VOZ
  // ============================================================
  TranscriptionResult _transcriptionResult = const TranscriptionResult();
  TranscriptionResult get transcriptionResult => _transcriptionResult;

  TranscriptionStatus get transcriptionStatus => _transcriptionResult.status;

  // ============================================================
  // INCONSISTÊNCIAS
  // ============================================================
  InconsistencyCheckResult _inconsistencyResult =
      InconsistencyCheckResult.empty;
  InconsistencyCheckResult get inconsistencyResult => _inconsistencyResult;

  bool _isCheckingInconsistencies = false;
  bool get isCheckingInconsistencies => _isCheckingInconsistencies;

  // ============================================================
  // PADRONIZAÇÃO
  // ============================================================
  StandardizationResult _standardizationResult = StandardizationResult.empty;
  StandardizationResult get standardizationResult => _standardizationResult;

  bool _isStandardizing = false;
  bool get isStandardizing => _isStandardizing;

  // ============================================================
  // SUGESTÕES APROVADAS PELO PAINEL
  // ============================================================
  final Map<int, ApprovedSuggestion> _approvedSuggestions = {};
  /// Retorna sugestão aprovada para uma pergunta, se houver e não foi dispensada.
  ApprovedSuggestion? getApprovedSuggestion(int questionId) =>
      _approvedSuggestions[questionId];
  bool get hasApprovedSuggestions => _approvedSuggestions.isNotEmpty;

  // ============================================================
  // PREENCHIMENTO INTELIGENTE
  // ============================================================
  SmartFieldsResult _smartFieldsResult = SmartFieldsResult.empty;
  SmartFieldsResult get smartFieldsResult => _smartFieldsResult;

  bool _isLoadingSmartFields = false;
  bool get isLoadingSmartFields => _isLoadingSmartFields;

  // ============================================================
  // REFORMULAÇÃO
  // ============================================================
  final Map<int, ReformulatedQuestion> _reformulatedQuestions = {};
  Map<int, ReformulatedQuestion> get reformulatedQuestions =>
      _reformulatedQuestions;

  bool _useReformulatedQuestions = false;
  bool get useReformulatedQuestions => _useReformulatedQuestions;

  // ============================================================
  // QUESTIONÁRIO ADAPTATIVO
  // ============================================================
  AdaptiveNextQuestion? _adaptiveNext;
  AdaptiveNextQuestion? get adaptiveNext => _adaptiveNext;

  bool _isLoadingAdaptive = false;
  bool get isLoadingAdaptive => _isLoadingAdaptive;

  bool _useAdaptiveMode = false;
  bool get useAdaptiveMode => _useAdaptiveMode;

  // ============================================================
  // FOLLOW-UP
  // ============================================================
  FollowUpResult _followUpResult = FollowUpResult.empty;
  FollowUpResult get followUpResult => _followUpResult;

  bool _isLoadingFollowUp = false;
  bool get isLoadingFollowUp => _isLoadingFollowUp;

  // ============================================================
  // RELATÓRIOS
  // ============================================================
  AiReportResult _reportResult = AiReportResult.empty;
  AiReportResult get reportResult => _reportResult;

  bool _isGeneratingReport = false;
  bool get isGeneratingReport => _isGeneratingReport;

  // ============================================================
  // DICAS DE FOLLOW-UP PRÉ-CONFIGURADAS NO PAINEL
  // ============================================================
  final Map<int, List<String>> _followUpTips = {};
  bool _isLoadingFollowUpTips = false;

  /// Retorna as dicas de follow-up para uma pergunta, ou null se não houver.
  List<String>? getFollowUpTips(int questionId) => _followUpTips[questionId];

  /// Verifica se as dicas estão sendo carregadas.
  bool get isLoadingFollowUpTips => _isLoadingFollowUpTips;

  /// Verifica se há dicas para alguma pergunta.
  bool get hasFollowUpTips => _followUpTips.isNotEmpty;

  // ============================================================
  // ERRO GERAL
  // ============================================================
  String? _lastError;
  String? get lastError => _lastError;

  // Timers para debounce
  Timer? _inconsistencyDebounce;
  Timer? _followUpDebounce;

  // ============================================================
  // INICIALIZAÇÃO
  // ============================================================

  /// Inicializa o contexto do formulário atual
  void initForForm({
    required int questionnaireId,
    int? formId,
  }) {
    _currentQuestionnaireId = questionnaireId;
    _currentFormId = formId;
    _clearAllResults();
    checkAiAvailability();
  }

  /// Verifica se os serviços de IA estão disponíveis
  Future<void> checkAiAvailability() async {
    _isCheckingAvailability = true;
    notifyListeners();

    try {
      _isAiAvailable = await AiApiService.isAiAvailable();
    } catch (_) {
      _isAiAvailable = false;
    }

    _isCheckingAvailability = false;
    notifyListeners();
  }

  /// Limpa todos os resultados de IA
  void _clearAllResults() {
    _transcriptionResult = const TranscriptionResult();
    _inconsistencyResult = InconsistencyCheckResult.empty;
    _standardizationResult = StandardizationResult.empty;
    _smartFieldsResult = SmartFieldsResult.empty;
    _approvedSuggestions.clear();
    _reformulatedQuestions.clear();
    _adaptiveNext = null;
    _followUpResult = FollowUpResult.empty;
    _reportResult = AiReportResult.empty;
    _followUpTips.clear();
    _lastError = null;
    _inconsistencyDebounce?.cancel();
    _followUpDebounce?.cancel();
  }

  /// Limpa estado ao sair do formulário
  @override
  void dispose() {
    _inconsistencyDebounce?.cancel();
    _followUpDebounce?.cancel();
    super.dispose();
  }

  // ============================================================
  // TRANSCRIÇÃO DE VOZ
  // ============================================================

  /// Inicia o estado de gravação
  void setRecordingState() {
    _transcriptionResult = const TranscriptionResult(
      status: TranscriptionStatus.recording,
    );
    notifyListeners();
  }

  /// Envia áudio para transcrição com dados contextuais
  Future<TranscriptionResult> transcribeAudio(
    File audioFile, {
    int? questionId,
    String? questionText,
    int? applicatorId,
    String? applicatorName,
    int? recordingDurationSecs,
  }) async {
    _transcriptionResult = const TranscriptionResult(
      status: TranscriptionStatus.uploading,
    );
    notifyListeners();

    _transcriptionResult = const TranscriptionResult(
      status: TranscriptionStatus.processing,
    );
    notifyListeners();

    final result = await AiApiService.transcribeAudio(
      audioFile,
      questionId: questionId,
      questionnaireId: _currentQuestionnaireId,
      questionText: questionText,
      applicatorId: applicatorId,
      applicatorName: applicatorName,
      recordingDurationSecs: recordingDurationSecs,
    );
    _transcriptionResult = result;
    notifyListeners();

    // Auditoria
    if (result.hasText) {
      AiAuditService.logEvent(
        eventType: AiAuditService.eventTranscriptionUsed,
        questionnaireId: _currentQuestionnaireId,
        formId: _currentFormId,
        metadata: {
          'confidence': result.confidence,
          'duration_ms': result.durationMs,
        },
      );
    } else if (result.hasError) {
      AiAuditService.logEvent(
        eventType: AiAuditService.eventTranscriptionFailed,
        questionnaireId: _currentQuestionnaireId,
        metadata: {'error': result.errorMessage},
      );
    }

    return result;
  }

  /// Reseta o estado de transcrição
  void resetTranscription() {
    _transcriptionResult = const TranscriptionResult();
    notifyListeners();
  }

  // ============================================================
  // DETECÇÃO DE INCONSISTÊNCIAS
  // ============================================================

  /// Verifica inconsistências com debounce (evita muitas chamadas)
  void checkInconsistenciesDebounced({
    required Map<String, dynamic> responses,
    List<Map<String, dynamic>>? questions,
    Duration debounce = const Duration(seconds: 2),
  }) {
    if (!_isAiAvailable || _currentQuestionnaireId == null) return;

    _inconsistencyDebounce?.cancel();
    _inconsistencyDebounce = Timer(debounce, () {
      checkInconsistencies(responses: responses, questions: questions);
    });
  }

  /// Verifica inconsistências nas respostas
  Future<InconsistencyCheckResult> checkInconsistencies({
    required Map<String, dynamic> responses,
    List<Map<String, dynamic>>? questions,
  }) async {
    if (_currentQuestionnaireId == null) return InconsistencyCheckResult.empty;

    _isCheckingInconsistencies = true;
    notifyListeners();

    try {
      _inconsistencyResult = await AiApiService.checkInconsistencies(
        questionnaireId: _currentQuestionnaireId!,
        responses: responses,
        questions: questions,
      );

      // Auditoria para cada alerta mostrado
      for (final alert in _inconsistencyResult.alerts) {
        AiAuditService.logEvent(
          eventType: AiAuditService.eventInconsistencyShown,
          questionId: alert.questionId,
          questionnaireId: _currentQuestionnaireId,
          formId: _currentFormId,
          metadata: {
            'severity': alert.severity.name,
            'rule_type': alert.ruleType,
          },
        );
      }
    } catch (e) {
      _lastError = e.toString();
      _inconsistencyResult = InconsistencyCheckResult.empty;
    }

    _isCheckingInconsistencies = false;
    notifyListeners();
    return _inconsistencyResult;
  }

  /// Registra ação do usuário sobre uma inconsistência
  void resolveInconsistency(int questionId, InconsistencyAction action) {
    final alertIndex = _inconsistencyResult.alerts
        .indexWhere((a) => a.questionId == questionId);
    if (alertIndex != -1) {
      _inconsistencyResult.alerts[alertIndex].userAction = action;
      notifyListeners();

      // Auditoria
      String eventType;
      switch (action) {
        case InconsistencyAction.corrected:
          eventType = AiAuditService.eventInconsistencyCorrected;
          break;
        case InconsistencyAction.kept:
          eventType = AiAuditService.eventInconsistencyIgnored;
          break;
        case InconsistencyAction.reviewLater:
          eventType = AiAuditService.eventInconsistencyDeferred;
          break;
        default:
          return;
      }

      AiAuditService.logEvent(
        eventType: eventType,
        questionId: questionId,
        questionnaireId: _currentQuestionnaireId,
        formId: _currentFormId,
      );
    }
  }

  /// Retorna alertas para uma pergunta específica
  List<InconsistencyAlert> getAlertsForQuestion(int questionId) {
    return _inconsistencyResult.alerts
        .where((a) => a.questionId == questionId && a.isPending)
        .toList();
  }

  // ============================================================
  // PADRONIZAÇÃO
  // ============================================================

  /// Solicita padronização das respostas
  Future<StandardizationResult> standardizeResponses({
    required Map<String, dynamic> responses,
  }) async {
    if (!_isAiAvailable || _currentQuestionnaireId == null) {
      return StandardizationResult.empty;
    }

    _isStandardizing = true;
    notifyListeners();

    try {
      _standardizationResult = await AiApiService.standardizeData(
        questionnaireId: _currentQuestionnaireId!,
        responses: responses,
      );
    } catch (e) {
      _lastError = e.toString();
      _standardizationResult = StandardizationResult.empty;
    }

    _isStandardizing = false;
    notifyListeners();
    return _standardizationResult;
  }

  /// Aceita uma sugestão de padronização
  void acceptStandardization(int questionId) {
    final idx = _standardizationResult.suggestions
        .indexWhere((s) => s.questionId == questionId);
    if (idx != -1) {
      _standardizationResult.suggestions[idx].accepted = true;
      notifyListeners();

      AiAuditService.logEvent(
        eventType: AiAuditService.eventStandardizationAccepted,
        questionId: questionId,
        questionnaireId: _currentQuestionnaireId,
        formId: _currentFormId,
      );
    }
  }

  /// Rejeita uma sugestão de padronização
  void rejectStandardization(int questionId) {
    final idx = _standardizationResult.suggestions
        .indexWhere((s) => s.questionId == questionId);
    if (idx != -1) {
      _standardizationResult.suggestions.removeAt(idx);
      notifyListeners();

      AiAuditService.logEvent(
        eventType: AiAuditService.eventStandardizationRejected,
        questionId: questionId,
        questionnaireId: _currentQuestionnaireId,
        formId: _currentFormId,
      );
    }
  }

  /// Retorna sugestão de padronização para uma pergunta
  DataStandardization? getStandardizationForQuestion(int questionId) {
    try {
      return _standardizationResult.suggestions
          .firstWhere((s) => s.questionId == questionId && !s.accepted);
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // SUGESTÕES APROVADAS PELO PAINEL — MÉTODOS
  // ============================================================

  /// Busca sugestões aprovadas pelo painel para o questionário atual.
  /// Chamado uma vez ao abrir o formulário, em paralelo com o restante.
  /// Falhas são silenciosas.
  Future<void> loadApprovedSuggestions() async {
    if (_currentQuestionnaireId == null) return;

    try {
      final list = await AiApiService.getApprovedSuggestions(
        questionnaireId: _currentQuestionnaireId!,
      );
      _approvedSuggestions.clear();
      for (final s in list) {
        _approvedSuggestions[s.questionId] = s;
      }
      if (_approvedSuggestions.isNotEmpty) notifyListeners();
    } catch (_) {
      // Silencioso
    }
  }

  /// Aplica sugestão aprovada: remove do mapa (esconde banner) e registra auditoria.
  /// Retorna o valor sugerido para o caller preencher o campo.
  String? applyApprovedSuggestion(int questionId) {
    final suggestion = _approvedSuggestions.remove(questionId);
    if (suggestion == null) return null;

    notifyListeners();

    AiAuditService.logEvent(
      eventType: AiAuditService.eventSmartFieldApplied,
      questionId: questionId,
      questionnaireId: _currentQuestionnaireId,
      formId: _currentFormId,
      metadata: {
        'suggested_value': suggestion.suggestedValue,
        'confidence': suggestion.confidence,
        'source': 'approved_panel',
      },
    );

    return suggestion.suggestedValue;
  }

  /// Descarta sugestão aprovada sem aplicar: remove do mapa e registra auditoria.
  void ignoreApprovedSuggestion(int questionId) {
    final suggestion = _approvedSuggestions.remove(questionId);
    if (suggestion == null) return;

    notifyListeners();

    AiAuditService.logEvent(
      eventType: AiAuditService.eventSmartFieldIgnored,
      questionId: questionId,
      questionnaireId: _currentQuestionnaireId,
      formId: _currentFormId,
      metadata: {
        'suggested_value': suggestion.suggestedValue,
        'confidence': suggestion.confidence,
        'source': 'approved_panel',
      },
    );
  }

  // ============================================================
  // PREENCHIMENTO INTELIGENTE
  // ============================================================

  /// Solicita sugestões inteligentes para um campo
  Future<SmartFieldsResult> loadSmartSuggestions({
    required int questionId,
    required Map<String, dynamic> currentResponses,
    Map<String, dynamic>? metadata,
  }) async {
    if (!_isAiAvailable || _currentQuestionnaireId == null) {
      return SmartFieldsResult.empty;
    }

    _isLoadingSmartFields = true;
    notifyListeners();

    try {
      _smartFieldsResult = await AiApiService.getSmartSuggestions(
        questionnaireId: _currentQuestionnaireId!,
        questionId: questionId,
        currentResponses: currentResponses,
        metadata: metadata,
      );
    } catch (e) {
      _lastError = e.toString();
      _smartFieldsResult = SmartFieldsResult.empty;
    }

    _isLoadingSmartFields = false;
    notifyListeners();
    return _smartFieldsResult;
  }

  /// Aplica sugestão inteligente
  void applySmartSuggestion(int questionId) {
    final suggestion = _smartFieldsResult.getSuggestionForQuestion(questionId);
    if (suggestion != null) {
      suggestion.applied = true;
      notifyListeners();

      AiAuditService.logEvent(
        eventType: AiAuditService.eventSmartFieldApplied,
        questionId: questionId,
        questionnaireId: _currentQuestionnaireId,
        formId: _currentFormId,
        metadata: {'source': suggestion.source},
      );
    }
  }

  /// Ignora sugestão inteligente
  void ignoreSmartSuggestion(int questionId) {
    AiAuditService.logEvent(
      eventType: AiAuditService.eventSmartFieldIgnored,
      questionId: questionId,
      questionnaireId: _currentQuestionnaireId,
      formId: _currentFormId,
    );
  }

  // ============================================================
  // REFORMULAÇÃO DE PERGUNTAS
  // ============================================================

  /// Carrega versões reformuladas das perguntas
  Future<void> loadReformulatedQuestions({
    required List<int> questionIds,
    String style = 'simplified',
  }) async {
    if (!_isAiAvailable || _currentQuestionnaireId == null) return;

    try {
      final questions = await AiApiService.getReformulatedQuestions(
        questionnaireId: _currentQuestionnaireId!,
        questionIds: questionIds,
        style: style,
      );

      for (final q in questions) {
        _reformulatedQuestions[q.questionId] = q;
      }
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
    }
  }

  /// Alterna uso de perguntas reformuladas
  void toggleReformulatedQuestions(bool enabled) {
    _useReformulatedQuestions = enabled;
    notifyListeners();

    if (enabled) {
      AiAuditService.logEvent(
        eventType: AiAuditService.eventReformulationUsed,
        questionnaireId: _currentQuestionnaireId,
      );
    }
  }

  /// Retorna texto da pergunta (reformulada ou original)
  String getQuestionText(int questionId, String originalText) {
    if (_useReformulatedQuestions &&
        _reformulatedQuestions.containsKey(questionId)) {
      return _reformulatedQuestions[questionId]!.reformulatedText;
    }
    return originalText;
  }

  // ============================================================
  // QUESTIONÁRIO ADAPTATIVO
  // ============================================================

  /// Ativa/desativa modo adaptativo
  void setAdaptiveMode(bool enabled) {
    _useAdaptiveMode = enabled;
    notifyListeners();
  }

  /// Solicita próxima pergunta adaptativa
  Future<AdaptiveNextQuestion?> getNextQuestion({
    required int currentQuestionId,
    required Map<String, dynamic> responses,
  }) async {
    if (!_useAdaptiveMode ||
        !_isAiAvailable ||
        _currentQuestionnaireId == null) {
      return null; // Usar fluxo padrão
    }

    _isLoadingAdaptive = true;
    notifyListeners();

    try {
      _adaptiveNext = await AiApiService.getNextAdaptiveQuestion(
        questionnaireId: _currentQuestionnaireId!,
        currentQuestionId: currentQuestionId,
        responses: responses,
      );

      if (_adaptiveNext != null) {
        AiAuditService.logEvent(
          eventType: AiAuditService.eventAdaptiveRouteUsed,
          questionId: currentQuestionId,
          questionnaireId: _currentQuestionnaireId,
          formId: _currentFormId,
          metadata: {
            'next_question_id': _adaptiveNext!.nextQuestionId,
            'reason': _adaptiveNext!.reason,
          },
        );
      }
    } catch (e) {
      _lastError = e.toString();
      _adaptiveNext = null;

      AiAuditService.logEvent(
        eventType: AiAuditService.eventAdaptiveFallback,
        questionnaireId: _currentQuestionnaireId,
        metadata: {'error': e.toString()},
      );
    }

    _isLoadingAdaptive = false;
    notifyListeners();
    return _adaptiveNext;
  }

  // ============================================================
  // DICAS DE FOLLOW-UP PRÉ-CONFIGURADAS — MÉTODOS
  // ============================================================

  /// Busca todas as dicas de follow-up do painel para o questionário atual.
  /// Chamado uma vez ao abrir o formulário. Falha é silenciosa.
  Future<void> loadFollowUpTips() async {
    if (_currentQuestionnaireId == null) return;
    if (_followUpTips.isNotEmpty || _isLoadingFollowUpTips) return;

    _isLoadingFollowUpTips = true;

    try {
      final tips = await AiApiService.getFollowUpTips(
        questionnaireId: _currentQuestionnaireId!,
      );
      _followUpTips.clear();
      _followUpTips.addAll(tips);
      if (_followUpTips.isNotEmpty) notifyListeners();
    } catch (_) {
      // Silencioso
    }

    _isLoadingFollowUpTips = false;
  }

  // ============================================================
  // FOLLOW-UP
  // ============================================================

  /// Solicita sugestões de follow-up com debounce (aguarda 3s após última digitação)
  void loadFollowUpDebounced({
    required int questionId,
    required String responseValue,
    Map<String, dynamic>? allResponses,
    Duration debounce = const Duration(seconds: 3),
  }) {
    if (!_isAiAvailable || _currentQuestionnaireId == null) return;

    // Ignora respostas muito curtas
    if (responseValue.trim().length < 3) return;

    _followUpDebounce?.cancel();
    _followUpDebounce = Timer(debounce, () {
      loadFollowUpSuggestions(
        questionId: questionId,
        responseValue: responseValue,
        allResponses: allResponses,
      );
    });
  }

  /// Solicita sugestões de follow-up para uma resposta
  Future<FollowUpResult> loadFollowUpSuggestions({
    required int questionId,
    required String responseValue,
    Map<String, dynamic>? allResponses,
  }) async {
    if (!_isAiAvailable || _currentQuestionnaireId == null) {
      return FollowUpResult.empty;
    }

    _isLoadingFollowUp = true;
    notifyListeners();

    try {
      _followUpResult = await AiApiService.getFollowUpSuggestions(
        questionnaireId: _currentQuestionnaireId!,
        questionId: questionId,
        responseValue: responseValue,
        allResponses: allResponses,
      );
    } catch (e) {
      _lastError = e.toString();
      _followUpResult = FollowUpResult.empty;
    }

    _isLoadingFollowUp = false;
    notifyListeners();
    return _followUpResult;
  }

  /// Aplica uma sugestão de follow-up
  void applyFollowUp(int index) {
    if (index < _followUpResult.suggestions.length) {
      _followUpResult.suggestions[index].applied = true;
      notifyListeners();

      AiAuditService.logEvent(
        eventType: AiAuditService.eventFollowUpApplied,
        questionnaireId: _currentQuestionnaireId,
        formId: _currentFormId,
        metadata: {
          'question_text': _followUpResult.suggestions[index].questionText,
        },
      );
    }
  }

  /// Ignora uma sugestão de follow-up
  void ignoreFollowUp(int index) {
    if (index < _followUpResult.suggestions.length) {
      AiAuditService.logEvent(
        eventType: AiAuditService.eventFollowUpIgnored,
        questionnaireId: _currentQuestionnaireId,
        formId: _currentFormId,
      );
    }
  }

  /// Limpa follow-ups atuais
  void clearFollowUps() {
    _followUpResult = FollowUpResult.empty;
    notifyListeners();
  }

  // ============================================================
  // RELATÓRIOS
  // ============================================================

  /// Gera relatório com IA
  Future<AiReportResult> generateReport({
    required int questionnaireId,
    String reportType = 'descriptive',
    Map<String, dynamic>? filters,
  }) async {
    _isGeneratingReport = true;
    notifyListeners();

    try {
      _reportResult = await AiApiService.generateReport(
        questionnaireId: questionnaireId,
        reportType: reportType,
        filters: filters,
      );

      AiAuditService.logEvent(
        eventType: AiAuditService.eventReportGenerated,
        questionnaireId: questionnaireId,
        metadata: {'report_type': reportType},
      );
    } catch (e) {
      _lastError = e.toString();
      _reportResult = AiReportResult.empty;
    }

    _isGeneratingReport = false;
    notifyListeners();
    return _reportResult;
  }

  // ============================================================
  // MODO DE DEMONSTRAÇÃO
  // ============================================================

  /// Ativa/desativa o modo de demonstração.
  /// No modo demo, widgets de IA ficam visíveis com dados simulados.
  /// Útil para testar a interface sem backend de IA.
  void toggleDemoMode() {
    _isDemoMode = !_isDemoMode;

    if (_isDemoMode) {
      _loadDemoData();
    } else {
      _clearAllResults();
    }

    notifyListeners();
  }

  /// Carrega dados simulados para demonstração
  void _loadDemoData() {
    // Dados mock de inconsistência (usam questionId genéricos)
    _inconsistencyResult = InconsistencyCheckResult(
      alerts: [
        InconsistencyAlert(
          questionId: _demoFirstQuestionId,
          fieldName: 'Resposta',
          message: 'Esta resposta parece inconsistente com a resposta anterior.',
          suggestion: 'Verifique se os valores estão corretos.',
          severity: InconsistencySeverity.warning,
          ruleType: 'contradiction',
        ),
      ],
      hasWarnings: true,
    );

    // Dados mock de padronização
    _standardizationResult = StandardizationResult(
      suggestions: [
        DataStandardization(
          questionId: _demoFirstQuestionId,
          originalValue: 'joao da silva',
          suggestedValue: 'João da Silva',
          standardizationType: 'capitalization',
          confidence: 0.95,
        ),
      ],
      totalFields: 1,
      fieldsWithSuggestions: 1,
    );

    // Dados mock de sugestão inteligente
    _smartFieldsResult = SmartFieldsResult(
      suggestions: [
        SmartFieldSuggestion(
          questionId: _demoFirstQuestionId,
          suggestedValue: 'Resposta sugerida pela IA com base no contexto.',
          reason: 'Baseado em respostas similares anteriores',
          source: 'history',
          confidence: 0.82,
        ),
      ],
    );

    // Dados mock de follow-up
    _followUpResult = FollowUpResult(
      suggestions: [
        FollowUpSuggestion(
          questionText: 'Poderia detalhar melhor sua resposta anterior?',
          reason: 'A resposta pode se beneficiar de mais contexto.',
          questionType: 'text',
        ),
      ],
    );
  }

  /// Retorna o ID da primeira questão do formulário atual (para dados demo)
  int get _demoFirstQuestionId {
    // Tenta usar um ID de questão real se o contexto existir
    return 0; // ID genérico - os widgets usam getAlertsForQuestion que filtra por ID
  }

  /// Injetar dados demo para uma pergunta específica visível
  void loadDemoDataForQuestion(int questionId) {
    if (!_isDemoMode) return;

    // Inconsistência para esta pergunta
    final hasAlert = _inconsistencyResult.alerts.any((a) => a.questionId == questionId);
    if (!hasAlert) {
      _inconsistencyResult = InconsistencyCheckResult(
        alerts: [
          ..._inconsistencyResult.alerts,
          InconsistencyAlert(
            questionId: questionId,
            fieldName: 'Resposta',
            message: 'Possível inconsistência detectada pela IA.',
            suggestion: 'Revise esta resposta antes de continuar.',
            severity: InconsistencySeverity.warning,
            ruleType: 'suspicious',
          ),
        ],
        hasWarnings: true,
      );
    }

    // Padronização para esta pergunta
    final hasStd = _standardizationResult.suggestions.any((s) => s.questionId == questionId);
    if (!hasStd) {
      _standardizationResult = StandardizationResult(
        suggestions: [
          ..._standardizationResult.suggestions,
          DataStandardization(
            questionId: questionId,
            originalValue: 'texto digitado',
            suggestedValue: 'Texto Padronizado',
            standardizationType: 'capitalization',
            confidence: 0.93,
          ),
        ],
      );
    }

    // Sugestão inteligente para esta pergunta
    final hasSmart = _smartFieldsResult.getSuggestionForQuestion(questionId) != null;
    if (!hasSmart) {
      _smartFieldsResult = SmartFieldsResult(
        suggestions: [
          ..._smartFieldsResult.suggestions,
          SmartFieldSuggestion(
            questionId: questionId,
            suggestedValue: 'Sugestão automática baseada no contexto',
            reason: 'Padrão identificado em respostas anteriores',
            source: 'pattern',
            confidence: 0.85,
          ),
        ],
      );
    }

    notifyListeners();
  }

  // ============================================================
  // LIMPEZA
  // ============================================================

  /// Limpa todo o estado ao sair do formulário
  void clearFormContext() {
    _inconsistencyDebounce?.cancel();
    _currentQuestionnaireId = null;
    _currentFormId = null;
    _isDemoMode = false;
    _clearAllResults();
    notifyListeners();
  }
}
