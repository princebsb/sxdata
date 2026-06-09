import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/questionnaire.dart';
import '../models/question.dart';
import '../models/ai_models.dart';
import '../providers/form_provider.dart';
import '../providers/ai_provider.dart';
import '../widgets/question_widgets.dart';
import '../widgets/voice_transcription_widget.dart';
import '../widgets/inconsistency_alert_widget.dart';
import '../widgets/standardization_suggestion_widget.dart';
import '../widgets/smart_suggestion_widget.dart';
import '../widgets/follow_up_suggestion_widget.dart';
import '../widgets/ai_status_indicator.dart';
import '../widgets/realtime_validation_widget.dart';
import '../widgets/approved_suggestion_banner.dart';
import '../services/local_validation_service.dart';
import 'photo_capture_screen.dart';
import 'form_completed_screen.dart';
import 'location_disclosure_screen.dart';
import '../providers/auth_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class QuestionScreen extends StatefulWidget {
  final Questionnaire questionnaire;
  final int currentQuestionIndex;

  const QuestionScreen({
    super.key,
    required this.questionnaire,
    required this.currentQuestionIndex,
  });

  @override
  State<QuestionScreen> createState() => _QuestionScreenState();
}

class _QuestionScreenState extends State<QuestionScreen> {
  late PageController _pageController;
  final Map<int, dynamic> _currentAnswers = {};
  final Map<int, List<ValidationAlert>> _validationAlerts = {};
  int _currentVisibleIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    print('🚀 === QUESTION SCREEN INICIADO ===');
    print('📝 Número de questões: ${widget.questionnaire.questions.length}');

    // Debug das questões
    for (int i = 0; i < widget.questionnaire.questions.length; i++) {
      final question = widget.questionnaire.questions[i];
      print('📝 [$i] ID ${question.id}: "${question.questionText}"');
      if (question.hasConditionalLogic) {
        print('🔧   Lógica: ${question.conditionalLogicSummary}');
      }
    }

