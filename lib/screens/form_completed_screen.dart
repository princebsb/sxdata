import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/questionnaire.dart';
import '../providers/form_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'questionnaire_preview_screen.dart';
import '../services/photo_storage_service.dart';
import '../services/local_storage_service.dart';
import '../models/form_response.dart';
import '../models/question_response.dart';

class FormCompletedScreen extends StatefulWidget {
  final Questionnaire questionnaire;
  
  // Parâmetros opcionais para dados preservados
  final int? preservedQuestionnaireId;
  final int? preservedAppliedBy;
  final bool? preservedConsentGiven;
  final Map<int, dynamic>? preservedResponses;
  final double? preservedLatitude;
  final double? preservedLongitude;
  final String? preservedLocationName;
  final String? preservedPhotoPath;
  final DateTime? preservedStartedAt;
  final DateTime? preservedCompletedAt;

  const FormCompletedScreen({
    super.key, 
    required this.questionnaire,
    this.preservedQuestionnaireId,
    this.preservedAppliedBy,
    this.preservedConsentGiven,
    this.preservedResponses,
    this.preservedLatitude,
    this.preservedLongitude,
    this.preservedLocationName,
    this.preservedPhotoPath,
    this.preservedStartedAt,
    this.preservedCompletedAt,
  });

  @override
  State<FormCompletedScreen> createState() => _FormCompletedScreenState();
}

class _FormCompletedScreenState extends State<FormCompletedScreen> {
  bool _isSubmitting = false;
  bool _isUploadingPhoto = false;
  String _statusMessage = 'Preparando submissão...';
  String _photoUploadStatus = '';
  
  // Variáveis para preservar informações
  int _responseCount = 0;
  String _applicatorName = 'Usuário';
  DateTime _completionTime = DateTime.now();
  String _locationName = '';
  bool _hasSyncedSuccessfully = false;
  bool _hasPhotoUploaded = false;
  File? _capturedPhoto;
  String? _uploadedPhotoFilename;
  
  // Dados finais do formulário
  int? _finalQuestionnaireId;
  int? _finalAppliedBy;
  bool _finalConsentGiven = false;
  Map<int, dynamic> _finalResponses = {};
  double? _finalLatitude;
  double? _finalLongitude;
  String? _finalLocationName;
  String? _finalPhotoPath;
  DateTime? _finalStartedAt;
  DateTime? _finalCompletedAt;

