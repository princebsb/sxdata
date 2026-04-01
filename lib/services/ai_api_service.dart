import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../models/ai_models.dart';

/// Serviço de comunicação com os endpoints de IA do backend.
/// IMPORTANTE: Toda lógica de IA (prompts, OpenAI, custos) fica no backend.
/// O app apenas envia contexto e recebe resultados processados.
class AiApiService {
  static const String _baseUrl = ApiService.baseUrl;
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _transcriptionTimeout = Duration(seconds: 60);
  static const Duration _reportTimeout = Duration(seconds: 90);

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Helper genérico para chamadas POST com tratamento de erro
  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration? timeout,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl$endpoint'),
            headers: await _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(timeout ?? _defaultTimeout);

      // Proteger contra resposta HTML (página de erro PHP)
      if (response.body.trimLeft().startsWith('<')) {
        throw AiApiException(
          'Servidor retornou resposta inválida (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw AiApiException('Sessão expirada. Faça login novamente.',
            statusCode: 401);
      } else if (response.statusCode == 429) {
        throw AiApiException(
            'Muitas requisições. Aguarde um momento e tente novamente.',
            statusCode: 429);
      } else {
        final errorData = _tryDecodeJson(response.body);
        throw AiApiException(
          errorData?['message']?.toString() ??
              'Erro no servidor (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw AiApiException('Sem conexão com a internet. Recurso de IA indisponível offline.');
    } on http.ClientException {
      throw AiApiException('Erro de comunicação com o servidor.');
    } catch (e) {
      if (e is AiApiException) rethrow;
      if (e.toString().contains('TimeoutException')) {
        throw AiApiException('Tempo de espera esgotado. Tente novamente.');
      }
      throw AiApiException('Erro inesperado: $e');
    }
  }

