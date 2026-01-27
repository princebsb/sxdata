import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class QuestionAnalysisProvider with ChangeNotifier {
  List<QuestionnaireAnalysis> _questionnaires = [];
  QuestionnaireDetail? _selectedQuestionnaireDetail;
  bool _isLoading = false;
  bool _isLoadingDetail = false;
  String? _error;
  int? _selectedQuestionnaireId;

  List<QuestionnaireAnalysis> get questionnaires => _questionnaires;
  QuestionnaireDetail? get selectedQuestionnaireDetail => _selectedQuestionnaireDetail;
  bool get isLoading => _isLoading;
  bool get isLoadingDetail => _isLoadingDetail;
  String? get error => _error;
  int? get selectedQuestionnaireId => _selectedQuestionnaireId;

  /// Carregar lista de questionários com estatísticas básicas
  Future<void> loadQuestionnaires([AnalysisFilters? filters]) async {
    print('📊 Carregando questionários para análise via API');
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // CHAMADA API REAL:
      final response = await ApiService.getQuestionnaireAnalysisList(filters?.toApiMap());
      
      if (response['success'] == true && response['data'] != null) {
        _questionnaires = (response['data'] as List).map((item) => 
          QuestionnaireAnalysis.fromJson(item)
        ).toList();
        _error = null;
        print('✅ ${_questionnaires.length} questionários carregados via API');
      } else {
        _error = response['message'] ?? 'Erro ao carregar questionários';
        print('❌ Erro na resposta da API: $_error');
      }

    } catch (e, stackTrace) {
      _error = 'Erro de conexão: $e';
      print('❌ Erro ao carregar questionários via API: $e');
      print('🔍 Stack trace: $stackTrace');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Carregar análise detalhada de um questionário
  Future<void> loadQuestionnaireDetail(int questionnaireId, {
    AnalysisFilters? filters,
  }) async {
    print('🔍 Carregando análise detalhada do questionário $questionnaireId via API');
    
    _isLoadingDetail = true;
    _selectedQuestionnaireId = questionnaireId;
    _error = null;
    notifyListeners();

    try {
      // CHAMADA API REAL:
      final response = await ApiService.getQuestionnaireDetailAnalysis(
        questionnaireId,
        filters?.toApiMap(),
      );

      print('🔍 DEBUG - Response completa: $response');

      if (response['success'] == true && response['data'] != null) {
        print('🔍 DEBUG - Dados da API: ${response['data']}');
        
        _selectedQuestionnaireDetail = QuestionnaireDetail.fromJson(response['data']);
        _error = null;
        
        print('✅ Análise detalhada carregada com sucesso via API');
        print('🔍 DEBUG - QuestionnaireDetail criado:');
        print('   - ID: ${_selectedQuestionnaireDetail!.id}');
        print('   - Título: ${_selectedQuestionnaireDetail!.title}');
        print('   - Total Questões: ${_selectedQuestionnaireDetail!.totalQuestions}');
        print('   - Total Respostas: ${_selectedQuestionnaireDetail!.totalResponses}');
        print('   - Tempo Médio: ${_selectedQuestionnaireDetail!.avgCompletionTime}');
        print('   - Número de Questões: ${_selectedQuestionnaireDetail!.questions.length}');
        
        // Verificar se os dados das questões estão corretos
        for (int i = 0; i < _selectedQuestionnaireDetail!.questions.length; i++) {
          final q = _selectedQuestionnaireDetail!.questions[i];
          print('   - Questão $i: ID=${q.id}, Type=${q.type}, Responses=${q.totalResponses}, Rate=${q.responseRate}%, Data=${q.data.length} items');
          
          // Mostrar alguns dados da questão
          for (int j = 0; j < q.data.length && j < 3; j++) {
            final d = q.data[j];
            print('     - Data $j: "${d.label}" = ${d.count} (${d.percentage}%)');
          }
        }
      } else {
        _error = response['message'] ?? 'Erro ao carregar análise detalhada';
        print('❌ Erro na resposta da API: $_error');
      }

    } catch (e, stackTrace) {
      _error = 'Erro de conexão: $e';
      print('❌ Erro ao carregar análise via API: $e');
      print('🔍 Stack trace: $stackTrace');
    } finally {
      _isLoadingDetail = false;
      notifyListeners();
    }
  }

  /// Carregar lista de aplicadores para filtros
  Future<List<User>> loadApplicators() async {
    try {
      print('👥 Carregando lista de aplicadores via API');
      
      final response = await ApiService.getApplicators();
      
      if (response['success'] == true && response['data'] != null) {
        final applicators = (response['data'] as List).map((item) => 
          User.fromJson(item)
        ).toList();
        
        print('✅ ${applicators.length} aplicadores carregados via API');
        return applicators;
      } else {
        print('❌ Erro ao carregar aplicadores: ${response['message']}');
        return [];
      }
    } catch (e) {
      print('❌ Erro ao carregar aplicadores via API: $e');
      return [];
    }
  }

  /// Limpar seleção de questionário
  void clearSelection() {
    _selectedQuestionnaireDetail = null;
    _selectedQuestionnaireId = null;
    _isLoadingDetail = false;
    notifyListeners();
  }

  /// Limpar todos os dados
  void clearData() {
    _questionnaires = [];
    _selectedQuestionnaireDetail = null;
    _selectedQuestionnaireId = null;
    _error = null;
    _isLoading = false;
    _isLoadingDetail = false;
    notifyListeners();
  }

  /// Debug: imprimir estado atual
  void debugPrintCurrentState() {
    print('🔍 Estado atual do QuestionAnalysisProvider:');
    print('   - Carregando lista: $_isLoading');
    print('   - Carregando detalhe: $_isLoadingDetail');
    print('   - Erro: $_error');
    print('   - Questionários: ${_questionnaires.length}');
    print('   - Questionário selecionado: $_selectedQuestionnaireId');
    print('   - Tem detalhes: ${_selectedQuestionnaireDetail != null}');
  }
}

// Função auxiliar para converter valores para int de forma segura
int _parseToInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) {
    try {
      return int.parse(value);
    } catch (e) {
      print('⚠️ Erro ao converter "$value" para int: $e');
      return 0;
    }
  }
  if (value is double) return value.toInt();
  return 0;
}