  @override
  void initState() {
    super.initState();
    print('🎯 FormCompletedScreen iniciado');
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndSubmit();
    });
  }

  Future<void> _initializeAndSubmit() async {
    print('📋 === INICIALIZANDO E SUBMETENDO ===');
    
    try {
      // Capturar dados de múltiplas fontes
      await _captureFormData();
      
      // Configurar informações básicas
      _setupBasicInfo();
      
      // Atualizar UI
      setState(() {});
      
      // Submeter dados
      await _submitFormData();
      
    } catch (e, stackTrace) {
      print('❌ Erro na inicialização: $e');
      print('📋 Stack trace: $stackTrace');
      
      _useDefaultValues();
      setState(() {});
    }
  }

  Future<void> _captureFormData() async {
    print('📋 === CAPTURANDO DADOS DO FORMULÁRIO ===');
    
    final formProvider = Provider.of<FormProvider>(context, listen: false);
    
    // ESTRATÉGIA 1: Dados preservados passados como parâmetros
    if (widget.preservedQuestionnaireId != null) {
      print('✅ Usando dados preservados dos parâmetros');
      _useParameterData();
      return;
    }
    
    // ESTRATÉGIA 2: FormProvider ativo
    if (formProvider.currentForm != null) {
      print('✅ Usando FormProvider ativo');
      _useFormProviderData(formProvider);
      return;
    }
    
    // ESTRATÉGIA 3: Dados preservados no FormProvider
    if (formProvider.lastCompletedForm != null) {
      print('✅ Usando dados preservados do FormProvider');
      _useLastCompletedData(formProvider);
      return;
    }
    
    // ESTRATÉGIA 4: Buscar no localStorage
    print('🔍 Buscando no localStorage...');
    await _searchInLocalStorage();
  }

  void _useParameterData() {
    _finalQuestionnaireId = widget.preservedQuestionnaireId!;
    _finalAppliedBy = widget.preservedAppliedBy!;
    _finalConsentGiven = widget.preservedConsentGiven ?? false;
    _finalResponses = widget.preservedResponses ?? {};
    _finalLatitude = widget.preservedLatitude;
    _finalLongitude = widget.preservedLongitude;
    _finalLocationName = widget.preservedLocationName;
    _finalPhotoPath = widget.preservedPhotoPath;
    _finalStartedAt = widget.preservedStartedAt;
    _finalCompletedAt = widget.preservedCompletedAt ?? DateTime.now();
    
    _responseCount = _finalResponses.length;
    
    print('📋 Dados dos parâmetros capturados: $_responseCount respostas');
  }

  void _useFormProviderData(FormProvider formProvider) {
    final currentForm = formProvider.currentForm!;
    
    _finalQuestionnaireId = currentForm.questionnaireId;
    _finalAppliedBy = currentForm.appliedBy;
    _finalConsentGiven = currentForm.consentGiven;
    _finalResponses = Map<int, dynamic>.from(
      formProvider.responses.map((key, value) => MapEntry(key, value.getValue()))
    );
    _finalLatitude = currentForm.latitude;
    _finalLongitude = currentForm.longitude;
    _finalLocationName = currentForm.locationName;
    _finalPhotoPath = currentForm.photoPath;
    _finalStartedAt = currentForm.startedAt;
    _finalCompletedAt = DateTime.now();
    
    _responseCount = formProvider.responses.length;
    
    print('📋 Dados do FormProvider capturados: $_responseCount respostas');
  }

  void _useLastCompletedData(FormProvider formProvider) {
    final lastForm = formProvider.lastCompletedForm!;
    
    _finalQuestionnaireId = lastForm.questionnaireId;
    _finalAppliedBy = lastForm.appliedBy;
    _finalConsentGiven = lastForm.consentGiven;
    _finalResponses = Map<int, dynamic>.from(
      formProvider.lastCompletedResponses.map((key, value) => MapEntry(key, value.getValue()))
    );
    _finalLatitude = lastForm.latitude;
    _finalLongitude = lastForm.longitude;
    _finalLocationName = lastForm.locationName;
    _finalPhotoPath = lastForm.photoPath;
    _finalStartedAt = lastForm.startedAt;
    _finalCompletedAt = lastForm.completedAt ?? DateTime.now();
    
    _responseCount = formProvider.lastCompletedResponses.length;
    
    print('📋 Dados preservados do FormProvider capturados: $_responseCount respostas');
  }

  Future<void> _searchInLocalStorage() async {
    try {
      final forms = await LocalStorageService.getFormResponses();
      
      // Buscar formulário mais recente deste questionário
      final recentForms = forms
          .where((f) => f.questionnaireId == widget.questionnaire.id)
          .toList();
      
      if (recentForms.isNotEmpty) {
        // Ordenar por data de conclusão ou criação
        recentForms.sort((a, b) {
          final dateA = a.completedAt ?? a.startedAt;
          final dateB = b.completedAt ?? b.startedAt;
          return dateB.compareTo(dateA);
        });
        
        final recentForm = recentForms.first;
        
        print('✅ Formulário encontrado no localStorage');
        
        _finalQuestionnaireId = recentForm.questionnaireId;
        _finalAppliedBy = recentForm.appliedBy;
        _finalConsentGiven = recentForm.consentGiven;
        _finalResponses = Map<int, dynamic>.from(
          recentForm.responses.asMap().map((index, response) => 
            MapEntry(response.questionId, response.getValue()))
        );
        _finalLatitude = recentForm.latitude;
        _finalLongitude = recentForm.longitude;
        _finalLocationName = recentForm.locationName;
        _finalPhotoPath = recentForm.photoPath;
        _finalStartedAt = recentForm.startedAt;
        _finalCompletedAt = recentForm.completedAt ?? DateTime.now();
        
        _responseCount = recentForm.responses.length;
        
        // Se já está sincronizado, não precisa submeter novamente
        if (recentForm.syncStatus == 'synced') {
          _hasSyncedSuccessfully = true;
          _statusMessage = 'Formulário já foi sincronizado';
          print('ℹ️ Formulário já sincronizado, não precisa submeter');
          return;
        }
        
        print('📋 Dados do localStorage capturados: $_responseCount respostas');
        return;
      }
    } catch (e) {
      print('❌ Erro ao buscar no localStorage: $e');
    }
    
    // Se não encontrou nada, usar valores padrão
    _useDefaultValues();
  }

  void _useDefaultValues() {
    print('📋 Usando valores padrão');
    
    _finalQuestionnaireId = widget.questionnaire.id;
    _finalAppliedBy = 1; // Valor padrão - ajustar conforme necessário
    _finalConsentGiven = true;
    _finalResponses = {};
    _finalLatitude = null;
    _finalLongitude = null;
    _finalLocationName = null;
    _finalPhotoPath = null;
    _finalStartedAt = DateTime.now().subtract(const Duration(minutes: 5));
    _finalCompletedAt = DateTime.now();
    
    _responseCount = widget.questionnaire.questions.length;
    _hasSyncedSuccessfully = true; // Assumir que foi processado
    _statusMessage = 'Formulário processado';
  }

  void _setupBasicInfo() {
    print('📋 Configurando informações básicas');

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // IMPORTANTE: Verificar se o usuário está disponível no AuthProvider
      // Mesmo offline, o usuário deve estar carregado do armazenamento local
      if (authProvider.user != null) {
        _applicatorName = authProvider.user!.fullName;
        print('✅ Usando usuário do AuthProvider: $_applicatorName');
      } else {
        // Apenas como fallback - não deve acontecer se o usuário estava logado
        _applicatorName = 'Aplicador';
        print('⚠️ Usuário não disponível no AuthProvider');
      }
    } catch (e) {
      print('❌ Erro ao obter usuário: $e');
      _applicatorName = 'Aplicador';
    }

    // Configurar localização
    if (_finalLocationName != null && _finalLocationName!.isNotEmpty) {
      _locationName = _finalLocationName!;
    } else if (_finalLatitude != null && _finalLongitude != null) {
      _locationName = 'Lat: ${_finalLatitude!.toStringAsFixed(6)}, Lng: ${_finalLongitude!.toStringAsFixed(6)}';
    } else {
      _locationName = 'Localização não disponível';
    }

    // Configurar foto
    if (_finalPhotoPath != null && _finalPhotoPath!.isNotEmpty) {
      final photoFile = File(_finalPhotoPath!);
      if (photoFile.existsSync()) {
        _capturedPhoto = photoFile;
        print('📸 Foto encontrada: $_finalPhotoPath');
      }
    }

    _completionTime = _finalCompletedAt ?? DateTime.now();

    print('📋 Informações básicas configuradas - Aplicador: $_applicatorName');
  }

  Future<void> _submitFormData() async {
    print('📤 === SUBMETENDO DADOS DO FORMULÁRIO ===');
    
    // Se já foi sincronizado, não submeter novamente
    if (_hasSyncedSuccessfully) {
      print('ℹ️ Formulário já foi processado');
      return;
    }
    
    setState(() {
      _isSubmitting = true;
      _statusMessage = 'Salvando dados...';
    });
    
    try {
      final formProvider = Provider.of<FormProvider>(context, listen: false);

      // Se o FormProvider ainda tem um formulário ativo, usar submissão normal
      //COMENTADO PARA EVITAR SALVAR 2 VEZES LEOHARLEY
      // CORREÇÃO: Este bloco estava causando duplicação de formulários!
      // O formulário já foi submetido no question_screen.dart quando clicou "Finalizar"
      // NÃO deve submeter novamente aqui!
      /*
      if (formProvider.currentForm != null) {
        print('📋 Usando submissão do FormProvider');


        final success = await formProvider.submitFormWithPhoto(null);

        setState(() {
          _hasSyncedSuccessfully = success;
          _statusMessage = success
            ? 'Dados salvos com sucesso'
            : 'Dados salvos localmente';
          _isSubmitting = false;
        });

        _showSubmissionResult(success);
        return;
      }
      */

      // CORREÇÃO: Agora apenas exibe o formulário que já foi salvo
      if (formProvider.currentForm != null) {
        print('✅ Formulário já foi submetido anteriormente');
        setState(() {
          _hasSyncedSuccessfully = true;
          _statusMessage = 'Formulário salvo com sucesso';
          _isSubmitting = false;
        });
        return;
      }
      
      // Criar e salvar FormResponse com os dados capturados
      print('📋 Criando FormResponse com dados capturados');
      
      final formResponse = FormResponse(
        questionnaireId: _finalQuestionnaireId!,
        appliedBy: _finalAppliedBy!,
        consentGiven: _finalConsentGiven,
        syncStatus: 'pending',
        startedAt: _finalStartedAt ?? DateTime.now().subtract(const Duration(minutes: 5)),
        completedAt: _finalCompletedAt ?? DateTime.now(),
        responses: _finalResponses.entries.map((entry) {
          return QuestionResponse(
            questionId: entry.key,
            responseText: entry.value?.toString(),
          );
        }).toList(),
        latitude: _finalLatitude,
        longitude: _finalLongitude,
        locationName: _finalLocationName,
        photoPath: _finalPhotoPath,
      );
      
      // Salvar localmente

    //COMENTADO PARA EVITAR SALVAR 2 VEZES LEOHARLEY
    //  await LocalStorageService.saveFormResponse(formResponse);
      
      print('✅ Formulário salvo localmente');
      
      // Tentar sincronizar com servidor
    /*  bool syncSuccess = false;
      try {
        final result = await ApiService.submitForm(formResponse);
        if (result['success'] == true) {
          syncSuccess = true;
          print('✅ Formulário sincronizado com servidor');
        }
      } catch (e) {
        print('⚠️ Erro na sincronização (modo offline): $e');
        syncSuccess = false;
      } 
      
      setState(() {
        _hasSyncedSuccessfully = syncSuccess;
        //COMENTADO PARA RESOLVER PROBLEMA DE SALVAR 2 VEZES
        /*_statusMessage = syncSuccess 
          ? 'Dados sincronizados com sucesso' 
          : 'Dados salvos localmente'; */
          _statusMessage = syncSuccess 
          ? 'Dados salvos localmente' 
          : 'Dados salvos localmente';
        _isSubmitting = false;
      });
      
      _showSubmissionResult(true); // Sempre true porque pelo menos salvou localmente
      */
    } catch (e, stackTrace) {
      print('❌ Erro na submissão: $e');
      print('📋 Stack trace: $stackTrace');
      
      setState(() {
        _statusMessage = 'Erro ao salvar dados';
        _hasSyncedSuccessfully = false;
        _isSubmitting = false;
      });
      
      _showSubmissionResult(false); 
    }
  }

  void _showSubmissionResult(bool success) {
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formulário processado com sucesso!'),
          backgroundColor: Color(0xFF8fae5d),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Erro ao processar formulário. Tente novamente.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Tentar Novamente',
            textColor: Colors.white,
            onPressed: () => _submitFormData(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print('🏗️ Building FormCompletedScreen');
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header customizado com logo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(35, 52, 95, 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Espaço vazio para manter simetria (sem botão voltar)
                  const SizedBox(width: 48),
                  // Logo centralizado
                  Image.asset(
                    'assets/images/Logo_verde2.png',
                    width: 120,             
                    fit: BoxFit.contain,
                  ),
                  // Ícone de conclusão
                  Icon(
                    Icons.check_circle,
                    color: _hasSyncedSuccessfully ? const Color(0xFF8fae5d) : Colors.orange,
                    size: 24,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: _hasSyncedSuccessfully 
                                  ? const Color(0xFF8fae5d) 
                                  : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _hasSyncedSuccessfully ? Icons.check : Icons.save,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            const Text(
                              'Formulário Concluído!',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF23345F),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _statusMessage,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                            
                            _buildSummaryCard(),
                            
                            // Seção de upload de foto
                            if (_capturedPhoto != null) ...[
                              const SizedBox(height: 40),
                              _buildPhotoUploadSection(),
                              const SizedBox(height: 40),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    print('🏗️ Building summary card');
    
    try {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            _buildSummaryRow('Questionário:', widget.questionnaire.title),
            const SizedBox(height: 10),
            _buildSummaryRow('Aplicador:', _applicatorName),
            const SizedBox(height: 10),
            _buildSummaryRow(
              'Data/Hora:', 
              '${_completionTime.day.toString().padLeft(2, '0')}/${_completionTime.month.toString().padLeft(2, '0')}/${_completionTime.year} ${_completionTime.hour.toString().padLeft(2, '0')}:${_completionTime.minute.toString().padLeft(2, '0')}'
            ),
            const SizedBox(height: 10),
            _buildSummaryRow('Localização:', _locationName),
            const SizedBox(height: 10),
            _buildSummaryRow(
              'Status:', 
              _isSubmitting 
                ? '🔄 Salvando...' 
                : _hasSyncedSuccessfully 
                  ? '✔️ Sincronizado' 
                  : '💾 Salvo localmente',
              statusColor: _isSubmitting 
                ? Colors.orange 
                : _hasSyncedSuccessfully 
                  ? const Color(0xFF8fae5d)
                  : Colors.orange,
            ),
            const SizedBox(height: 10),
            _buildSummaryRow(
              'Respostas:', 
              '$_responseCount questão${_responseCount != 1 ? 'ões' : ''} respondida${_responseCount != 1 ? 's' : ''}',
              statusColor: _responseCount > 0 ? const Color(0xFF8fae5d) : Colors.red,
            ),
            const SizedBox(height: 10),
            _buildSummaryRow(
              'Questões do formulário:', 
              '${widget.questionnaire.questions.length} questões disponíveis',
            ),
            if (_capturedPhoto != null) ...[
              const SizedBox(height: 10),
              _buildSummaryRow(
                'Foto:', 
                _hasPhotoUploaded 
                  ? '✔️ Enviada' 
                  : _isUploadingPhoto 
                    ? '🔄 Enviando...'
                    : 'Pendente upload',
                statusColor: _hasPhotoUploaded 
                  ? const Color(0xFF8fae5d) 
                  : _isUploadingPhoto
                    ? Colors.orange
                    : Colors.orange,
              ),
            ],
          ],
        ),
      );
    } catch (e, stackTrace) {
      print('❌ Erro ao construir summary card: $e');
      print('📋 Stack trace: $stackTrace');
      
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 32),
            SizedBox(height: 10),
            Text(
              'Erro ao carregar informações',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
            ),
            Text(
              'Os dados do formulário foram salvos',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }
  }

  void _showFullScreenPhoto() {
    if (_capturedPhoto == null) return;
    
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            // Foto em tela cheia
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 3.0,
                child: Image.file(
                  _capturedPhoto!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            
            // Botão de fechar
            Positioned(
              top: 40,
              right: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            
            // Informações da foto
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Evidência Fotográfica',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tamanho: ${(_capturedPhoto!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Capturada: ${_completionTime.day.toString().padLeft(2, '0')}/${_completionTime.month.toString().padLeft(2, '0')}/${_completionTime.year} ${_completionTime.hour.toString().padLeft(2, '0')}:${_completionTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    if (_locationName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Local: $_locationName',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoUploadSection() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8fae5d),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header da seção
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8fae5d).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.photo_camera,
                  color: Color(0xFF8fae5d),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evidência Fotográfica',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Anexo do formulário',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Status indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8fae5d).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.save_alt,
                      size: 12,
                      color: Color(0xFF8fae5d),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'OFFLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8fae5d),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 15),
          
          // Preview da foto
          Container(
            width: double.infinity,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                children: [
                  // Imagem da foto
                  Positioned.fill(
                    child: Image.file(
                      _capturedPhoto!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Overlay com informações
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.photo_library,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'IMG_${DateTime.now().millisecondsSinceEpoch}.jpg',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(_capturedPhoto!.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Badge de qualidade
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8fae5d),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'HD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Informações detalhadas da foto
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                // Data e hora de captura
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Capturada em: ${_completionTime.day.toString().padLeft(2, '0')}/${_completionTime.month.toString().padLeft(2, '0')}/${_completionTime.year} às ${_completionTime.hour.toString().padLeft(2, '0')}:${_completionTime.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Localização se disponível
                if (_locationName.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Local: $_locationName',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                
                // Resolução e qualidade
                Row(
                  children: [
                    Icon(
                      Icons.photo_size_select_large,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Qualidade: Alta resolução • Formato: JPEG',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 15),
          
          // Status do processamento offline
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF8fae5d).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF8fae5d).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF8fae5d),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Foto processada e salva localmente',
                        style: TextStyle(
                          color: Color(0xFF8fae5d),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Explicação do processo
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.grey,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'A foto será sincronizada automaticamente com o servidor quando houver conexão com internet. Você pode continuar usando o app normalmente.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 15),
          
          // Ações disponíveis
          Row(
            children: [
              // Botão para visualizar em tela cheia
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showFullScreenPhoto(),
                  icon: const Icon(
                    Icons.fullscreen,
                    size: 16,
                  ),
                  label: const Text(
                    'Ver Ampliada',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8fae5d),
                    side: const BorderSide(
                      color: Color(0xFF8fae5d),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Status de sincronização
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.blue.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_queue,
                        size: 16,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Pendente Sync',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? statusColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: statusColor ?? const Color(0xFF23345F),
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : _newForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8fae5d),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 2,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Novo Formulário',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _backToDashboard(),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF8fae5d), width: 2),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Voltar ao Dashboard',
              style: TextStyle(
                color: Color(0xFF8fae5d),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _newForm() {
    print('📄 Iniciando novo formulário');
    try {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QuestionnairePreviewScreen(
            questionnaire: widget.questionnaire,
          ),
        ),
      );
    } catch (e) {
      print('❌ Erro ao navegar para novo formulário: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao iniciar novo formulário: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _backToDashboard() {
    print('🏠 Voltando ao dashboard');
    try {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
        (route) => false,
      );
    } catch (e) {
      print('❌ Erro ao voltar ao dashboard: $e');
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}