  /// Helper para chamadas GET
  static Future<Map<String, dynamic>> _get(
    String endpoint, {
    Map<String, String>? queryParams,
    Duration? timeout,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http
          .get(uri, headers: await _getHeaders())
          .timeout(timeout ?? _defaultTimeout);

      // Proteger contra resposta HTML (página de erro PHP)
      if (response.body.trimLeft().startsWith('<')) {
        throw AiApiException(
          'Servidor retornou resposta inválida (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw AiApiException('Sessão expirada.', statusCode: 401);
      } else {
        final errorData = _tryDecodeJson(response.body);
        throw AiApiException(
          errorData?['message']?.toString() ??
              'Erro no servidor (${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
    } on SocketException {
      throw AiApiException('Sem conexão com a internet.');
    } catch (e) {
      if (e is AiApiException) rethrow;
      if (e.toString().contains('TimeoutException')) {
        throw AiApiException('Tempo de espera esgotado.');
      }
      throw AiApiException('Erro inesperado: $e');
    }
  }

  static Map<String, dynamic>? _tryDecodeJson(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // TRANSCRIÇÃO DE VOZ
  // ============================================================

  /// Envia áudio para transcrição no backend com dados contextuais.
  static Future<TranscriptionResult> transcribeAudio(
    File audioFile, {
    int? questionId,
    int? questionnaireId,
    String? questionText,
    int? applicatorId,
    String? applicatorName,
    int? recordingDurationSecs,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/ai/transcribe'),
      );

      final headers = await _getHeaders();
      request.headers.addAll(headers);
      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      // Campos contextuais para o painel identificar a transcrição
      if (questionId != null) {
        request.fields['questionId'] = questionId.toString();
      }
      if (questionnaireId != null) {
        request.fields['questionnaireId'] = questionnaireId.toString();
      }
      if (questionText != null) {
        request.fields['questionText'] = questionText;
      }
      if (applicatorId != null) {
        request.fields['applicatorId'] = applicatorId.toString();
      }
      if (applicatorName != null) {
        request.fields['applicatorName'] = applicatorName;
      }
      if (recordingDurationSecs != null) {
        request.fields['recordingDurationSecs'] =
            recordingDurationSecs.toString();
      }

      final response = await request.send().timeout(_transcriptionTimeout);
      final responseBody = await response.stream.bytesToString();

      // Proteger contra resposta HTML do backend (página de erro PHP)
      if (responseBody.trimLeft().startsWith('<')) {
        print('⚠️ Backend retornou HTML em vez de JSON (status ${response.statusCode})');
        return TranscriptionResult(
          status: TranscriptionStatus.error,
          errorMessage: 'Serviço de transcrição com erro no servidor. '
              'Tente novamente ou use a digitação manual.',
        );
      }

      final responseData = jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode == 200 && responseData['success'] == true) {
        return TranscriptionResult.fromJson(
            responseData['data'] as Map<String, dynamic>);
      } else {
        return TranscriptionResult(
          status: TranscriptionStatus.error,
          errorMessage: responseData['message']?.toString() ??
              'Erro na transcrição (${response.statusCode})',
        );
      }
    } on SocketException {
      return const TranscriptionResult(
        status: TranscriptionStatus.error,
        errorMessage: 'Sem conexão. Use a digitação manual.',
      );
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return const TranscriptionResult(
          status: TranscriptionStatus.error,
          errorMessage: 'Tempo esgotado. Tente gravar um áudio mais curto.',
        );
      }
      return TranscriptionResult(
        status: TranscriptionStatus.error,
        errorMessage: 'Erro: $e',
      );
    }
  }

  // ============================================================
  // DETECÇÃO DE INCONSISTÊNCIAS
  // ============================================================

  /// Verifica inconsistências nas respostas do formulário
  static Future<InconsistencyCheckResult> checkInconsistencies({
    required int questionnaireId,
    required Map<String, dynamic> responses,
    List<Map<String, dynamic>>? questions,
  }) async {
    try {
      final result = await _post('/ai/check-inconsistencies', {
        'questionnaire_id': questionnaireId,
        'responses': responses,
        if (questions != null) 'questions': questions,
      });

      if (result['success'] == true && result['data'] != null) {
        return InconsistencyCheckResult.fromJson(
            result['data'] as Map<String, dynamic>);
      }
      return InconsistencyCheckResult.empty;
    } on AiApiException catch (e) {
      print('⚠️ Verificação de inconsistências indisponível: $e');
      return InconsistencyCheckResult.empty;
    }
  }

  // ============================================================
  // CORREÇÃO E PADRONIZAÇÃO
  // ============================================================

  /// Solicita padronização de dados ao backend
  static Future<StandardizationResult> standardizeData({
    required int questionnaireId,
    required Map<String, dynamic> responses,
  }) async {
    try {
      final result = await _post('/ai/standardize', {
        'questionnaire_id': questionnaireId,
        'responses': responses,
      });

      if (result['success'] == true && result['data'] != null) {
        return StandardizationResult.fromJson(
            result['data'] as Map<String, dynamic>);
      }
      return StandardizationResult.empty;
    } on AiApiException catch (e) {
      print('⚠️ Padronização indisponível: $e');
      return StandardizationResult.empty;
    }
  }

  // ============================================================
  // PREENCHIMENTO INTELIGENTE
  // ============================================================

  /// Solicita sugestões de preenchimento inteligente
  static Future<SmartFieldsResult> getSmartSuggestions({
    required int questionnaireId,
    required int questionId,
    required Map<String, dynamic> currentResponses,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final result = await _post('/ai/smart-suggestions', {
        'questionnaire_id': questionnaireId,
        'question_id': questionId,
        'current_responses': currentResponses,
        if (metadata != null) 'metadata': metadata,
      });

      if (result['success'] == true && result['data'] != null) {
        return SmartFieldsResult.fromJson(
            result['data'] as Map<String, dynamic>);
      }
      return SmartFieldsResult.empty;
    } on AiApiException catch (e) {
      print('⚠️ Sugestões inteligentes indisponíveis: $e');
      return SmartFieldsResult.empty;
    }
  }

  // ============================================================
  // SUGESTÕES APROVADAS PELO PAINEL
  // ============================================================

  /// Busca sugestões de preenchimento aprovadas pelo painel para um questionário.
  /// Falhas são silenciosas — retorna lista vazia sem mostrar erro ao usuário.
  static Future<List<ApprovedSuggestion>> getApprovedSuggestions({
    required int questionnaireId,
  }) async {
    try {
      final result = await _get(
        '/ai/approved-suggestions',
        queryParams: {'questionnaire_id': questionnaireId.toString()},
        timeout: const Duration(seconds: 10),
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final list = data['suggestions'] as List<dynamic>? ?? [];
        return list
            .map((s) =>
                ApprovedSuggestion.fromJson(s as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      // Silencioso — sugestões aprovadas são opcionais
      print('ℹ️ Sugestões aprovadas indisponíveis: $e');
      return [];
    }
  }

  // ============================================================
  // REFORMULAÇÃO DE PERGUNTAS
  // ============================================================

  /// Solicita versões reformuladas das perguntas
  static Future<List<ReformulatedQuestion>> getReformulatedQuestions({
    required int questionnaireId,
    required List<int> questionIds,
    String style = 'simplified',
  }) async {
    try {
      final result = await _post('/ai/reformulate-questions', {
        'questionnaire_id': questionnaireId,
        'question_ids': questionIds,
        'style': style,
      });

      if (result['success'] == true && result['data'] != null) {
        return (result['data']['questions'] as List<dynamic>?)
                ?.map((q) =>
                    ReformulatedQuestion.fromJson(q as Map<String, dynamic>))
                .toList() ??
            [];
      }
      return [];
    } on AiApiException catch (e) {
      print('⚠️ Reformulação indisponível: $e');
      return [];
    }
  }

  // ============================================================
  // QUESTIONÁRIO ADAPTATIVO
  // ============================================================

  /// Solicita a próxima pergunta do fluxo adaptativo
  static Future<AdaptiveNextQuestion?> getNextAdaptiveQuestion({
    required int questionnaireId,
    required int currentQuestionId,
    required Map<String, dynamic> responses,
  }) async {
    try {
      final result = await _post('/ai/adaptive-next', {
        'questionnaire_id': questionnaireId,
        'current_question_id': currentQuestionId,
        'responses': responses,
      });

      if (result['success'] == true && result['data'] != null) {
        return AdaptiveNextQuestion.fromJson(
            result['data'] as Map<String, dynamic>);
      }
      return null;
    } on AiApiException catch (e) {
      print('⚠️ Roteamento adaptativo indisponível: $e');
      return null; // Fallback para fluxo padrão
    }
  }

  // ============================================================
  // FOLLOW-UP
  // ============================================================

  /// Solicita sugestões de perguntas de follow-up
  static Future<FollowUpResult> getFollowUpSuggestions({
    required int questionnaireId,
    required int questionId,
    required String responseValue,
    Map<String, dynamic>? allResponses,
  }) async {
    try {
      final result = await _post('/ai/follow-up', {
        'questionnaire_id': questionnaireId,
        'question_id': questionId,
        'response_value': responseValue,
        if (allResponses != null) 'all_responses': allResponses,
      });

      if (result['success'] == true && result['data'] != null) {
        return FollowUpResult.fromJson(
            result['data'] as Map<String, dynamic>);
      }
      return FollowUpResult.empty;
    } on AiApiException catch (e) {
      print('⚠️ Sugestões de follow-up indisponíveis: $e');
      return FollowUpResult.empty;
    }
  }

  // ============================================================
  // DICAS DE FOLLOW-UP PRÉ-CONFIGURADAS NO PAINEL
  // ============================================================

  /// Busca dicas de follow-up configuradas na tela ai/followup do painel.
  /// GET /ai/followup-tips?questionnaire_id={id}
  /// Retorna mapa questionId -> lista de dicas.
  static Future<Map<int, List<String>>> getFollowUpTips({
    required int questionnaireId,
  }) async {
    try {
      final result = await _get(
        '/ai/followup-tips',
        queryParams: {'questionnaire_id': questionnaireId.toString()},
        timeout: const Duration(seconds: 10),
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        final tips = <int, List<String>>{};
        final list = data['tips'] as List<dynamic>? ?? [];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final qId = item['question_id'] is int
                ? item['question_id'] as int
                : int.tryParse(item['question_id']?.toString() ?? '') ?? 0;
            final tipText = item['tip']?.toString() ?? '';
            final description = item['description']?.toString();
            final fullTip = description != null && description.isNotEmpty
                ? '$tipText\n$description'
                : tipText;
            if (qId > 0 && fullTip.isNotEmpty) {
              tips.putIfAbsent(qId, () => []).add(fullTip);
            }
          }
        }
        return tips;
      }
      return {};
    } catch (e) {
      print('ℹ️ Dicas de follow-up indisponíveis: $e');
      return {};
    }
  }

  // ============================================================
  // RELATÓRIOS
  // ============================================================

  /// Solicita relatório com análise de IA
  static Future<AiReportResult> generateReport({
    required int questionnaireId,
    String reportType = 'descriptive',
    Map<String, dynamic>? filters,
  }) async {
    try {
      final result = await _post(
        '/ai/generate-report',
        {
          'questionnaire_id': questionnaireId,
          'report_type': reportType,
          if (filters != null) 'filters': filters,
        },
        timeout: _reportTimeout,
      );

      if (result['success'] == true && result['data'] != null) {
        return AiReportResult.fromJson(
            result['data'] as Map<String, dynamic>);
      }
      return AiReportResult.empty;
    } on AiApiException catch (e) {
      print('⚠️ Relatório IA indisponível: $e');
      return AiReportResult.empty;
    }
  }

  // ============================================================
  // TRANSCRIÇÕES — SINCRONIZAÇÃO
  // ============================================================

  /// Envia batch de transcrições para o backend.
  /// POST /ai/transcriptions/sync
  static Future<void> syncTranscriptions(
      List<Map<String, dynamic>> transcriptions) async {
    await _post('/ai/transcriptions/sync', {
      'transcriptions': transcriptions,
    });
  }

  // ============================================================
  // AUDITORIA
  // ============================================================

  /// Envia eventos de auditoria de IA para o backend
  static Future<void> logAuditEvent(AiAuditEvent event) async {
    try {
      await _post('/ai/audit-log', event.toJson());
    } catch (e) {
      // Auditoria não deve bloquear o fluxo principal
      print('⚠️ Erro ao registrar evento de auditoria: $e');
    }
  }

  /// Envia batch de eventos de auditoria (para sync offline)
  static Future<void> logAuditEventsBatch(List<AiAuditEvent> events) async {
    try {
      await _post('/ai/audit-log/batch', {
        'events': events.map((e) => e.toJson()).toList(),
      });
    } catch (e) {
      print('⚠️ Erro ao enviar batch de auditoria: $e');
    }
  }

  // ============================================================
  // HEALTH CHECK
  // ============================================================

  /// Verifica se os serviços de IA estão disponíveis.
  /// Tenta /ai/status (endpoint real do backend) com fallback para /ai/health.
  static Future<bool> isAiAvailable() async {
    try {
      final result = await _get('/ai/status', timeout: const Duration(seconds: 5));
      return result['success'] == true ||
          result['status'] == 'active' ||
          result['enabled'] == true;
    } catch (e) {
      // Fallback: se /ai/status falhar com 404, tentar /ai/health
      if (e is AiApiException && e.statusCode == 404) {
        try {
          final result = await _get('/ai/health', timeout: const Duration(seconds: 5));
          return result['success'] == true;
        } catch (_) {
          return false;
        }
      }
      // Se retornou 401, o endpoint existe mas precisa de auth
      // Isso significa que a IA está configurada no backend
      if (e is AiApiException && e.statusCode == 401) {
        return false; // Vai tentar novamente quando o token estiver disponível
      }
      return false;
    }
  }
}

/// Exceção específica para erros da API de IA
class AiApiException implements Exception {
  final String message;
  final int? statusCode;

  AiApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}
