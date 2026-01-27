import 'package:flutter/foundation.dart';
import '../models/questionnaire.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';

class QuestionnaireProvider with ChangeNotifier {
  List<Questionnaire> _questionnaires = [];
  bool _isLoading = false;
  String? _error;

  List<Questionnaire> get questionnaires => _questionnaires;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadQuestionnaires() async {
    print('🔄 Starting to load questionnaires...');
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🌐 Attempting to load from server...');
      
      // Try to load from server first
      final serverData = await ApiService.getQuestionnaires();

      print('📡 Server response received:');
      print('📡 Success: ${serverData['success']}');
      print('📡 Data type: ${serverData['data'].runtimeType}');
      
      if (serverData['data'] is List) {
        final dataList = serverData['data'] as List;
        print('📡 Data length: ${dataList.length}');
        
        if (dataList.isNotEmpty) {
          print('📡 First item keys: ${(dataList.first as Map).keys.toList()}');
          print('📡 First item title: ${dataList.first['title']}');
          
          // Verificar se há questões no primeiro item
          if (dataList.first['questions'] != null) {
            final questions = dataList.first['questions'] as List;
            print('📡 First questionnaire has ${questions.length} questions');
            if (questions.isNotEmpty) {
              print('📡 First question: ${questions.first}');
            }
          }
        }
      }
      
      if (serverData['success'] == true) {
        print('✅ Server request successful');
        
        final dataList = serverData['data'] as List?;
        if (dataList != null && dataList.isNotEmpty) {
          print('🔄 Converting ${dataList.length} questionnaires...');
          
          _questionnaires = [];
          
          for (int i = 0; i < dataList.length; i++) {
            try {
              final rawData = dataList[i] as Map<String, dynamic>;
              print('🔄 Converting questionnaire $i: ${rawData['title']}');
              print('📋 Raw questionnaire data: $rawData');
              
              final questionnaire = Questionnaire.fromJson(rawData);
              _questionnaires.add(questionnaire);
              
              print('✅ Questionnaire $i converted successfully:');
              print('   - Title: ${questionnaire.title}');
              print('   - Questions: ${questionnaire.questions.length}');
              
              // Log das questões
              for (int j = 0; j < questionnaire.questions.length; j++) {
                final q = questionnaire.questions[j];
                print('   - Question $j: ${q.questionText} (type: ${q.questionType}, options: ${q.options.length})');
              }
              
            } catch (conversionError, stackTrace) {
              print('❌ Error converting questionnaire $i: $conversionError');
              print('📋 Raw data: ${dataList[i]}');
              print('📋 Stack trace: $stackTrace');
              // Continue com os outros questionários mesmo se um falhar
            }
          }
          
          print('✅ Successfully converted ${_questionnaires.length} questionnaires');
          print('📊 Final questionnaires list:');
          for (int i = 0; i < _questionnaires.length; i++) {
            print('   $i: ${_questionnaires[i].title} (${_questionnaires[i].questions.length} questions)');
          }
          
          // Save to local storage
          try {
            await LocalStorageService.saveQuestionnaires(_questionnaires);
            print('💾 Questionnaires saved to local storage');
          } catch (storageError) {
            print('⚠️ Failed to save to local storage: $storageError');
          }
        } else {
          print('⚠️ Server data is null or empty');
          throw Exception('Server returned null or empty data');
        }
      } else {
        print('❌ Server request failed: ${serverData['message'] ?? 'Unknown error'}');
        throw Exception(serverData['message'] ?? 'Failed to load from server');
      }
    } catch (e, stackTrace) {
      print('❌ Error loading from server: $e');
      print('📋 Stack trace: $stackTrace');
      print('🔄 Attempting to load from local storage...');
      
      // Fallback to local storage
      try {
        _questionnaires = await LocalStorageService.getQuestionnaires();
        print('💾 Loaded ${_questionnaires.length} questionnaires from local storage');
        
        if (_questionnaires.isEmpty) {
          _error = 'Não foi possível carregar os questionários';
          print('⚠️ No questionnaires found in local storage either');
        }
      } catch (localError) {
        print('❌ Failed to load from local storage: $localError');
        _error = 'Não foi possível carregar os questionários';
        _questionnaires = [];
      }
    } finally {
      _isLoading = false;
      
      print('🏁 Load questionnaires finished');
      print('📊 Final state: ${_questionnaires.length} questionnaires, error: $_error');
      
      // Log final detalhado
      if (_questionnaires.isNotEmpty) {
        print('📋 Final questionnaires summary:');
        for (int i = 0; i < _questionnaires.length; i++) {
          final q = _questionnaires[i];
          print('   $i: ${q.title}');
          print('      - ID: ${q.id}');
          print('      - Questions: ${q.questions.length}');
          print('      - Requires photo: ${q.requiresPhoto}');
          print('      - Status: ${q.status}');
          
          for (int j = 0; j < q.questions.length; j++) {
            final question = q.questions[j];
            print('      - Q$j: ${question.questionText} (${question.questionType})');
          }
        }
      } else {
        print('📋 No questionnaires in final state');
      }
      
      notifyListeners();
    }
  }

  Questionnaire? getQuestionnaireById(int id) {
    try {
      final questionnaire = _questionnaires.firstWhere((q) => q.id == id);
      print('✅ Found questionnaire: ${questionnaire.title} with ${questionnaire.questions.length} questions');
      return questionnaire;
    } catch (e) {
      print('❌ Questionnaire with id $id not found');
      print('📋 Available questionnaires: ${_questionnaires.map((q) => '${q.id}: ${q.title}').toList()}');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadQuestionnaires();
  }
}