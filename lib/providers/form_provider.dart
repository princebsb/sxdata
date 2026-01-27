import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/form_response.dart';
import '../models/question_response.dart';
import '../models/question.dart';
import '../models/questionnaire.dart';
import '../models/conditional_logic.dart';
import '../services/conditional_logic_engine.dart';
import '../services/local_storage_service.dart';
import '../services/api_service.dart';
import '../services/photo_storage_service.dart';

class FormProvider with ChangeNotifier {
  FormResponse? _currentForm;
  final Map<int, QuestionResponse> _responses = {};
  bool _isSubmitting = false;

  // Campos para lógica condicional
  List<Question> _questions = [];
  Map<int, QuestionState> _questionStates = {};

  // Campos para modo de edição
  bool _isEditMode = false;
  String? _editingFormId;

  FormResponse? get currentForm => _currentForm;
  Map<int, QuestionResponse> get responses => _responses;
  bool get isSubmitting => _isSubmitting;
  List<Question> get questions => _questions;
  Map<int, QuestionState> get questionStates => _questionStates;
  bool get isEditMode => _isEditMode;
  String? get editingFormId => _editingFormId;

  FormResponse? _lastCompletedForm;
  Map<int, QuestionResponse> _lastCompletedResponses = {};

  // ADICIONAR estes getters:
  FormResponse? get lastCompletedForm => _lastCompletedForm;
  Map<int, QuestionResponse> get lastCompletedResponses =>
      _lastCompletedResponses;

  /// Inicia um novo formulário com lógica condicional
  void startForm(int questionnaireId, int userId, List<Question> questions) {
    print('🚀 ========================================');
    print('🚀 === INICIANDO FORMULÁRIO (startForm) ===');
    print('🚀 ========================================');
    print('🚀 CHAMADA: ${DateTime.now().toIso8601String()}');
    print('🚀 Stack Trace para rastrear múltiplas chamadas:');
    print('🚀 ${StackTrace.current}');
    print('📋 Questionnaire ID: $questionnaireId');
    print('👤 User ID: $userId');
    print('📝 Questions: ${questions.length}');
    print('✏️ Modo de edição: $_isEditMode');
    print('✏️ ID do formulário em edição: $_editingFormId');
    print('✏️ Formulário atual (_currentForm): $_currentForm');
    print('✏️ ID do formulário atual: ${_currentForm?.id}');

    try {
      // Se está em modo de edição, preservar o formulário existente COM O ID ORIGINAL
      if (_isEditMode && _editingFormId != null) {
        print('✏️ MODO DE EDIÇÃO - Preservando formulário existente');

        // Converter _editingFormId para int se necessário
        int? formId;
        if (_editingFormId is int) {
          formId = _editingFormId as int;
        } else if (_editingFormId is String) {
          formId = int.tryParse(_editingFormId!);
        }

        print('✏️ === ID CRÍTICO ===');
        print('✏️ _editingFormId original: $_editingFormId');
        print('✏️ formId convertido: $formId');

        if (formId == null) {
          print('❌ ERRO CRÍTICO: Não foi possível converter o ID para edição!');
          throw Exception('ID de edição inválido: $_editingFormId');
        }

        // Criar formulário com ID existente - GARANTIR QUE O ID SEJA PRESERVADO
        _currentForm = FormResponse(
          id: formId,  // ← USAR O ID DO FORMULÁRIO ORIGINAL - CRÍTICO!
          questionnaireId: questionnaireId,
          appliedBy: userId,
          consentGiven: true, // Já tinha dado consentimento antes
          startedAt: DateTime.now(),
        );

        // VERIFICAÇÃO DE SEGURANÇA IMEDIATA
        if (_currentForm!.id != formId) {
          print('❌ ERRO CRÍTICO: FormResponse não preservou o ID!');
          print('   ID esperado: $formId');
          print('   ID obtido: ${_currentForm!.id}');
          throw Exception('FormResponse alterou o ID durante criação');
        }

        print('✅ Formulário de edição criado com ID: ${_currentForm!.id}');
        print('✅ Respostas preservadas: ${_responses.length}');
        // NÃO limpar as respostas em modo de edição
      } else {
        print('📝 MODO NOVO FORMULÁRIO');
        _currentForm = FormResponse(
          questionnaireId: questionnaireId,
          appliedBy: userId,
          consentGiven: false,
          startedAt: DateTime.now(),
        );
        print('📝 Novo formulário criado com ID: ${_currentForm!.id}');
        _responses.clear();
      }

      // CORREÇÃO: Ordenar perguntas por order_index antes de processar
      _questions = List<Question>.from(questions)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      print('📝 === PERGUNTAS ORDENADAS ===');
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        print(
          '📝 Índice $i: ID ${q.id}, Order ${q.orderIndex} - "${q.questionText}"',
        );
        if (q.hasConditionalLogic) {
          print('🔧   Lógica: ${q.conditionalLogicSummary}');
        }
      }

      // Inicializar estados das perguntas
      _initializeQuestionStates();

      print('✅ Formulário iniciado com sucesso');
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Erro ao iniciar formulário: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Carrega um formulário existente para edição
  void loadFormForEdit(FormResponse existingForm, Questionnaire questionnaire) {
    print('📝 === CARREGANDO FORMULÁRIO PARA EDIÇÃO ===');
    print('📋 Form ID: ${existingForm.id}');
    print('📋 Questionário: ${questionnaire.title}');

    try {
      // Carregar o formulário existente
      _currentForm = existingForm;

      // Ordenar perguntas
      _questions = List<Question>.from(questionnaire.questions)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      print('📝 ${_questions.length} perguntas carregadas');

      // Carregar respostas existentes
      _responses.clear();
      for (final response in existingForm.responses) {
        _responses[response.questionId] = response;
        print('📝 Resposta carregada para questão ${response.questionId}: ${response.getValue()}');
      }

      print('📝 ${_responses.length} respostas carregadas');

      // Inicializar estados das perguntas
      _initializeQuestionStates();

      print('✅ Formulário carregado para edição com sucesso');
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Erro ao carregar formulário para edição: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Método compatível para inicialização sem questões (para compatibilidade)
  void initialize(List<Question> questions) {
    print('🔄 === INICIALIZANDO FORM PROVIDER (MÉTODO COMPATÍVEL) ===');
    print('🔄 Modo de edição: $_isEditMode');
    print('🔄 Respostas atuais: ${_responses.length}');

    if (questions.isEmpty) {
      print('⚠️ Lista de questões vazia');
      _questions.clear();
      _questionStates.clear();
      if (!_isEditMode) {
        _responses.clear();
      }
      notifyListeners();
      return;
    }

    try {
      // PRESERVAR respostas se estiver em modo de edição
      final savedResponses = _isEditMode ? Map<int, QuestionResponse>.from(_responses) : null;

      if (_isEditMode) {
        print('✏️ Preservando ${savedResponses!.length} respostas para modo de edição');
      }

      // Limpar estados anteriores (mas preservar respostas em modo de edição)
      if (!_isEditMode) {
        _responses.clear();
      }
      _questionStates.clear();

      // Ordenar perguntas por order_index
      _questions = List<Question>.from(questions)
        ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      // Restaurar respostas se estiver em modo de edição
      if (_isEditMode && savedResponses != null) {
        _responses.clear();
        _responses.addAll(savedResponses);
        print('✏️ Respostas restauradas: ${_responses.length}');
      }

      print('📝 Questões ordenadas: ${_questions.length}');
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        print('📝 [$i] ID ${q.id}, Order ${q.orderIndex}: "${q.questionText}"');
      }

      // Inicializar estados
      _initializeQuestionStates();

      print('✅ Inicialização compatível concluída');
      notifyListeners();
    } catch (e, stackTrace) {
      print('❌ Erro na inicialização compatível: $e');
      print('📋 Stack trace: $stackTrace');

      // Em caso de erro, limpar tudo
      _questions.clear();
      _questionStates.clear();
      _responses.clear();
      notifyListeners();
    }
  }

  /// Inicializa os estados das perguntas
  void _initializeQuestionStates() {
    print('🔧 === INICIALIZANDO ESTADOS DAS PERGUNTAS ===');

    _questionStates.clear();

    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      _questionStates[i] = QuestionState(
        visible: true,
        required: question.isRequired,
        originalRequired: question.isRequired,
      );

      print(
        '📝 Pergunta $i (ID ${question.id}): visible=true, required=${question.isRequired}',
      );
      if (question.hasConditionalLogic) {
        print('🔧 Tem lógica condicional: ${question.conditionalLogicSummary}');
      }
    }

    // Executar lógica condicional inicial mesmo sem respostas
    print('🔧 Executando lógica condicional inicial...');
    _executeConditionalLogic();

    print('✅ Estados inicializados para ${_questionStates.length} perguntas');
  }

  /// Executa a lógica condicional quando uma resposta muda
  void _executeConditionalLogic() {
    if (_questions.isEmpty) return;

    print('🎯 === EXECUTANDO LÓGICA CONDICIONAL ===');

    // Converter respostas para o formato esperado pelo engine
    final Map<int, dynamic> responseValues = {};
    _responses.forEach((questionId, response) {
      responseValues[questionId] = response.getValue();
    });

    print('📝 Respostas para análise: $responseValues');

    // Debug adicional das perguntas sendo processadas
    print('📝 === PERGUNTAS PARA PROCESSAMENTO ===');
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final hasResponse = responseValues.containsKey(q.id);
      final responseValue = responseValues[q.id];
      print(
        '📝 [$i] ID ${q.id}: "${q.questionText}" - Resposta: ${hasResponse ? responseValue : "SEM RESPOSTA"}',
      );
    }

    // Executar lógica condicional usando o engine
    final newStates = ConditionalLogicEngine.executeLogic(
      _questions,
      responseValues,
    );

    // Verificar se houve mudanças
    bool hasChanges = false;
    newStates.forEach((index, newState) {
      final currentState = _questionStates[index];
      if (currentState?.visible != newState.visible ||
          currentState?.required != newState.required) {
        hasChanges = true;
        final question = _questions[index];
        print(
          '🔄 Mudança detectada na pergunta $index (ID ${question.id}): '
          'visible ${currentState?.visible} → ${newState.visible}, '
          'required ${currentState?.required} → ${newState.required}',
        );
      }
    });

    if (hasChanges) {
      _questionStates = newStates;
      print('✅ Estados atualizados, notificando listeners');

      // Debug dos estados finais
      print('📊 === ESTADOS FINAIS ===');
      for (int i = 0; i < _questions.length; i++) {
        final question = _questions[i];
        final state = _questionStates[i]!;
        print(
          '📊 [$i] ID ${question.id}: visible=${state.visible}, required=${state.required}',
        );
      }

      notifyListeners();
    } else {
      print('ℹ️ Nenhuma mudança nos estados');
    }
  }

