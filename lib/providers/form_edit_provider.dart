import 'package:flutter/foundation.dart';
import '../models/form_response.dart';
import '../models/questionnaire.dart';
import '../services/local_storage_service.dart';
import '../services/api_service.dart';

class FormEditProvider with ChangeNotifier {
  FormResponse? _currentForm;
  Questionnaire? _questionnaire;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  FormResponse? get currentForm => _currentForm;
  Questionnaire? get questionnaire => _questionnaire;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  /// Carregar formulário para edição
  Future<bool> loadFormForEdit(int formId, Questionnaire questionnaire) async {
    print('📝 === CARREGANDO FORMULÁRIO PARA EDIÇÃO ===');
    print('📋 Form ID: $formId');

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Carregar formulário do storage local
      final form = await LocalStorageService.getFormResponseById(formId);

      if (form == null) {
        _error = 'Formulário não encontrado';
        print('❌ Formulário não encontrado');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentForm = form;
      _questionnaire = questionnaire;

      print('✅ Formulário carregado com sucesso');
      print('📋 Respostas: ${form.responses.length}');

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _error = 'Erro ao carregar formulário: $e';
      print('❌ Erro ao carregar formulário: $e');
      print('📋 Stack trace: $stackTrace');

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Salvar alterações do formulário
  Future<bool> saveFormChanges(FormResponse updatedForm) async {
    print('💾 === SALVANDO ALTERAÇÕES DO FORMULÁRIO ===');
    print('📋 Form ID: ${updatedForm.id}');

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      // Marcar como editado e com status pendente para ressincronizar
      final formToSave = updatedForm.copyWith(
        editedAt: DateTime.now(),
        syncStatus: 'pending',
      );

      // Salvar no storage local
      await LocalStorageService.updateFormResponse(formToSave);

      _currentForm = formToSave;

      print('✅ Formulário salvo com sucesso no storage local');
      print('📋 Status: ${formToSave.syncStatus}');
      print('📋 Editado em: ${formToSave.editedAt}');

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e, stackTrace) {
      _error = 'Erro ao salvar formulário: $e';
      print('❌ Erro ao salvar formulário: $e');
      print('📋 Stack trace: $stackTrace');

      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Sincronizar formulário editado com o servidor
  Future<bool> syncEditedForm(FormResponse form) async {
    print('🔄 === SINCRONIZANDO FORMULÁRIO EDITADO ===');
    print('📋 Form ID: ${form.id}');

    _isSaving = true;
    _error = null;
    notifyListeners();

    try {
      // Enviar para API
      final response = await ApiService.submitForm(form);

      if (response['success'] == true) {
        print('✅ Formulário sincronizado com sucesso');

        // Atualizar status para 'synced'
        final syncedForm = form.copyWith(syncStatus: 'synced');
        await LocalStorageService.updateFormResponse(syncedForm);

        _currentForm = syncedForm;

        _isSaving = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Erro ao sincronizar formulário';
        print('❌ Erro na sincronização: $_error');

        // Atualizar status para 'error'
        final errorForm = form.copyWith(syncStatus: 'error');
        await LocalStorageService.updateFormResponse(errorForm);

        _isSaving = false;
        notifyListeners();
        return false;
      }
    } catch (e, stackTrace) {
      _error = 'Erro de conexão ao sincronizar: $e';
      print('❌ Erro ao sincronizar: $e');
      print('📋 Stack trace: $stackTrace');

      // Manter como 'pending' para tentar novamente
      try {
        final pendingForm = form.copyWith(syncStatus: 'pending');
        await LocalStorageService.updateFormResponse(pendingForm);
      } catch (e) {
        print('❌ Erro ao atualizar status: $e');
      }

      _isSaving = false;
      notifyListeners();
      return false;
    }
  }

  /// Salvar e sincronizar em uma operação
  Future<bool> saveAndSync(FormResponse updatedForm) async {
    print('💾🔄 === SALVANDO E SINCRONIZANDO FORMULÁRIO ===');

    // Primeiro salvar localmente
    final saved = await saveFormChanges(updatedForm);
    if (!saved) {
      return false;
    }

    // Depois tentar sincronizar
    return await syncEditedForm(_currentForm!);
  }

  /// Limpar dados do provider
  void clear() {
    _currentForm = null;
    _questionnaire = null;
    _error = null;
    _isLoading = false;
    _isSaving = false;
    notifyListeners();
  }

  /// Debug: imprimir estado atual
  void debugPrintCurrentState() {
    print('🔍 Estado atual do FormEditProvider:');
    print('   - Formulário carregado: ${_currentForm != null}');
    print('   - Questionário: ${_questionnaire?.title}');
    print('   - Carregando: $_isLoading');
    print('   - Salvando: $_isSaving');
    print('   - Erro: $_error');
    if (_currentForm != null) {
      print('   - Form ID: ${_currentForm!.id}');
      print('   - Status: ${_currentForm!.syncStatus}');
      print('   - Respostas: ${_currentForm!.responses.length}');
      print('   - Editado em: ${_currentForm!.editedAt}');
    }
  }
}