// Função auxiliar para converter valores para double de forma segura
double _parseToDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    try {
      return double.parse(value);
    } catch (e) {
      print('⚠️ Erro ao converter "$value" para double: $e');
      return 0.0;
    }
  }
  return 0.0;
}

// Função auxiliar para verificar se uma string é uma data válida
bool _isValidDate(String? dateStr) {
  if (dateStr == null || dateStr.isEmpty) return false;
  try {
    DateTime.parse(dateStr);
    return true;
  } catch (e) {
    return false;
  }
}

// Modelos de dados
class QuestionnaireAnalysis {
  final int id;
  final String title;
  final String description;
  final int totalQuestions;
  final int totalResponses;
  final double responseRate;
  final DateTime? lastResponse;

  QuestionnaireAnalysis({
    required this.id,
    required this.title,
    required this.description,
    required this.totalQuestions,
    required this.totalResponses,
    required this.responseRate,
    this.lastResponse,
  });

  factory QuestionnaireAnalysis.fromJson(Map<String, dynamic> json) {
    return QuestionnaireAnalysis(
      id: _parseToInt(json['id']),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      totalQuestions: _parseToInt(json['total_questions']),
      totalResponses: _parseToInt(json['total_responses']),
      responseRate: _parseToDouble(json['response_rate']),
      lastResponse: json['last_response'] != null 
          ? DateTime.tryParse(json['last_response'].toString()) 
          : null,
    );
  }
}

class QuestionnaireDetail {
  final int id;
  final String title;
  final String description;
  final int totalQuestions;
  final int totalResponses;
  final double avgCompletionTime;
  final List<QuestionAnalysis> questions;

  QuestionnaireDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.totalQuestions,
    required this.totalResponses,
    required this.avgCompletionTime,
    required this.questions,
  });

  factory QuestionnaireDetail.fromJson(Map<String, dynamic> json) {
    // A API retorna dados em uma estrutura específica
    final questionnaire = json['questionnaire'] ?? json;
    final summary = json['summary'] ?? {};
    final questionsList = json['questions'] ?? [];
    
    print('🔍 DEBUG QuestionnaireDetail.fromJson:');
    print('   - questionnaire keys: ${questionnaire.keys.toList()}');
    print('   - summary keys: ${summary.keys.toList()}');
    print('   - summary content: $summary');
    print('   - questionsList length: ${questionsList.length}');
    
    final totalQuestions = _parseToInt(summary['total_questions']) != 0 
        ? _parseToInt(summary['total_questions']) 
        : questionsList.length;
    final totalResponses = _parseToInt(summary['total_responses']);
    final avgTime = _parseToDouble(summary['avg_time']);
    
    print('   - Parsed values:');
    print('     - totalQuestions: $totalQuestions (from summary: ${summary['total_questions']})');
    print('     - totalResponses: $totalResponses (from summary: ${summary['total_responses']})');
    print('     - avgTime: $avgTime (from summary: ${summary['avg_time']})');
    
    final questions = (questionsList as List<dynamic>)
        .map((q) => QuestionAnalysis.fromJson(q))
        .toList();
    
    print('   - Questions parsed: ${questions.length}');
    
    // Se totalResponses for 0, tentar calcular baseado nas questões
    int calculatedTotalResponses = totalResponses;
    if (calculatedTotalResponses == 0 && questions.isNotEmpty) {
      calculatedTotalResponses = questions
          .map((q) => q.totalResponses)
          .reduce((a, b) => a > b ? a : b); // Pegar o maior valor
      print('   - Calculated totalResponses from questions: $calculatedTotalResponses');
    }
    
    final result = QuestionnaireDetail(
      id: _parseToInt(questionnaire['id']),
      title: questionnaire['title']?.toString() ?? '',
      description: questionnaire['description']?.toString() ?? '',
      totalQuestions: totalQuestions,
      totalResponses: calculatedTotalResponses,
      avgCompletionTime: avgTime,
      questions: questions,
    );
    
    print('   - Final QuestionnaireDetail:');
    print('     - id: ${result.id}');
    print('     - title: ${result.title}');
    print('     - totalQuestions: ${result.totalQuestions}');
    print('     - totalResponses: ${result.totalResponses}');
    print('     - avgCompletionTime: ${result.avgCompletionTime}');
    print('     - questions count: ${result.questions.length}');
    
    return result;
  }
}