    // Inicializar FormProvider e AiProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFormProvider();
      _initializeAiProvider();
    });
  }

  void _initializeAiProvider() {
    try {
      final aiProvider = Provider.of<AiProvider>(context, listen: false);
      aiProvider.initForForm(questionnaireId: widget.questionnaire.id);
      // Busca em paralelo — falhas são silenciosas
      aiProvider.loadApprovedSuggestions();
      aiProvider.loadFollowUpTips();
    } catch (e) {
      print('⚠️ Erro ao inicializar AiProvider: $e');
    }
  }

  /// Dispara verificação de inconsistências e follow-ups após alteração de resposta
  void _onResponseChanged(int questionId, dynamic value, String questionType, FormProvider formProvider) {
    // Salvar resposta no FormProvider
    formProvider.setResponse(questionId, value, questionType);

    // Validação local em tempo real (funciona offline)
    _runLocalValidation(questionId, value, questionType);

    // Disparar verificações via backend (com debounce)
    final aiProvider = Provider.of<AiProvider>(context, listen: false);
    if (aiProvider.isAiAvailable) {
      final responsesMap = <String, dynamic>{};
      formProvider.responses.forEach((key, val) {
        responsesMap[key.toString()] = val;
      });

      // Inconsistências (debounce 2s)
      aiProvider.checkInconsistenciesDebounced(responses: responsesMap);

      // Follow-ups: sugestões de perguntas complementares (debounce 3s)
      final strValue = value?.toString() ?? '';
      if (strValue.trim().isNotEmpty) {
        aiProvider.loadFollowUpDebounced(
          questionId: questionId,
          responseValue: strValue,
          allResponses: responsesMap,
        );
      }
    }
  }

  /// Executa validação local em tempo real para a resposta atual
  void _runLocalValidation(int questionId, dynamic value, String questionType) {
    // Encontrar o texto da pergunta
    String questionText = '';
    for (final q in widget.questionnaire.questions) {
      if (q.id == questionId) {
        questionText = q.questionText;
        break;
      }
    }

    final alerts = LocalValidationService.validate(
      questionText: questionText,
      questionType: questionType,
      value: value,
    );

    setState(() {
      if (alerts.isEmpty) {
        _validationAlerts.remove(questionId);
      } else {
        _validationAlerts[questionId] = alerts;
      }
    });
  }

  void _initializeFormProvider() {
    print('📄 === INICIALIZANDO FORM PROVIDER ===');

    try {
      final formProvider = Provider.of<FormProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // VERIFICAR SE ESTÁ EM MODO DE EDIÇÃO
      if (formProvider.isEditMode) {
        print('✏️ MODO DE EDIÇÃO DETECTADO - Mantendo respostas existentes');
        print('📝 Respostas carregadas: ${formProvider.responses.length}');
        print('📝 Formulário atual: ${formProvider.currentForm}');

        // Verificar se já existe um formulário atual
        if (formProvider.currentForm == null) {
          // Se não existe, criar um novo formulário para edição
          print('📝 Criando formulário de edição...');
          formProvider.startForm(
            widget.questionnaire.id,
            authProvider.user!.id,
            widget.questionnaire.questions,
          );
        } else {
          // Se já existe, apenas inicializar as questões
          print('📝 Formulário já existe, inicializando questões...');
          formProvider.initialize(widget.questionnaire.questions);
        }

        // Executar lógica condicional com as respostas já carregadas
        formProvider.debugConditionalLogic();

        setState(() {
          _isInitialized = true;
        });

        print('✅ Modo de edição inicializado com ${formProvider.responses.length} respostas');
        return;
      }

      // Se NÃO está em modo de edição, limpar e criar novo formulário
      print('📝 MODO NOVO FORMULÁRIO - Limpando dados anteriores');
      formProvider.clearForm();

      print('🚀 Iniciando formulário com ID do questionário: ${widget.questionnaire.id}');
      print('👤 ID do usuário: ${authProvider.user!.id}');
      print('📝 Questões: ${widget.questionnaire.questions.length}');

      formProvider.startForm(
        widget.questionnaire.id,
        authProvider.user!.id,
        widget.questionnaire.questions,
      );

      // Verificar se inicialização foi bem-sucedida
      if (formProvider.currentForm != null && formProvider.questions.isNotEmpty) {
        print('✅ FormProvider inicializado com sucesso');
        print('   - Formulário ativo: SIM');
        print('   - Questões carregadas: ${formProvider.questions.length}');
        print('   - Questionário ID: ${formProvider.currentForm!.questionnaireId}');
        print('   - Aplicado por: ${formProvider.currentForm!.appliedBy}');

        // Debug inicial da lógica condicional
        formProvider.debugConditionalLogic();

        setState(() {
          _isInitialized = true;
        });

        print('✅ Inicialização completa');
      } else {
        print('❌ Falha na inicialização:');
        print('   - Formulário ativo: ${formProvider.currentForm != null}');
        print('   - Questões: ${formProvider.questions.length}');
        
        // Tentar método de fallback
        print('🔄 Tentando método de fallback...');
        formProvider.initialize(widget.questionnaire.questions);
        
        if (formProvider.questions.isNotEmpty) {
          print('⚠️ Fallback parcial funcionou, mas sem formulário ativo');
          setState(() {
            _isInitialized = true;
          });
        }
      }
    } catch (e, stackTrace) {
      print('❌ Erro na inicialização: $e');
      print('📋 Stack trace: $stackTrace');
      
      // Em caso de erro, tentar ainda o método compatível
      try {
        print('🆘 Tentando recuperação com método compatível...');
        final formProvider = Provider.of<FormProvider>(context, listen: false);
        formProvider.initialize(widget.questionnaire.questions);
        
        if (formProvider.questions.isNotEmpty) {
          print('🔧 Recuperação parcial bem-sucedida');
          setState(() {
            _isInitialized = true;
          });
        }
      } catch (recoveryError) {
        print('💥 Falha total na recuperação: $recoveryError');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FormProvider>(
      builder: (context, formProvider, child) {
        // Aguardar inicialização
        if (!_isInitialized) {
          return _buildLoadingScreen();
        }

        // Verificar se há questões
        if (formProvider.questions.isEmpty) {
          return _buildErrorScreen('Nenhuma questão encontrada');
        }

        // Obter questões visíveis
        final visibleQuestions = <Question>[];
        for (int i = 0; i < formProvider.questions.length; i++) {
          if (formProvider.isQuestionVisible(i)) {
            visibleQuestions.add(formProvider.questions[i]);
          }
        }

        print(
          '👁️ Questões visíveis: ${visibleQuestions.length} de ${formProvider.questions.length}',
        );

        // Se não há questões visíveis
        if (visibleQuestions.isEmpty) {
          return _buildNoVisibleQuestionsScreen(formProvider);
        }

        // Verificar índice atual
        if (_currentVisibleIndex >= visibleQuestions.length) {
          _currentVisibleIndex = 0;
        }

        return Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: visibleQuestions.length,
                    onPageChanged: (index) {
                      // Bloquear swipe para frente se pergunta obrigatória não respondida
                      if (index > _currentVisibleIndex) {
                        final currentQuestion = visibleQuestions[_currentVisibleIndex];
                        final currentOriginalIndex = _getOriginalIndex(
                          currentQuestion, formProvider,
                        );
                        final questionState = formProvider.getQuestionState(currentOriginalIndex);
                        final isRequired = questionState?.required ?? currentQuestion.isRequired;

                        if (isRequired) {
                          final response = formProvider.getResponse(currentQuestion.id);
                          if (response == null || response.toString().trim().isEmpty) {
                            // Voltar para a pergunta atual
                            _pageController.jumpToPage(_currentVisibleIndex);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Responda esta questão obrigatória antes de avançar'),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                        }
                      }

                      setState(() {
                        _currentVisibleIndex = index;
                      });
                    },
                    itemBuilder: (context, index) {
                      final question = visibleQuestions[index];
                      final originalIndex = _getOriginalIndex(
                        question,
                        formProvider,
                      );

                      return _buildQuestionPage(
                        question,
                        index,
                        originalIndex,
                        visibleQuestions.length,
                        formProvider,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Carregando questionário...'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 64),
                    const SizedBox(height: 16),
                    Text(message, style: const TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoVisibleQuestionsScreen(FormProvider formProvider) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.visibility_off,
                      color: Colors.orange,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text('Nenhuma questão visível'),
                    const SizedBox(height: 8),
                    const Text(
                      'Baseado nas respostas, não há questões disponíveis.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            print('🔍 === DEBUG COMPLETO ===');
                            formProvider.debugConditionalLogic();
                          },
                          child: const Text('Debug'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            print('🧪 === TESTE GERAL ===');
                            formProvider.testConditionalLogic();
                          },
                          child: const Text('Teste'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            print('🧪 === TESTE JSON ESPECÍFICO ===');
                            formProvider.testSpecificJSON();
                          },
                          child: const Text('JSON'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: const BoxDecoration(color: Color.fromRGBO(35, 52, 95, 1.0)),
    child: Row(
      children: [
        // Espaço vazio à esquerda
        const Expanded(child: SizedBox()),
        
        // Imagem centralizada
        Image.asset(
          'assets/images/Logo_verde2.png',
          width: 120,
          fit: BoxFit.contain,
        ),
        
        // Espaço à direita com indicador de IA
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: const AiStatusIndicator(compact: true),
          ),
        ),
      ],
    ),
  );
}

  int _getOriginalIndex(Question question, FormProvider formProvider) {
    for (int i = 0; i < formProvider.questions.length; i++) {
      if (formProvider.questions[i].id == question.id) {
        return i;
      }
    }
    return -1;
  }

  Widget _buildQuestionPage(
    Question question,
    int visibleIndex,
    int originalIndex,
    int totalVisible,
    FormProvider formProvider,
  ) {
    if (originalIndex < 0) {
      return const Center(child: Text('Erro: questão não encontrada'));
    }

    final questionState = formProvider.getQuestionState(originalIndex);
    final isRequired = questionState?.required ?? question.isRequired;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progresso
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8fae5d),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Pergunta ${visibleIndex + 1} de $totalVisible',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Texto da questão + botão de dicas de follow-up
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          question.questionText,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Color(0xFF23345F),
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Consumer<AiProvider>(
                        builder: (context, aiProvider, _) {
                          final tips =
                              aiProvider.getFollowUpTips(question.id);
                          final hasTips = tips != null && tips.isNotEmpty;
                          return Tooltip(
                            message: 'Dicas para esta pergunta',
                            child: InkWell(
                              onTap: () => _showFollowUpTipsModal(
                                context,
                                question.questionText,
                                tips ?? [],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.help_outline,
                                  size: 22,
                                  color: hasTips
                                      ? Colors.purple.shade400
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Obrigatório
                  if (isRequired)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Text(
                        '* Campo obrigatório',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Debug da questão
               /*   Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ID: ${question.id}, Índice: $originalIndex → $visibleIndex',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Text(
                          'Estado: visible=${questionState?.visible}, required=${questionState?.required}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green.shade700,
                          ),
                        ),
                        if (question.hasConditionalLogic)
                          Text(
                            'Lógica: ${question.conditionalLogicSummary}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.purple.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10), */

                  // Widget da questão
                  QuestionWidget(
                    question: question,
                    initialValue: formProvider.getResponse(question.id),
                    onChanged: (value) {
                      print('📝 === RESPOSTA ALTERADA ===');
                      print('📝 Questão ${question.id}: "$value"');

                      setState(() {
                        _currentAnswers[question.id] = value;
                      });

                      // Salvar resposta e disparar verificações de IA
                      _onResponseChanged(
                        question.id,
                        value,
                        question.questionType,
                        formProvider,
                      );
                    },
                  ),

                  // === VALIDAÇÃO EM TEMPO REAL (local, funciona offline) ===
                  if (_validationAlerts.containsKey(question.id))
                    RealtimeValidationWidget(
                      alerts: _validationAlerts[question.id]!,
                    ),

                  // === SUGESTÃO APROVADA PELO PAINEL ===
                  Consumer<AiProvider>(
                    builder: (context, aiProvider, _) {
                      final approved =
                          aiProvider.getApprovedSuggestion(question.id);
                      if (approved == null) return const SizedBox.shrink();
                      return ApprovedSuggestionBanner(
                        suggestion: approved,
                        onApply: () {
                          final value =
                              aiProvider.applyApprovedSuggestion(question.id);
                          if (value != null) {
                            setState(() {
                              _currentAnswers[question.id] = value;
                            });
                            _onResponseChanged(
                              question.id,
                              value,
                              question.questionType,
                              formProvider,
                            );
                          }
                        },
                        onIgnore: () =>
                            aiProvider.ignoreApprovedSuggestion(question.id),
                      );
                    },
                  ),

                  // === WIDGETS DE IA (backend) ===
                  _buildAiWidgets(question, formProvider),
                ],
              ),
            ),
          ),
          _buildNavigationButtons(
            visibleIndex,
            totalVisible,
            originalIndex,
            formProvider,
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(
    int visibleIndex,
    int totalVisible,
    int originalIndex,
    FormProvider formProvider,
  ) {
    final isFirstQuestion = visibleIndex == 0;
    final isLastQuestion = visibleIndex == totalVisible - 1;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        children: [
          if (!isFirstQuestion)
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: Colors.grey),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Anterior',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            ),

          if (!isFirstQuestion) const SizedBox(width: 10),

          Expanded(
            flex: isFirstQuestion ? 1 : 2,
            child: ElevatedButton(
              onPressed: () => _handleNext(
                visibleIndex,
                totalVisible,
                originalIndex,
                isLastQuestion,
                formProvider,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8fae5d),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
              child: Text(
                isLastQuestion
                    ? (formProvider.isEditMode ? 'Atualizar' : 'Finalizar')
                    : 'Próxima',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNext(
    int visibleIndex,
    int totalVisible,
    int originalIndex,
    bool isLastQuestion,
    FormProvider formProvider,
  ) async {
    if (originalIndex < 0) return;

    final currentQuestion = formProvider.questions[originalIndex];
    final questionState = formProvider.getQuestionState(originalIndex);
    final isRequired = questionState?.required ?? currentQuestion.isRequired;

    print('🚀 Tentativa de avanço: questão $originalIndex');

    // Verificar obrigatoriedade
    if (isRequired) {
      final response = formProvider.getResponse(currentQuestion.id);
      if (response == null || response.toString().trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, responda esta questão obrigatória'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (isLastQuestion) {
      // Validação final
      final validation = formProvider.validateAllResponses();
      if (!validation.isValid) {
        final errors = validation.errors.take(3).join('\n');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erros:\n$errors'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        return;
      }

      // Verificação final de inconsistências e padronização (IA)
      await _runFinalAiChecks(formProvider);

      // Finalizar formulário
      if (widget.questionnaire.requiresPhoto) {
        // Para questionários com foto, navegar para captura de foto
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                PhotoCaptureScreen(questionnaire: widget.questionnaire),
          ),
        );
      } else {
        // Sem foto: capturar a localização (se exigida) antes de submeter.
        // A captura via PhotoCaptureScreen não acontece aqui, então fazemos aqui.
        await _captureLocationIfRequired(formProvider);
        // Para questionários sem foto, submeter e navegar
        await _submitAndNavigate(formProvider);
      }
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  /// Executa verificações finais de IA antes de submeter
  Future<void> _runFinalAiChecks(FormProvider formProvider) async {
    final aiProvider = Provider.of<AiProvider>(context, listen: false);
    if (!aiProvider.isAiAvailable) return;

    try {
      final responsesMap = <String, dynamic>{};
      formProvider.responses.forEach((key, val) {
        responsesMap[key.toString()] = val;
      });

      // Solicitar padronização
      final stdResult = await aiProvider.standardizeResponses(
        responses: responsesMap,
      );

      // Se há sugestões de padronização, mostrar diálogo resumido
      if (stdResult.hasSuggestions && mounted) {
        final accepted = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sugestões de padronização'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${stdResult.suggestions.length} campo(s) podem ser padronizados.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: stdResult.suggestions.length,
                      itemBuilder: (_, i) {
                        final s = stdResult.suggestions[i];
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${s.originalValue} → ${s.suggestedValue}',
                            style: const TextStyle(fontSize: 13),
                          ),
                          subtitle: Text(s.standardizationType,
                              style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Manter originais'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Aceitar todas'),
              ),
            ],
          ),
        );

        if (accepted == true) {
          for (final s in stdResult.suggestions) {
            formProvider.setResponse(s.questionId, s.suggestedValue, 'text');
            aiProvider.acceptStandardization(s.questionId);
          }
        }
      }
    } catch (e) {
      // IA não deve bloquear a submissão
      print('⚠️ Erro nas verificações finais de IA: $e');
    }
  }

  /// Captura a localização GPS quando o questionário exige (requiresLocation),
  /// mas o fluxo não passa pela PhotoCaptureScreen (que já captura por conta própria).
  /// Sem isso, questionários com "Capturar Localização" ligado e "Requer Foto"
  /// desligado nunca registravam as coordenadas.
  Future<void> _captureLocationIfRequired(FormProvider formProvider) async {
    if (!widget.questionnaire.requiresLocation) return;

    // Já capturada (ex.: edição com localização preservada)? Não recapturar.
    if (formProvider.currentForm?.latitude != null) {
      print('📍 Localização já definida, mantendo a existente');
      return;
    }

    try {
      var status = await Permission.location.status;

      // Sem permissão ainda: mostrar disclosure (exigido pelo Google Play) e solicitar.
      if (!status.isGranted) {
        if (!mounted) return;
        final granted = await LocationDisclosureHelper
            .showDisclosureAndRequestPermission(context);
        if (!granted) {
          print('📍 Permissão de localização não concedida — seguindo sem coordenadas');
          return;
        }
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('📍 Serviço de localização desativado — seguindo sem coordenadas');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      print('📍 Localização obtida: ${position.latitude}, ${position.longitude}');
      formProvider.setLocation(position.latitude, position.longitude, '');
    } catch (e) {
      // Falha na captura não deve bloquear a submissão do formulário.
      print('❌ Erro ao capturar localização: $e');
    }
  }

  Future<void> _submitAndNavigate(FormProvider formProvider) async {
  print('📤 === SUBMETENDO FORMULÁRIO SEM FOTO ===');
  print('✏️ Modo de edição: ${formProvider.isEditMode}');
  print('✏️ ID do formulário em edição: ${formProvider.editingFormId}');

  // Verificar se há formulário ou respostas para submeter
  final hasResponses = formProvider.responses.isNotEmpty;
  final hasForm = formProvider.currentForm != null;

  print('📊 Status antes da submissão:');
  print('   - Formulário ativo: $hasForm');
  print('   - ID do formulário: ${formProvider.currentForm?.id}');
  print('   - Respostas coletadas: ${formProvider.responses.length}');
  print('   - Questões processadas: ${formProvider.questions.length}');

  if (!hasResponses && !hasForm) {
    print('⚠️ Nenhum dado para submeter, navegando direto');
    _navigateToCompletedScreen();
    return;
  }

  // Mostrar loading
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Text(formProvider.isEditMode ? 'Atualizando respostas...' : 'Salvando respostas...'),
        ],
      ),
      backgroundColor: const Color(0xFF8fae5d),
      duration: const Duration(seconds: 10),
    ),
  );

  try {
    bool success = false;

    // SEMPRE submeter diretamente, SEM criar novo formulário
    print('📤 Submetendo formulário existente (ID: ${formProvider.currentForm?.id})...');
    success = await formProvider.submitForm();

    // Remover snackbar de loading
    ScaffoldMessenger.of(context).clearSnackBars();

    if (success) {
      print('✅ Formulário submetido com sucesso');
      _navigateToCompletedScreen();
    } else {
      print('❌ Falha ao submeter formulário');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(formProvider.isEditMode
            ? 'Erro ao atualizar formulário. Tente novamente.'
            : 'Erro ao salvar formulário. Tente novamente.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    print('❌ Erro durante submissão: $e');
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erro inesperado: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  void _navigateToCompletedScreen() {
    // Se está em modo de edição, apenas voltar para a tela anterior
    // indicando que a edição foi bem-sucedida
    final formProvider = Provider.of<FormProvider>(context, listen: false);
    if (formProvider.isEditMode) {
      print('✅ Modo de edição - voltando para tela anterior com sucesso');
      Navigator.pop(context, true); // Retorna true indicando sucesso
      return;
    }

    // Se não está em modo de edição, navegar para a tela de conclusão
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => FormCompletedScreen(
          questionnaire: widget.questionnaire,
        ),
      ),
    );
  }

  void _navigateToFormCompleted() async {
    print('🚀 === NAVEGANDO PARA TELA DE CONCLUSÃO ===');

    try {
      final formProvider = Provider.of<FormProvider>(context, listen: false);

      // CAPTURAR TODOS OS DADOS ANTES DA NAVEGAÇÃO
      final currentForm = formProvider.currentForm;

      if (currentForm == null) {
        print('❌ Nenhum formulário ativo para navegar');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: Nenhum formulário ativo encontrado'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Preservar dados ANTES de qualquer submissão ou limpeza
      final preservedData = {
        'questionnaireId': currentForm.questionnaireId,
        'appliedBy': currentForm.appliedBy,
        'consentGiven': currentForm.consentGiven,
        'responses': Map<int, dynamic>.from(formProvider.responses),
        'latitude': currentForm.latitude,
        'longitude': currentForm.longitude,
        'locationName': currentForm.locationName,
        'photoPath': currentForm.photoPath,
        'startedAt': currentForm.startedAt,
        'completedAt': DateTime.now(),
      };

      print('📋 Dados preservados para navegação:');
      print('   - Questionário ID: ${preservedData['questionnaireId']}');
      print('   - Respostas: ${(preservedData['responses'] as Map).length}');
      print('   - Foto: ${preservedData['photoPath']}');

      // Navegar passando os dados preservados
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => FormCompletedScreen(
            questionnaire:
                widget.questionnaire, // ou como você acessa o questionário
            preservedQuestionnaireId: preservedData['questionnaireId'] as int,
            preservedAppliedBy: preservedData['appliedBy'] as int,
            preservedConsentGiven: preservedData['consentGiven'] as bool,
            preservedResponses: preservedData['responses'] as Map<int, dynamic>,
            preservedLatitude: preservedData['latitude'] as double?,
            preservedLongitude: preservedData['longitude'] as double?,
            preservedLocationName: preservedData['locationName'] as String?,
            preservedPhotoPath: preservedData['photoPath'] as String?,
            preservedStartedAt: preservedData['startedAt'] as DateTime,
            preservedCompletedAt: preservedData['completedAt'] as DateTime,
          ),
        ),
      );
    } catch (e, stackTrace) {
      print('❌ Erro na navegação: $e');
      print('📋 Stack trace: $stackTrace');

      // Navegação de fallback sem dados preservados
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              FormCompletedScreen(questionnaire: widget.questionnaire),
        ),
      );
    }
  }

  /// Constrói os widgets de IA para a pergunta atual
  Widget _buildAiWidgets(Question question, FormProvider formProvider) {
    return Consumer<AiProvider>(
      builder: (context, aiProvider, _) {
        if (!aiProvider.isAiAvailable) return const SizedBox.shrink();

        // No modo demo, injetar dados para a pergunta atual
        if (aiProvider.isDemoMode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            aiProvider.loadDemoDataForQuestion(question.id);
          });
        }

        final questionType = question.questionType.toLowerCase();
        final isTextType = questionType == 'text' || questionType == 'textarea';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Transcrição de voz (apenas para campos de texto)
            if (isTextType) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final authProvider =
                      Provider.of<AuthProvider>(context, listen: false);
                  return VoiceTranscriptionWidget(
                questionId: question.id,
                questionnaireId: widget.questionnaire.id,
                questionText: question.questionText,
                applicatorName: authProvider.user?.fullName,
                applicatorId: authProvider.user?.id,
                currentValue: formProvider.getResponse(question.id)?.toString(),
                onTranscriptionAccepted: (text) {
                  formProvider.setResponse(
                    question.id,
                    text,
                    question.questionType,
                  );
                  setState(() {
                    _currentAnswers[question.id] = text;
                  });
                },
              );
                },
              ),
            ],

            // 2. Alertas de inconsistência
            Builder(
              builder: (context) {
                final alerts = aiProvider.getAlertsForQuestion(question.id);
                if (alerts.isEmpty) return const SizedBox.shrink();

                return InconsistencyAlertWidget(
                  alerts: alerts,
                  onCorrect: () {
                    aiProvider.resolveInconsistency(
                      question.id,
                      InconsistencyAction.corrected,
                    );
                  },
                  onKeep: () {
                    aiProvider.resolveInconsistency(
                      question.id,
                      InconsistencyAction.kept,
                    );
                  },
                  onReviewLater: () {
                    aiProvider.resolveInconsistency(
                      question.id,
                      InconsistencyAction.reviewLater,
                    );
                  },
                );
              },
            ),

            // 3. Sugestão de padronização
            Builder(
              builder: (context) {
                final std =
                    aiProvider.getStandardizationForQuestion(question.id);
                if (std == null) return const SizedBox.shrink();

                return StandardizationSuggestionWidget(
                  suggestion: std,
                  onAccept: () {
                    aiProvider.acceptStandardization(question.id);
                    // Aplicar valor padronizado
                    formProvider.setResponse(
                      question.id,
                      std.suggestedValue,
                      question.questionType,
                    );
                    setState(() {
                      _currentAnswers[question.id] = std.suggestedValue;
                    });
                  },
                  onReject: () {
                    aiProvider.rejectStandardization(question.id);
                  },
                );
              },
            ),

            // 4. Sugestão inteligente de preenchimento
            Builder(
              builder: (context) {
                final suggestion =
                    aiProvider.smartFieldsResult.getSuggestionForQuestion(question.id);
                if (suggestion == null || suggestion.applied) {
                  return const SizedBox.shrink();
                }

                return SmartSuggestionWidget(
                  suggestion: suggestion,
                  onApply: () {
                    aiProvider.applySmartSuggestion(question.id);
                    formProvider.setResponse(
                      question.id,
                      suggestion.suggestedValue,
                      question.questionType,
                    );
                    setState(() {
                      _currentAnswers[question.id] = suggestion.suggestedValue;
                    });
                  },
                  onIgnore: () {
                    aiProvider.ignoreSmartSuggestion(question.id);
                  },
                );
              },
            ),

            // 5. Sugestões de follow-up
            Builder(
              builder: (context) {
                if (!aiProvider.followUpResult.hasSuggestions) {
                  return const SizedBox.shrink();
                }

                return FollowUpSuggestionWidget(
                  suggestions: aiProvider.followUpResult.suggestions,
                  onApply: (index) {
                    aiProvider.applyFollowUp(index);
                  },
                  onIgnore: (index) {
                    aiProvider.ignoreFollowUp(index);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _showFollowUpTipsModal(
    BuildContext context,
    String questionText,
    List<String> tips,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.purple.shade400, size: 22),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Sugestões de Follow-up',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF23345F),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Pergunta de referência
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      questionText,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Lista de dicas
                  Expanded(
                    child: tips.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline,
                                    size: 48,
                                    color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text(
                                  'Nenhuma dica configurada para esta pergunta.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'O administrador pode adicionar dicas no painel.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                      controller: scrollController,
                      itemCount: tips.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: Colors.purple.shade100),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${i + 1}.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  tips[i],
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: Color(0xFF23345F),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Limpar contexto de IA ao sair da tela
    try {
      Provider.of<AiProvider>(context, listen: false).clearFormContext();
    } catch (_) {}
    super.dispose();
  }
}