  /// Verifica se uma pergunta está visível
  bool isQuestionVisible(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= _questions.length) {
      print(
        '⚠️ isQuestionVisible: índice $questionIndex fora do range (0-${_questions.length - 1})',
      );
      return false;
    }

    final visible = _questionStates[questionIndex]?.visible ?? true;
    final question = _questions[questionIndex];

    print(
      '👁️ isQuestionVisible($questionIndex) - ID ${question.id}: $visible',
    );
    return visible;
  }

  /// Verifica se uma pergunta é obrigatória (considerando lógica condicional)
  bool isQuestionRequired(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= _questions.length) {
      print('⚠️ isQuestionRequired: índice $questionIndex fora do range');
      return false;
    }

    final required = _questionStates[questionIndex]?.required ?? false;
    final question = _questions[questionIndex];

    print(
      '⚠️ isQuestionRequired($questionIndex) - ID ${question.id}: $required',
    );
    return required;
  }

  /// Retorna o estado de uma pergunta
  QuestionState? getQuestionState(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= _questions.length) {
      print('⚠️ getQuestionState: índice $questionIndex fora do range');
      return null;
    }

    return _questionStates[questionIndex];
  }

  /// Retorna apenas as perguntas visíveis
  List<Question> getVisibleQuestions() {
    final visibleQuestions = <Question>[];

    for (int i = 0; i < _questions.length; i++) {
      if (isQuestionVisible(i)) {
        visibleQuestions.add(_questions[i]);
      }
    }

    print(
      '👁️ Perguntas visíveis: ${visibleQuestions.length} de ${_questions.length}',
    );

    // Debug das perguntas visíveis
    print('👁️ === PERGUNTAS VISÍVEIS ===');
    for (int i = 0; i < visibleQuestions.length; i++) {
      final q = visibleQuestions[i];
      print('👁️ [$i] ID ${q.id}: "${q.questionText}"');
    }

    return visibleQuestions;
  }

  /// Valida se pode avançar para próxima pergunta
  bool canAdvanceFromQuestion(int questionIndex) {
    if (questionIndex < 0 || questionIndex >= _questions.length) {
      print('⚠️ canAdvanceFromQuestion: índice $questionIndex fora do range');
      return true;
    }

    final question = _questions[questionIndex];
    final state = _questionStates[questionIndex];

    // Se pergunta não está visível, pode avançar
    if (state?.visible != true) {
      print('ℹ️ Pode avançar: pergunta $questionIndex não está visível');
      return true;
    }

    // Se pergunta é obrigatória, verificar se foi respondida
    if (state?.required == true) {
      final response = _responses[question.id];
      final isEmpty = response?.isEmpty ?? true;

      if (isEmpty) {
        print(
          '❌ Não pode avançar: pergunta $questionIndex é obrigatória e não foi respondida',
        );
        return false;
      }
    }

    print('✅ Pode avançar da pergunta $questionIndex');
    return true;
  }

  /// Valida todas as respostas considerando lógica condicional
  ValidationResult validateAllResponses() {
    print('✅ === VALIDANDO TODAS AS RESPOSTAS ===');

    if (_questions.isEmpty) {
      return const ValidationResult(isValid: true, errors: [], warnings: []);
    }

    // Converter respostas para o formato esperado
    final Map<int, dynamic> responseValues = {};
    _responses.forEach((questionId, response) {
      responseValues[questionId] = response.getValue();
    });

    // Usar o engine para validação
    return ConditionalLogicEngine.validateResponses(_questions, responseValues);
  }

  /// Define o consentimento
  void setConsent(bool consent) {
    print('📋 Definindo consentimento: $consent');

    if (_currentForm != null) {
      try {
        _currentForm = _currentForm!.copyWith(consentGiven: consent);
        print('✅ Consentimento definido');
        notifyListeners();
      } catch (e) {
        print('❌ Erro ao definir consentimento: $e');
      }
    } else {
      print('⚠️ Tentativa de definir consentimento sem formulário ativo');
    }
  }

  /// Define uma resposta para uma questão
  void setResponse(int questionId, dynamic value, String type) {
    print('📝 === DEFININDO RESPOSTA ===');
    print('📝 Pergunta ID: $questionId');
    print('📊 Valor: $value (tipo: $type)');

    try {
      QuestionResponse response;

      switch (type.toLowerCase().trim()) {
        case 'text':
        case 'textarea':
          response = QuestionResponse(
            questionId: questionId,
            responseText: value?.toString(),
          );
          break;
        case 'number':
          response = QuestionResponse(
            questionId: questionId,
            responseNumber: double.tryParse(value?.toString() ?? ''),
          );
          break;
        case 'date':
          response = QuestionResponse(
            questionId: questionId,
            responseDate: value is DateTime ? value : null,
          );
          break;
        case 'datetime':
          response = QuestionResponse(
            questionId: questionId,
            responseDatetime: value is DateTime ? value : null,
          );
          break;
        case 'radio':
          response = QuestionResponse(
            questionId: questionId,
            selectedOptions: value != null ? [value.toString()] : [],
          );
          break;
        case 'checkbox':
          List<String> options = [];
          if (value is List) {
            options = value.map((v) => v.toString()).toList();
          } else if (value != null) {
            options = [value.toString()];
          }
          response = QuestionResponse(
            questionId: questionId,
            selectedOptions: options,
          );
          break;
        default:
          print('⚠️ Tipo de questão não reconhecido: $type, usando texto');
          response = QuestionResponse(
            questionId: questionId,
            responseText: value?.toString(),
          );
      }

      _responses[questionId] = response;
      print(
        '✅ Resposta salva para questão $questionId: ${response.getValue()}',
      );

      // Debug das respostas antes de executar lógica
      print('📊 === RESPOSTAS ATUAIS ===');
      _responses.forEach((id, resp) {
        print('📊 ID $id: ${resp.getValue()}');
      });

      // Executar lógica condicional após cada resposta
      print('🔧 Executando lógica condicional após resposta...');
      _executeConditionalLogic();
    } catch (e, stackTrace) {
      print('❌ Erro ao salvar resposta: $e');
      print('📋 Stack trace: $stackTrace');
    }
  }

  /// Método compatível para obter resposta (para compatibilidade)
  dynamic getResponse(int questionId) {
    final response = _responses[questionId];
    return response?.getValue();
  }

  /// Define a localização
  void setLocation(double latitude, double longitude, String? locationName) {
    print('📍 Definindo localização: $latitude, $longitude');

    if (_currentForm != null) {
      try {
        _currentForm = _currentForm!.copyWith(
          latitude: latitude,
          longitude: longitude,
          locationName: locationName,
        );
        print('✅ Localização definida');
        notifyListeners();
      } catch (e) {
        print('❌ Erro ao definir localização: $e');
      }
    } else {
      print('⚠️ Tentativa de definir localização sem formulário ativo');
    }
  }

  /// Define a foto
  void setPhoto(String photoPath) {
    print('📸 Definindo foto: $photoPath');

    if (_currentForm != null) {
      try {
        _currentForm = _currentForm!.copyWith(photoPath: photoPath);
        print('✅ Foto definida');
        notifyListeners();
      } catch (e) {
        print('❌ Erro ao definir foto: $e');
      }
    } else {
      print('⚠️ Tentativa de definir foto sem formulário ativo');
    }
  }

  /// Define a segunda foto
  void setPhoto2(String photoPath2) {
    print('📸 Definindo segunda foto: $photoPath2');

    if (_currentForm != null) {
      try {
        _currentForm = _currentForm!.copyWith(photoPath2: photoPath2);
        print('✅ Segunda foto definida');
        notifyListeners();
      } catch (e) {
        print('❌ Erro ao definir segunda foto: $e');
      }
    } else {
      print('⚠️ Tentativa de definir segunda foto sem formulário ativo');
    }
  }

  void clearPreservedData() {
    print('🧹 Limpando dados preservados');
    _lastCompletedForm = null;
    _lastCompletedResponses.clear();
  }

  /// Salva a foto offline
  Future<String?> savePhotoOffline(String photoPath, {String photoType = 'photo1'}) async {
    print('📸 === SALVANDO FOTO OFFLINE ===');
    print('📸 Tipo: $photoType');

    if (_currentForm == null) {
      print('❌ Nenhum formulário ativo para salvar foto');
      return null;
    }

    try {
      final File photoFile = File(photoPath);

      if (!await photoFile.exists()) {
        print('❌ Arquivo de foto não encontrado: $photoPath');
        return null;
      }

      // Gerar um ID temporário para o formulário se não tiver
      final int formId =
          _currentForm!.id ?? DateTime.now().millisecondsSinceEpoch;

      // Salvar foto localmente usando o PhotoStorageService com o tipo correto
      final String offlineFilename = await PhotoStorageService.savePhotoOffline(
        photoFile,
        formId,
        photoType: photoType,
      );

      print('✅ Foto $photoType salva offline com filename: $offlineFilename');

      // Atualizar o formulário com o filename offline no campo correto
      if (photoType == 'photo1') {
        _currentForm = _currentForm!.copyWith(photoPath: offlineFilename);
      } else if (photoType == 'photo2') {
        _currentForm = _currentForm!.copyWith(photoPath2: offlineFilename);
      }

      notifyListeners();
      return offlineFilename;
    } catch (e, stackTrace) {
      print('❌ Erro ao salvar foto offline: $e');
      print('📋 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Submete o formulário (sem foto)
  Future<bool> submitForm() async {
    return await submitFormWithPhoto(null);
  }

  /// Submete o formulário com foto
  Future<bool> submitFormWithPhoto(String? uploadedPhotoFilename) async {
    print('📤 ========================================');
    print('📤 === INICIANDO SUBMISSÃO DO FORMULÁRIO ===');
    print('📤 ========================================');
    print('📸 Filename da foto enviada: $uploadedPhotoFilename');
    print('✏️ MODO DE EDIÇÃO ATIVO: $_isEditMode');
    print('✏️ ID DO FORMULÁRIO EM EDIÇÃO: $_editingFormId');
    print('✏️ Já está submetendo: $_isSubmitting');
    print('📋 ID DO _currentForm: ${_currentForm?.id}');
    print('📋 ID DO _currentForm (tipo): ${_currentForm?.id.runtimeType}');

    // PROTEÇÃO CONTRA MÚLTIPLAS SUBMISSÕES
    if (_isSubmitting) {
      print('⚠️ ⚠️ ⚠️ SUBMISSÃO JÁ EM ANDAMENTO - Ignorando chamada duplicada');
      return false;
    }

    if (_currentForm == null) {
      print('❌ ❌ ❌ Nenhum formulário ativo para submeter');
      return false;
    }

    // CORREÇÃO CRÍTICA: Se está em modo de edição mas o ID é null, recuperar do _editingFormId
    if (_isEditMode && _currentForm!.id == null && _editingFormId != null) {
      print('⚠️ ⚠️ ⚠️ CORREÇÃO: Modo de edição ativo mas formulário sem ID!');
      print('⚠️ _editingFormId: $_editingFormId');
      print('⚠️ _currentForm.id: ${_currentForm!.id}');

      // Converter _editingFormId para int
      int? recoveredId;
      if (_editingFormId is int) {
        recoveredId = _editingFormId as int;
      } else if (_editingFormId is String) {
        recoveredId = int.tryParse(_editingFormId!);
      }

      if (recoveredId != null) {
        print('⚠️ RECUPERANDO ID de _editingFormId: $recoveredId');
        _currentForm = _currentForm!.copyWith(id: recoveredId);
        print('✅ ID recuperado com sucesso: ${_currentForm!.id}');
      } else {
        print('❌ ERRO CRÍTICO: Não foi possível recuperar o ID!');
        throw Exception('ERRO CRÍTICO: Modo de edição ativo mas não foi possível recuperar ID!');
      }
    }

    // Validar respostas com lógica condicional antes de submeter
    final validation = validateAllResponses();
    if (!validation.isValid) {
      print('❌ Validação falhou:');
      for (final error in validation.errors) {
        print('  - $error');
      }
      return false;
    }

    _isSubmitting = true;
    notifyListeners();

    bool localSaveSuccess = false;
    bool syncSuccess = false;
    FormResponse formToSave;

    try {
      print('📋 ========================================');
      print('📋 === PREPARANDO FORMULÁRIO PARA SUBMISSÃO ===');
      print('📋 ========================================');
      print('📋 ESTADO CRÍTICO DO PROVIDER:');
      print('📋 - _isEditMode: $_isEditMode');
      print('📋 - _editingFormId: $_editingFormId');
      print('📋 - _currentForm: $_currentForm');
      print('📋 - _currentForm.id: ${_currentForm?.id}');
      print('📋 - _currentForm.id (tipo): ${_currentForm?.id.runtimeType}');
      print('📋 Respostas disponíveis: ${_responses.length}');
      print('📋 Respostas coletadas:');
      _responses.forEach((questionId, response) {
        print(
          '   - Questão $questionId: ${response.displayValue} (tipo: ${response.responseText != null
              ? 'texto'
              : response.responseNumber != null
              ? 'número'
              : response.selectedOptions != null
              ? 'opções'
              : 'outro'})',
        );
      });

      // Lidar com fotos offline (primeira e segunda foto)
      String? finalPhotoFilename =
          uploadedPhotoFilename ?? _currentForm!.photoPath;
      String? finalPhotoFilename2 = _currentForm!.photoPath2;

      // PROCESSAR PRIMEIRA FOTO
      if (_currentForm!.photoPath != null &&
          _currentForm!.photoPath!.isNotEmpty) {
        final String photoPath = _currentForm!.photoPath!;

        print('📸 === PROCESSANDO FOTO 1 ===');
        print('📸 Caminho da foto 1: $photoPath');

        // Se o photoPath é um caminho completo, significa que é uma foto local que precisa ser salva offline
        if (photoPath.contains('/') && !photoPath.startsWith('http')) {
          print('📸 Foto 1 local detectada, salvando offline...');

          try {
            final String? offlineFilename = await savePhotoOffline(photoPath, photoType: 'photo1');
            if (offlineFilename != null) {
              finalPhotoFilename = offlineFilename;
              print('✅ Foto 1 salva offline como: $offlineFilename');
            } else {
              print('⚠️ Falha ao salvar foto 1 offline, usando caminho original');
              finalPhotoFilename = photoPath;
            }
          } catch (e) {
            print('❌ Erro ao salvar foto 1 offline: $e');
            finalPhotoFilename = photoPath; // Fallback para caminho original
          }
        } else {
          // Já é um filename do servidor ou offline
          print('📸 Foto 1 já processada (filename): $photoPath');
          finalPhotoFilename = photoPath;
        }
      } else {
        print('📸 Nenhuma foto 1 no formulário');
      }

      // PROCESSAR SEGUNDA FOTO
      if (_currentForm!.photoPath2 != null &&
          _currentForm!.photoPath2!.isNotEmpty) {
        final String photoPath2 = _currentForm!.photoPath2!;

        print('📸 === PROCESSANDO FOTO 2 ===');
        print('📸 Caminho da foto 2: $photoPath2');

        // Se o photoPath2 é um caminho completo, significa que é uma foto local que precisa ser salva offline
        if (photoPath2.contains('/') && !photoPath2.startsWith('http')) {
          print('📸 Foto 2 local detectada, salvando offline...');

          try {
            final String? offlineFilename2 = await savePhotoOffline(photoPath2, photoType: 'photo2');
            if (offlineFilename2 != null) {
              finalPhotoFilename2 = offlineFilename2;
              print('✅ Foto 2 salva offline como: $offlineFilename2');
            } else {
              print('⚠️ Falha ao salvar foto 2 offline, usando caminho original');
              finalPhotoFilename2 = photoPath2;
            }
          } catch (e) {
            print('❌ Erro ao salvar foto 2 offline: $e');
            finalPhotoFilename2 = photoPath2; // Fallback para caminho original
          }
        } else {
          // Já é um filename do servidor ou offline
          print('📸 Foto 2 já processada (filename): $photoPath2');
          finalPhotoFilename2 = photoPath2;
        }
      } else {
        print('📸 Nenhuma foto 2 no formulário');
      }

      // Preparar formulário para salvamento
      // Se estiver em modo de edição, GARANTIR que usa o ID existente
      print('📝 ========================================');
      print('📝 === PREPARAR FORMULÁRIO PARA SALVAMENTO ===');
      print('📝 ========================================');
      print('📝 ESTADO COMPLETO:');
      print('📝 - _isEditMode: $_isEditMode');
      print('📝 - _editingFormId: $_editingFormId (tipo: ${_editingFormId.runtimeType})');
      print('📝 - _currentForm: $_currentForm');
      print('📝 - _currentForm.id: ${_currentForm?.id} (tipo: ${_currentForm?.id.runtimeType})');
      print('📝 ========================================');

      if (_isEditMode && _editingFormId != null) {
        print('✏️ ✏️ ✏️ === MODO DE EDIÇÃO ATIVO ===');
        print('✏️ _editingFormId: $_editingFormId (tipo: ${_editingFormId.runtimeType})');
        print('✏️ _currentForm.id ANTES: ${_currentForm?.id}');

        // Garantir que o ID seja int (pode vir como String do storage)
        int? editId;
        if (_editingFormId is int) {
          editId = _editingFormId as int?;
          print('✏️ ID já é int: $editId');
        } else if (_editingFormId is String) {
          editId = int.tryParse(_editingFormId!);
          print('✏️ ID convertido de String para int: $editId');
        }

        // FALLBACK: Se por algum motivo editId é null, usar o ID do currentForm
        if (editId == null && _currentForm?.id != null) {
          editId = _currentForm!.id;
          print('✏️ FALLBACK: Usando ID de _currentForm: $editId');
        }

        print('✏️ ID FINAL que será usado para SOBRESCREVER: $editId');

        formToSave = _currentForm!.copyWith(
          id: editId, // ← CRÍTICO: Usar ID existente para sobrescrever
          syncStatus: 'pending', // Manter como pending para sincronizar depois
          completedAt: DateTime.now(),
          responses: _responses.values.toList(),
          photoPath: finalPhotoFilename,
          photoPath2: finalPhotoFilename2,
        );

        print('✏️ formToSave DEPOIS do copyWith:');
        print('   - id: ${formToSave.id} (DEVE SER O MESMO QUE $editId)');
        print('   - questionnaireId: ${formToSave.questionnaireId}');

        // VERIFICAÇÃO DE SEGURANÇA
        if (formToSave.id != editId) {
          print('❌ ERRO CRÍTICO: O ID do formulário mudou!');
          print('   Esperado: $editId');
          print('   Obtido: ${formToSave.id}');
          throw Exception('ID do formulário não foi preservado no modo de edição');
        }
      } else {
        print('📝 MODO NOVO FORMULÁRIO - Criando novo registro');
        formToSave = _currentForm!.copyWith(
          syncStatus: 'pending', // SEMPRE inicia como pending
          completedAt: DateTime.now(),
          responses: _responses.values.toList(),
          photoPath: finalPhotoFilename,
          photoPath2: finalPhotoFilename2,
        );
      }

      print('📋 === FORMULÁRIO PREPARADO PARA SALVAMENTO ===');
      print('   - Modo: ${_isEditMode ? "EDIÇÃO" : "NOVO"}');
      print('   - ID do formulário: ${formToSave.id}');
      print('   - ID do questionário: ${formToSave.questionnaireId}');
      print('   - Aplicado por: ${formToSave.appliedBy}');
      print('   - Respostas: ${formToSave.responses.length}');
      print('   - Consentimento: ${formToSave.consentGiven}');
      print(
        '   - Localização: ${formToSave.latitude}, ${formToSave.longitude}',
      );
      print('   - Foto 1 (filename): ${formToSave.photoPath}');
      print('   - Foto 2 (filename): ${formToSave.photoPath2}');
      print('   - Status inicial: ${formToSave.syncStatus}');
      print('   - Iniciado em: ${formToSave.startedAt}');
      print('   - Concluído em: ${formToSave.completedAt}');

      // 1. SEMPRE salvar localmente primeiro - CRÍTICO!
      print('💾 === SALVANDO LOCALMENTE (OFFLINE FIRST) ===');
      try {
        print('📄 Chamando LocalStorageService.saveFormResponse...');
        await LocalStorageService.saveFormResponse(formToSave);
        localSaveSuccess = true;
        print('✅ === SALVO LOCALMENTE COM SUCESSO ===');
      } catch (e, stackTrace) {
        print('❌ === ERRO CRÍTICO NO SALVAMENTO LOCAL ===');
        print('❌ Erro: $e');
        print('📋 Stack trace: $stackTrace');
        localSaveSuccess = false;

        // Tentar salvamento com dados mínimos como fallback
        print('🆘 === TENTATIVA DE SALVAMENTO MÍNIMO ===');
        try {
          final simpleForm = FormResponse(
            questionnaireId: _currentForm!.questionnaireId,
            appliedBy: _currentForm!.appliedBy,
            consentGiven: _currentForm!.consentGiven,
            syncStatus: 'pending',
            startedAt: _currentForm!.startedAt,
            completedAt: DateTime.now(),
            responses: _responses.values.toList(),
            photoPath: finalPhotoFilename,
            photoPath2: finalPhotoFilename2,
          );

          await LocalStorageService.saveFormResponse(simpleForm);
          localSaveSuccess = true;
          formToSave = simpleForm;
          print('✅ Salvamento mínimo bem-sucedido');
        } catch (alternativeError) {
          print('💥 FALHA TOTAL no salvamento: $alternativeError');
          // NÃO lançar exceção aqui - vamos tentar continuar
          localSaveSuccess = false;
        }
      }

      // LEOHARLEY: COMENTEI ABAIXO PARA EVITAR QUE O FORMULÁRIO SEJA SUBMETIDO AUTOMATICAMENTE APOS CONCLUIDO, SOMENTE PELO BOTÃO DE SINCRONIZAR

      // 2. Tentar sincronizar com servidor (se possível) - SEM UPLOAD DE FOTO
      // As fotos agora são sincronizadas separadamente pelo PhotoStorageService

      /*if (localSaveSuccess) {
        print('🌐 === TENTANDO SINCRONIZAR FORMULÁRIO COM SERVIDOR ===');
        try {
          final result = await ApiService.submitForm(formToSave);
          
          if (result['success'] == true) {
            print('✅ Formulário sincronizado com servidor com sucesso');
            syncSuccess = true;
            
            // Atualizar status para 'synced' apenas se conseguiu sincronizar
            if (formToSave.id != null) {
              try {
                await LocalStorageService.updateFormSyncStatus(
                  formToSave.id!, 'synced'
                );
                print('✅ Status local atualizado para \'synced\'');
              } catch (e) {
                print('⚠️ Erro ao atualizar status local, mas sincronização foi bem-sucedida: $e');
              }
            }
          } else {
            print('⚠️ Servidor retornou erro: ${result['message']}');
            syncSuccess = false;
          }
        } catch (e) {
          print('⚠️ Erro ao sincronizar formulário com servidor (modo OFFLINE): $e');
          syncSuccess = false;
          // Em modo offline, isso é esperado - não é um erro crítico
        }
      }

      // 3. Limpar formulário atual APENAS se salvou localmente com sucesso
      if (localSaveSuccess) {
        print('🧹 === LIMPANDO FORMULÁRIO ATUAL ===');
        _currentForm = null;
        _responses.clear();
        _questions.clear();
        _questionStates.clear();
        print('✅ Formulário atual limpo');
      } else {
        print('⚠️ Não limpando formulário - salvamento local falhou');
      }

      */

      // Status final
      print('📊 === SUBMISSÃO CONCLUÍDA ===');
      print('   - Salvo localmente: $localSaveSuccess');
      print('   - Sincronizado: $syncSuccess');
      print('   - Formulário limpo: $localSaveSuccess');
      print('   - Foto offline: ${finalPhotoFilename != null}');

      // LIMPAR MODO DE EDIÇÃO APÓS SUBMISSÃO BEM-SUCEDIDA
      if (localSaveSuccess && _isEditMode) {
        print('✏️ Limpando modo de edição após submissão');
        clearEditMode();
      }

      notifyListeners();

      // Retorna true se pelo menos salvou localmente
      return localSaveSuccess;
    } catch (e, stackTrace) {
      print('❌ === ERRO DURANTE SUBMISSÃO ===');
      print('❌ Erro: $e');
      print('📋 Stack trace: $stackTrace');

      // Se chegou aqui, algo deu muito errado
      // Tentar uma última vez salvar localmente se não conseguiu antes
      if (!localSaveSuccess && _currentForm != null) {
        print('🆘 === TENTATIVA DE SALVAMENTO DE EMERGÊNCIA ===');
        try {
          final emergencyForm = _currentForm!.copyWith(
            syncStatus: 'pending',
            completedAt: DateTime.now(),
            responses: _responses.values.toList(),
            photoPath: uploadedPhotoFilename ?? _currentForm!.photoPath,
            photoPath2: _currentForm!.photoPath2,
          );

          print('📄 Tentando salvar formulário de emergência...');
          await LocalStorageService.saveFormResponse(emergencyForm);
          print('✅ Salvamento de emergência bem-sucedido');

          // Limpar apenas se conseguiu salvar
          _currentForm = null;
          _responses.clear();
          _questions.clear();
          _questionStates.clear();
          localSaveSuccess = true;
          notifyListeners();

          return true; // Conseguiu salvar na tentativa de emergência
        } catch (emergencyError) {
          print(
            '💥 FALHA TOTAL: Não foi possível salvar nem em emergência: $emergencyError',
          );
          return false;
        }
      }

      return localSaveSuccess; // Retorna se conseguiu salvar localmente antes do erro
    } finally {
      print('📚 ========================================');
      print('📚 === FIM DA SUBMISSÃO (FINALLY) ===');
      print('📚 ========================================');
      print('📚 - _isSubmitting ANTES de resetar: $_isSubmitting');
      _isSubmitting = false;
      print('📚 - _isSubmitting DEPOIS de resetar: $_isSubmitting');
      print('📚 - _isEditMode: $_isEditMode');
      print('📚 - _editingFormId: $_editingFormId');
      print('📚 - localSaveSuccess: $localSaveSuccess');
      print('📚 ========================================');
      notifyListeners();
    }
  }

  /// Limpa o formulário atual
  void clearForm() {
    print('🧹 Limpando formulário');
    _currentForm = null;
    _responses.clear();
    _questions.clear();
    _questionStates.clear();
    notifyListeners();
  }

  /// Carregar respostas existentes para edição
  void loadExistingResponses(Map<int, QuestionResponse> existingResponses) {
    print('📝 === CARREGANDO RESPOSTAS EXISTENTES PARA EDIÇÃO ===');
    print('📝 Número de respostas: ${existingResponses.length}');

    _responses.clear();
    _responses.addAll(existingResponses);

    print('✅ Respostas carregadas com sucesso');
    notifyListeners();
  }

  /// Definir modo de edição
  void setEditMode(String formId) {
    print('✏️ Ativando modo de edição para formulário: $formId');
    _isEditMode = true;
    _editingFormId = formId;
    notifyListeners();
  }

  /// Limpar modo de edição
  void clearEditMode() {
    print('✏️ Desativando modo de edição');
    _isEditMode = false;
    _editingFormId = null;
    notifyListeners();
  }

  /// Verifica se há formulários pendentes de sincronização
  Future<List<FormResponse>> getPendingForms() async {
    try {
      print('📋 === BUSCANDO FORMULÁRIOS PENDENTES ===');
      final allForms = await LocalStorageService.getFormResponses();
      print('📋 Total de formulários no storage: ${allForms.length}');

      // Debug: mostrar status de cada formulário
      for (int i = 0; i < allForms.length; i++) {
        final form = allForms[i];
        print('📋 Formulário $i: ID=${form.id}, Status="${form.syncStatus}", Questionário=${form.questionnaireId}');
      }

      final pendingForms = allForms.where((form) => form.syncStatus == 'pending').toList();
      print('📋 Formulários com status "pending": ${pendingForms.length}');

      if (pendingForms.isEmpty && allForms.isNotEmpty) {
        print('⚠️ ATENÇÃO: Há formulários no storage mas nenhum com status "pending"!');
        print('⚠️ Status encontrados:');
        for (final form in allForms) {
          print('   - Formulário ${form.id}: "${form.syncStatus}"');
        }
      }

      return pendingForms;
    } catch (e, stackTrace) {
      print('❌ Erro ao buscar formulários pendentes: $e');
      print('📋 Stack trace: $stackTrace');
      return [];
    }
  }

  /// Sincroniza apenas fotos pendentes
  Future<int> syncPendingPhotosOnly() async {
    print('📸 === SINCRONIZAÇÃO ESPECÍFICA DE FOTOS ===');

    try {
      // Debug antes da sincronização
      print('📸 Debug antes da sincronização:');
      await PhotoStorageService.debugPrintPhotos();

      // Executar sincronização
      final syncedCount = await PhotoStorageService.syncPendingPhotos();

      // Debug após sincronização
      print('📸 Debug após sincronização:');
      await PhotoStorageService.debugPrintPhotos();

      print('📸 Resultado: $syncedCount fotos sincronizadas');
      return syncedCount;
    } catch (e, stackTrace) {
      print('❌ Erro na sincronização de fotos: $e');
      print('📋 Stack trace: $stackTrace');
      return 0;
    }
  }

  /// Diagnóstico completo de fotos
  Future<void> debugPhotosFullDiagnostic() async {
    print('🔍 === DIAGNÓSTICO COMPLETO DE FOTOS ===');

    try {
      // 1. Verificar estatísticas
      final stats = await PhotoStorageService.getPhotosStats();
      print('📊 Estatísticas: $stats');

      // 2. Listar fotos pendentes
      final pendingPhotos = await PhotoStorageService.getPendingPhotos();
      print('📸 Fotos pendentes: ${pendingPhotos.length}');

      for (int i = 0; i < pendingPhotos.length; i++) {
        final photo = pendingPhotos[i];
        print('📸 [$i] ${photo['filename']}:');
        print('   - Form ID: ${photo['formId']}');
        print('   - Local Path: ${photo['localPath']}');
        print('   - Status: ${photo['syncStatus']}');
        print('   - File Size: ${photo['fileSize']}');

        // Verificar se arquivo existe
        final File photoFile = File(photo['localPath']);
        final bool exists = await photoFile.exists();
        print('   - Arquivo existe: $exists');

        if (exists) {
          final int currentSize = await photoFile.length();
          print('   - Tamanho atual: $currentSize bytes');
        }
      }

      // 3. Debug completo
      await PhotoStorageService.debugPrintPhotos();
    } catch (e, stackTrace) {
      print('❌ Erro no diagnóstico: $e');
      print('📋 Stack trace: $stackTrace');
    }

    print('🔍 === FIM DIAGNÓSTICO ===');
  }

  /// Sincroniza formulários e fotos pendentes
  Future<int> syncPendingForms() async {
    print('🔄 === SINCRONIZAÇÃO COMPLETA (FORMULÁRIOS + FOTOS) ===');
    print('🔄 Timestamp: ${DateTime.now()}');

    try {
      int totalSynced = 0;

      // 1. Sincronizar formulários pendentes PRIMEIRO
      print('📋 === FASE 1: SINCRONIZANDO FORMULÁRIOS ===');

      List<FormResponse> pendingForms;
      try {
        pendingForms = await getPendingForms();
        print('📋 ${pendingForms.length} formulários pendentes encontrados');
      } catch (e, stackTrace) {
        print('❌ ERRO CRÍTICO ao buscar formulários pendentes: $e');
        print('📋 Stack trace: $stackTrace');
        return 0; // Retorna 0 se não conseguir buscar
      }

      if (pendingForms.isEmpty) {
        print('⚠️ Nenhum formulário pendente para sincronizar');
        // Continua para sincronizar fotos
      }

      int formsSyncedCount = 0;
      for (int i = 0; i < pendingForms.length; i++) {
        final form = pendingForms[i];

        try {
          print('📋 === SINCRONIZANDO FORMULÁRIO ${i + 1}/${pendingForms.length} ===');
          print('📋 ID do formulário: ${form.id}');
          print('📋 Questionário ID: ${form.questionnaireId}');
          print('📋 Aplicado por: ${form.appliedBy}');
          print('📋 Respostas: ${form.responses.length}');
          print('📋 Status atual: ${form.syncStatus}');

          // Debug do JSON antes de enviar
          final formMap = form.toJson();
          print('📋 JSON preparado para envio (${formMap.toString().length} caracteres)');

          // Tentar sincronizar com o servidor
          print('🌐 Enviando para API...');
          final result = await ApiService.submitForm(form);

          print('📋 Resposta da API: $result');

          if (result['success'] == true) {
            // Atualizar status para sincronizado
            if (form.id != null) {
              await LocalStorageService.updateFormSyncStatus(
                form.id!,
                'synced',
              );
              formsSyncedCount++;
              print('✅ Formulário ${form.id} sincronizado com sucesso!');
            } else {
              print('⚠️ Formulário sincronizado mas sem ID local');
            }
          } else {
            print('⚠️ Falha ao sincronizar formulário ${form.id}: ${result['message']}');
          }
        } catch (e, stackTrace) {
          print('❌ Erro ao sincronizar formulário ${form.id}: $e');
          print('📋 Stack trace: $stackTrace');
        }
      }

      totalSynced += formsSyncedCount;
      print('📋 === RESULTADO FASE 1 ===');
      print('📋 Formulários sincronizados: $formsSyncedCount de ${pendingForms.length}');

      // 2. Sincronizar fotos pendentes SEPARADAMENTE E SEMPRE
      print('📸 === FASE 2: SINCRONIZANDO FOTOS ===');
      try {
        // Verificar estatísticas antes
        final photosStatsBefore = await PhotoStorageService.getPhotosStats();
        print('📸 Fotos antes da sync: $photosStatsBefore');

        // Executar sincronização de fotos
        final photosSyncedCount = await PhotoStorageService.syncPendingPhotos();
        print('📸 Resultado da sincronização de fotos: $photosSyncedCount');

        // Verificar estatísticas depois
        final photosStatsAfter = await PhotoStorageService.getPhotosStats();
        print('📸 Fotos após a sync: $photosStatsAfter');

        totalSynced += photosSyncedCount;
      } catch (e, stackTrace) {
        print('❌ ERRO CRÍTICO na sincronização de fotos: $e');
        print('📋 Stack trace: $stackTrace');

        // Debug adicional em caso de erro
        try {
          await PhotoStorageService.debugPrintPhotos();
        } catch (debugError) {
          print('❌ Erro no debug de fotos: $debugError');
        }
      }

      print('📊 === SINCRONIZAÇÃO COMPLETA CONCLUÍDA ===');
      print(
        '   - Formulários sincronizados: $formsSyncedCount de ${pendingForms.length}',
      );
      print('   - Fotos processadas: executado (verificar logs acima)');
      print('   - Total de itens sincronizados: $totalSynced');

      return totalSynced;
    } catch (e, stackTrace) {
      print('❌ Erro durante sincronização completa: $e');
      print('📋 Stack trace: $stackTrace');
      return 0;
    }
  }

  // ========== MÉTODOS DE DEBUG ==========

  /// Debug do estado atual
  void debugPrintCurrentState() {
    print('🔍 Estado atual do FormProvider:');
    print('   - Formulário ativo: ${_currentForm != null}');
    print('   - Perguntas: ${_questions.length}');
    print('   - Respostas: ${_responses.length}');
    print('   - Estados: ${_questionStates.length}');
    print('   - Enviando: $_isSubmitting');

    if (_currentForm != null) {
      print('   - Questionário ID: ${_currentForm!.questionnaireId}');
      print('   - Aplicado por: ${_currentForm!.appliedBy}');
      print('   - Consentimento: ${_currentForm!.consentGiven}');
    }

    _responses.forEach((questionId, response) {
      print('   - Questão $questionId: ${response.toString()}');
    });

    print('🔧 Estados das perguntas:');
    _questionStates.forEach((index, state) {
      final question = index < _questions.length ? _questions[index] : null;
      if (question != null) {
        print('   - Pergunta $index (ID ${question.id}): $state');
      } else {
        print('   - Pergunta $index: $state');
      }
    });
  }

  /// Debug do storage local
  Future<void> debugPrintLocalStorage() async {
    print('🔍 === DEBUG STORAGE LOCAL VIA FORMPROVIDER ===');
    try {
      final forms = await LocalStorageService.getFormResponses();
      print('📋 Total de formulários encontrados: ${forms.length}');

      final pending = forms.where((f) => f.syncStatus == 'pending').length;
      final synced = forms.where((f) => f.syncStatus == 'synced').length;

      print('   - Pendentes: $pending');
      print('   - Sincronizados: $synced');

      for (var form in forms) {
        print(
          '   - ID: ${form.id}, Status: ${form.syncStatus}, Questionário: ${form.questionnaireId}, Respostas: ${form.responses.length}',
        );
      }
    } catch (e) {
      print('❌ Erro no debug do storage: $e');
    }
    print('🔍 === FIM DEBUG FORMPROVIDER ===');
  }

  /// Teste de salvamento do formulário atual
  Future<bool> testSaveCurrentForm() async {
    if (_currentForm == null) {
      print('❌ Nenhum formulário ativo para testar');
      return false;
    }

    print('🧪 === TESTE DE SALVAMENTO DO FORMULÁRIO ATUAL ===');
    try {
      final testForm = _currentForm!.copyWith(
        id: DateTime.now().millisecondsSinceEpoch,
        syncStatus: 'test',
        completedAt: DateTime.now(),
        responses: _responses.values.toList(),
      );

      await LocalStorageService.saveFormResponse(testForm);

      // Verificar se foi salvo
      final forms = await LocalStorageService.getFormResponses();
      final found = forms.any((f) => f.id == testForm.id);

      if (found) {
        print('✅ Teste do formulário atual PASSOU');

        // Limpar o teste
        final filteredForms = forms.where((f) => f.id != testForm.id).toList();
        final prefs = await SharedPreferences.getInstance();
        if (filteredForms.isEmpty) {
          await prefs.remove('form_responses');
        } else {
          final jsonList = filteredForms.map((f) => f.toJson()).toList();
          final jsonString = jsonEncode(jsonList);
          await prefs.setString('form_responses', jsonString);
        }

        return true;
      } else {
        print('❌ Teste do formulário atual FALHOU');
        return false;
      }
    } catch (e) {
      print('❌ Erro no teste: $e');
      return false;
    }
  }

  /// MÉTODO DE TESTE: Testa a lógica condicional com dados mockados
  void testConditionalLogic() {
    print('🧪 === TESTE DA LÓGICA CONDICIONAL ===');

    if (_questions.isEmpty) {
      print('❌ Nenhuma questão disponível para teste');
      return;
    }

    print('🧪 Testando com o formato JSON correto...');

    // Exemplo do JSON fornecido pelo usuário:
    // {"visibility":{"operator":"AND","conditions":[{"question":0,"operator":"equals","value":"teste"}]},"required":null}

    print(
      '🧪 Simulando JSON: {"visibility":{"operator":"AND","conditions":[{"question":0,"operator":"equals","value":"teste"}]},"required":null}',
    );

    // Encontrar questões com lógica condicional
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];

      if (question.hasConditionalLogic) {
        print('🧪 === TESTANDO QUESTÃO $i (ID ${question.id}) ===');
        print('🧪 Texto: "${question.questionText}"');
        print('🧪 JSON da lógica: ${question.conditionalLogic}');

        final logic = question.parsedConditionalLogic!;

        if (logic.visibility != null) {
          print('🧪 Regras de visibilidade encontradas:');
          for (var condition in logic.visibility!.conditions) {
            print(
              '   - Questão ID ${condition.questionId} ${condition.operator} "${condition.value}"',
            );

            // Testar cenário 1: Condição VERDADEIRA
            final testResponsesTrue = <int, dynamic>{
              condition.questionId: condition.value,
            };
            print(
              '🧪 TESTE 1: Resposta questão ${condition.questionId} = "${condition.value}"',
            );
            final resultTrue = ConditionalLogicEngine.executeLogic(
              _questions,
              testResponsesTrue,
            );
            final stateTrue = resultTrue[i];
            print(
              '🧪 Resultado: visible=${stateTrue?.visible}, required=${stateTrue?.required}',
            );
            print('');

            // Testar cenário 2: Condição FALSA
            final testResponsesFalse = <int, dynamic>{
              condition.questionId: 'outro_valor_diferente',
            };
            print(
              '🧪 TESTE 2: Resposta questão ${condition.questionId} = "outro_valor_diferente"',
            );
            final resultFalse = ConditionalLogicEngine.executeLogic(
              _questions,
              testResponsesFalse,
            );
            final stateFalse = resultFalse[i];
            print(
              '🧪 Resultado: visible=${stateFalse?.visible}, required=${stateFalse?.required}',
            );
            print('');

            // Testar cenário 3: Sem resposta
            final testResponsesEmpty = <int, dynamic>{};
            print(
              '🧪 TESTE 3: Sem resposta para questão ${condition.questionId}',
            );
            final resultEmpty = ConditionalLogicEngine.executeLogic(
              _questions,
              testResponsesEmpty,
            );
            final stateEmpty = resultEmpty[i];
            print(
              '🧪 Resultado: visible=${stateEmpty?.visible}, required=${stateEmpty?.required}',
            );
            print('');
          }
        }

        if (logic.required != null) {
          print('🧪 Regras de obrigatoriedade encontradas:');
          for (var condition in logic.required!.conditions) {
            print(
              '   - Questão ID ${condition.questionId} ${condition.operator} "${condition.value}"',
            );
          }
        }

        print('🧪 === FIM TESTE QUESTÃO $i ===');
        print('');
      }
    }

    print('🧪 === FIM TESTE GERAL ===');
  }

  /// Testa especificamente o JSON fornecido pelo usuário
  void testSpecificJSON() {
    print('🧪 === TESTE ESPECÍFICO DO JSON FORNECIDO ===');

    // JSON do usuário: {"visibility":{"operator":"AND","conditions":[{"question":0,"operator":"equals","value":"teste"}]},"required":null}

    final testJson = {
      "visibility": {
        "operator": "AND",
        "conditions": [
          {"question": 0, "operator": "equals", "value": "teste"},
        ],
      },
      "required": null,
    };

    print('🧪 JSON de teste: $testJson');

    try {
      // Testar parsing do JSON
      final logic = ConditionalLogic.fromJson(testJson);
      print('✅ JSON parseado com sucesso');
      print('🧪 Tem regras de visibilidade: ${logic.visibility != null}');
      print('🧪 Tem regras de obrigatoriedade: ${logic.required != null}');

      if (logic.visibility != null) {
        print('🧪 Operador: ${logic.visibility!.operator}');
        print('🧪 Condições: ${logic.visibility!.conditions.length}');

        for (int i = 0; i < logic.visibility!.conditions.length; i++) {
          final condition = logic.visibility!.conditions[i];
          print('🧪 Condição $i:');
          print('   - Questão ID: ${condition.questionId}');
          print('   - Operador: ${condition.operator}');
          print('   - Valor: "${condition.value}"');
        }

        // Testar avaliação
        print('🧪 === TESTANDO AVALIAÇÃO ===');

        // Cenário 1: Questão 0 = "teste" (deve ser true)
        final responses1 = {0: "teste"};
        print('🧪 Teste 1: Questão 0 = "teste"');
        final result1 = logic.visibility!.evaluate(responses1);
        print('🧪 Resultado: $result1 (esperado: true)');

        // Cenário 2: Questão 0 = "outro" (deve ser false)
        final responses2 = {0: "outro"};
        print('🧪 Teste 2: Questão 0 = "outro"');
        final result2 = logic.visibility!.evaluate(responses2);
        print('🧪 Resultado: $result2 (esperado: false)');

        // Cenário 3: Sem resposta (deve ser false)
        final responses3 = <int, dynamic>{};
        print('🧪 Teste 3: Sem resposta');
        final result3 = logic.visibility!.evaluate(responses3);
        print('🧪 Resultado: $result3 (esperado: false)');
      }
    } catch (e, stackTrace) {
      print('❌ Erro ao testar JSON: $e');
      print('📋 Stack trace: $stackTrace');
    }

    print('🧪 === FIM TESTE ESPECÍFICO ===');
  }

  /// Força a re-execução da lógica condicional com logs detalhados
  void debugConditionalLogic() {
    print('🔧 === DEBUG DETALHADO DA LÓGICA CONDICIONAL ===');

    if (_questions.isEmpty) {
      print('❌ Nenhuma questão carregada');
      return;
    }

    print('📝 Questões carregadas: ${_questions.length}');
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      print('[$i] ID ${q.id}: "${q.questionText}"');
      print('     Tipo: ${q.questionType}');
      print('     Order: ${q.orderIndex}');
      print('     Required: ${q.isRequired}');
      print('     Tem lógica: ${q.hasConditionalLogic}');

      if (q.hasConditionalLogic) {
        print('     JSON lógica: ${q.conditionalLogic}');

        try {
          final parsedLogic = q.parsedConditionalLogic;
          if (parsedLogic != null) {
            print('     Lógica parseada: OK');
            if (parsedLogic.visibility != null) {
              print(
                '     Regras visibilidade: ${parsedLogic.visibility!.conditions.length}',
              );
              for (var cond in parsedLogic.visibility!.conditions) {
                print(
                  '       - Questão ${cond.questionId} ${cond.operator} "${cond.value}"',
                );
              }
            }
            if (parsedLogic.required != null) {
              print(
                '     Regras obrigatoriedade: ${parsedLogic.required!.conditions.length}',
              );
            }
          } else {
            print('     ❌ Falha ao parsear lógica');
          }
        } catch (e) {
          print('     ❌ Erro ao analisar lógica: $e');
        }
      }
      print('');
    }

    print('📋 Respostas atuais: ${_responses.length}');
    _responses.forEach((id, response) {
      print(
        'Questão $id: "${response.getValue()}" (${response.getValue().runtimeType})',
      );
    });

    print('📊 Estados atuais: ${_questionStates.length}');
    _questionStates.forEach((index, state) {
      final q = _questions[index];
      print(
        '[$index] ID ${q.id}: visible=${state.visible}, required=${state.required}',
      );
    });

    // Forçar execução da lógica
    print('🔧 Forçando execução da lógica...');
    _executeConditionalLogic();

    print('🔧 === FIM DEBUG ===');
  }

  /// Debug específico para uma pergunta por ID
  void debugQuestionById(int questionId) {
    print('🔍 === DEBUG ESPECÍFICO DA PERGUNTA ID $questionId ===');

    // Encontrar a pergunta
    final questionIndex = _questions.indexWhere((q) => q.id == questionId);
    if (questionIndex == -1) {
      print('❌ Pergunta ID $questionId não encontrada!');
      return;
    }

    final question = _questions[questionIndex];
    final state = _questionStates[questionIndex];

    print('📝 Pergunta ID $questionId encontrada no índice: $questionIndex');
    print('📝 Texto: "${question.questionText}"');
    print('📝 Tem lógica condicional: ${question.hasConditionalLogic}');
    print('📝 Estado atual: $state');

    if (question.hasConditionalLogic) {
      print('🔧 Lógica condicional: ${question.conditionalLogicSummary}');
      print('🔧 JSON da lógica: ${question.conditionalLogic}');

      // Verificar dependências
      final logic = question.parsedConditionalLogic;
      if (logic != null) {
        if (logic.visibility != null) {
          print('👁️ Regras de visibilidade:');
          for (var condition in logic.visibility!.conditions) {
            final depResponse = _responses[condition.questionId];
            print(
              '   - Pergunta ${condition.questionId} ${condition.operator} ${condition.value}',
            );
            print('   - Resposta atual: ${depResponse?.getValue()}');
          }
        }

        if (logic.required != null) {
          print('⚠️ Regras de obrigatoriedade:');
          for (var condition in logic.required!.conditions) {
            final depResponse = _responses[condition.questionId];
            print(
              '   - Pergunta ${condition.questionId} ${condition.operator} ${condition.value}',
            );
            print('   - Resposta atual: ${depResponse?.getValue()}');
          }
        }
      }
    }

    print('🔍 === FIM DEBUG PERGUNTA ID $questionId ===');
  }

  /// Método de compatibilidade - debug da pergunta ID 8
  void debugQuestionId8() {
    debugQuestionById(8);
  }
}