class QuestionAnalysis {
  final int id;
  final String text;
  final String type;
  final int totalResponses;
  final double responseRate;
  final List<AnalysisData> data;

  QuestionAnalysis({
    required this.id,
    required this.text,
    required this.type,
    required this.totalResponses,
    required this.responseRate,
    required this.data,
  });

  factory QuestionAnalysis.fromJson(Map<String, dynamic> json) {
    final statistics = json['statistics'] ?? {};
    final statisticsData = statistics['data'] as List<dynamic>? ?? [];
    
    final totalResponses = _parseToInt(statistics['total_responses']);
    double responseRate = _parseToDouble(statistics['response_rate']);
    
    print('🔍 DEBUG QuestionAnalysis - ID: ${json['id']}, Type: ${json['question_type']}');
    print('   - Text: ${json['question_text']}');
    print('   - TotalResponses from API: $totalResponses');
    print('   - ResponseRate from API: $responseRate');
    print('   - StatisticsData length: ${statisticsData.length}');
    
    // Se responseRate está como 0, tentar calcular baseado nos dados
    if (responseRate == 0.0 && statisticsData.isNotEmpty && totalResponses > 0) {
      print('   - Calculando responseRate baseado nos dados...');
      
      // Para questões de texto, procurar "Respostas Preenchidas"
      for (var data in statisticsData) {
        print('     - Data item: ${data['label']} = ${data['count']} (${data['percentage']}%)');
        
        if ((data['label']?.toString().toLowerCase().contains('preenchidas') == true ||
             data['label']?.toString().toLowerCase().contains('filled') == true) && 
            data['percentage'] != null) {
          responseRate = _parseToDouble(data['percentage']);
          print('     - Found responseRate from "Preenchidas": $responseRate%');
          break;
        }
      }
      
      // Se ainda for 0, calcular manualmente
      if (responseRate == 0.0) {
        int validResponses = 0;
        int emptyResponses = 0;
        
        for (var data in statisticsData) {
          String label = data['label']?.toString().toLowerCase() ?? '';
          if (label.contains('vazias') || label.contains('empty')) {
            emptyResponses += _parseToInt(data['count']);
          } else if (label.contains('preenchidas') || label.contains('filled') || 
                     data['option_text'] != null) {
            validResponses += _parseToInt(data['count']);
          }
        }
        
        if (validResponses > 0) {
          responseRate = (validResponses / totalResponses) * 100;
          print('     - Calculated responseRate manually: $validResponses/$totalResponses = $responseRate%');
        }
      }
    }
    
    print('   - Final ResponseRate: $responseRate%');
    
    return QuestionAnalysis(
      id: _parseToInt(json['id']),
      text: json['question_text']?.toString() ?? json['text']?.toString() ?? '',
      type: json['question_type']?.toString() ?? json['type']?.toString() ?? '',
      totalResponses: totalResponses,
      responseRate: responseRate,
      data: statisticsData.map((d) => AnalysisData.fromJson(d)).toList(),
    );
  }
}

class AnalysisData {
  final String label;
  final int count;
  final double? percentage;
  final String? unit;
  final bool isDate;
  final String? dateValue;

  AnalysisData({
    required this.label,
    required this.count,
    this.percentage,
    this.unit,
    this.isDate = false,
    this.dateValue,
  });

  factory AnalysisData.fromJson(Map<String, dynamic> json) {
    // Determinar o label baseado na estrutura dos dados
    String label = '';
    
    // Para questões de radio/checkbox (com option_text)
    if (json['option_text'] != null) {
      label = json['option_text'].toString();
    } 
    // Para outros tipos de dados (com label)
    else if (json['label'] != null) {
      label = json['label'].toString();
    }
    // Fallback para option_value se existir
    else if (json['option_value'] != null) {
      label = json['option_value'].toString();
    }
    
    // Determinar se é uma data
    String countStr = json['count']?.toString() ?? '';
    bool isDate = json['is_date'] == true || 
                  json['is_date'] == 'true' || 
                  _isValidDate(countStr);
    
    // Processar count e dateValue
    String? dateValue;
    int count = 0;
    
    if (isDate && _isValidDate(countStr)) {
      // Para dados de data, o count é a data em si
      dateValue = countStr;
      count = 0; // Não é um count numérico
    } else {
      // Para dados normais, processar o count como número
      count = _parseToInt(json['count']);
      dateValue = json['date_value']?.toString();
    }
    
    // Processar percentage
    double? percentage;
    if (json['percentage'] != null) {
      percentage = _parseToDouble(json['percentage']);
    }
    
    print('🔍 DEBUG AnalysisData: Label="$label", Count=$count, Percentage=$percentage, IsDate=$isDate');
    
    return AnalysisData(
      label: label,
      count: count,
      percentage: percentage,
      unit: json['unit']?.toString(),
      isDate: isDate,
      dateValue: dateValue,
    );
  }
}

// Classe para filtros
class AnalysisFilters {
  PeriodType periodType;
  DateTime? dateFrom;
  DateTime? dateTo;
  int? questionnaireId;
  int? appliedBy;
  List<String> questionTypes;
  int minResponses;
  double minResponseRate;

  AnalysisFilters({
    this.periodType = PeriodType.lastMonth,
    this.dateFrom,
    this.dateTo,
    this.questionnaireId,
    this.appliedBy,
    List<String>? questionTypes,
    this.minResponses = 0,
    this.minResponseRate = 0.0,
  }) : questionTypes = questionTypes ?? [] {
    _updateDatesByPeriod();
  }

  void _updateDatesByPeriod() {
    final now = DateTime.now();
    switch (periodType) {
      case PeriodType.lastWeek:
        dateFrom = now.subtract(const Duration(days: 7));
        dateTo = now;
        break;
      case PeriodType.lastMonth:
        dateFrom = DateTime(now.year, now.month - 1, now.day);
        dateTo = now;
        break;
      case PeriodType.last3Months:
        dateFrom = DateTime(now.year, now.month - 3, now.day);
        dateTo = now;
        break;
      case PeriodType.lastYear:
        dateFrom = DateTime(now.year - 1, now.month, now.day);
        dateTo = now;
        break;
      case PeriodType.custom:
        // Não altera as datas, permite seleção manual
        break;
    }
  }

  AnalysisFilters copy() {
    return AnalysisFilters(
      periodType: periodType,
      dateFrom: dateFrom,
      dateTo: dateTo,
      questionnaireId: questionnaireId,
      appliedBy: appliedBy,
      questionTypes: List.from(questionTypes),
      minResponses: minResponses,
      minResponseRate: minResponseRate,
    );
  }

  Map<String, dynamic> toApiMap() {
    final map = <String, dynamic>{};
    
    if (dateFrom != null) {
      map['date_from'] = dateFrom!.toIso8601String().split('T')[0];
    }
    if (dateTo != null) {
      map['date_to'] = dateTo!.toIso8601String().split('T')[0];
    }
    if (questionnaireId != null) {
      map['questionnaire_id'] = questionnaireId.toString();
    }
    if (appliedBy != null) {
      map['applied_by'] = appliedBy.toString();
    }
    if (questionTypes.isNotEmpty) {
      map['question_types'] = questionTypes.join(',');
    }
    if (minResponses > 0) {
      map['min_responses'] = minResponses.toString();
    }
    if (minResponseRate > 0) {
      map['min_response_rate'] = minResponseRate.toString();
    }
    
    return map;
  }

  bool get hasActiveFilters {
    return questionnaireId != null ||
           appliedBy != null ||
           questionTypes.isNotEmpty ||
           minResponses > 0 ||
           minResponseRate > 0 ||
           periodType != PeriodType.lastMonth;
  }
}

enum PeriodType {
  lastWeek,
  lastMonth,
  last3Months,
  lastYear,
  custom,
}

// Modelo simplificado de usuário
class User {
  final int id;
  final String fullName;
  final String? role;

  User({
    required this.id,
    required this.fullName,
    this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: _parseToInt(json['id']),
      fullName: json['full_name']?.toString() ?? json['name']?.toString() ?? '',
      role: json['role']?.toString(),
    );
  }
}