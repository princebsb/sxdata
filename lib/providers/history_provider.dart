import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/api_service.dart';

class HistoryProvider with ChangeNotifier {
  List<ApplicationHistory> _applications = [];
  Map<String, int> _counters = {};
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'all';
  bool _hasMore = false;
  int _currentOffset = 0;
  final int _limit = 50;

  // Getters
  List<ApplicationHistory> get applications => _applications;
  Map<String, int> get counters => _counters;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get selectedFilter => _selectedFilter;
  bool get hasMore => _hasMore;

  /// Carregar histórico de aplicações
  Future<void> loadHistory({
    int? userId,
    String? period,
    String? syncStatus,
    bool refresh = false,
  }) async {
    print('🔄 Carregando histórico - Filter: $_selectedFilter, Period: $period, SyncStatus: $syncStatus, UserId: $userId');

    if (refresh) {
      _currentOffset = 0;
      _applications.clear();
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Determinar os parâmetros corretos baseado no filtro selecionado
      String? apiPeriod;
      String? apiSyncStatus;

      switch (_selectedFilter) {
        case 'today':
          apiPeriod = 'today';
          break;
        case 'week':
          apiPeriod = 'week';
          break;
        case 'pending':
          apiSyncStatus = 'pending';
          break;
        case 'all':
        default:
          // Para 'all', não passamos period nem syncStatus específico
          break;
      }

      print('📤 Chamando API com - Period: $apiPeriod, SyncStatus: $apiSyncStatus');

      final response = await ApiService.getApplicationHistory(
        userId: userId,
        period: apiPeriod,
        syncStatus: apiSyncStatus,
        limit: _limit,
        offset: _currentOffset,
      );

      print('📥 Resposta da API: ${response['success']}');

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];

        // Atualizar contadores
        _counters = Map<String, int>.from(data['counters'] ?? {});
        print('📊 Contadores atualizados: $_counters');

        // Processar aplicações
        final newApplications = (data['applications'] as List<dynamic>? ?? [])
            .map((app) => ApplicationHistory.fromJson(app))
            .toList();

        print('📋 ${newApplications.length} aplicações recebidas');

        if (refresh) {
          _applications = newApplications;
        } else {
          _applications.addAll(newApplications);
        }

        // Verificar se há mais dados
        final pagination = data['pagination'] ?? {};
        _hasMore = pagination['has_more'] ?? false;
        _currentOffset += newApplications.length;

        _error = null;
        print('✅ Histórico carregado: ${newApplications.length} itens, Total: ${_applications.length}');

        // Salvar histórico localmente para acesso offline
        await _saveHistoryLocally(data);
      } else {
        _error = response['message'] ?? 'Erro ao carregar histórico';
        print('❌ Erro na resposta: $_error');
      }
    } catch (e) {
      // Em caso de erro de conexão (offline), tentar carregar dados salvos
      print('⚠️ Erro ao conectar com servidor: $e');
      print('🔄 Tentando carregar histórico salvo localmente...');

      final loadedOffline = await _loadHistoryLocally();

      if (loadedOffline) {
        print('✅ Histórico offline carregado: ${_applications.length} itens');
        _error = null;
      } else {
        print('ℹ️ Nenhum histórico salvo localmente');
        _error = null;
        _applications = [];
        _counters = {};
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Alterar filtro e recarregar
  Future<void> setFilter(String filter, {int? userId}) async {
    print('🔄 Mudando filtro de $_selectedFilter para $filter');
    
    if (_selectedFilter != filter) {
      _selectedFilter = filter;
      
      // Carregar dados com o novo filtro
      await loadHistory(
        userId: userId,
        refresh: true,
      );
    }
  }

  /// Carregar mais itens (paginação)
  Future<void> loadMore({int? userId}) async {
    if (!_isLoading && _hasMore) {
      print('📄 Carregando mais itens - Offset atual: $_currentOffset');
      await loadHistory(
        userId: userId,
        refresh: false,
      );
    }
  }

  /// Limpar dados
  void clearHistory() {
    print('🧹 Limpando dados do histórico');
    _applications.clear();
    _counters.clear();
    _error = null;
    _currentOffset = 0;
    _hasMore = false;
    _selectedFilter = 'all';
    notifyListeners();
  }

  /// Filtrar aplicações por status local (para filtros rápidos)
  List<ApplicationHistory> getFilteredApplications(String filter) {
    switch (filter) {
      case 'pending':
        return _applications.where((app) => app.sync.status == 'pending').toList();
      case 'synced':
        return _applications.where((app) => app.sync.status == 'synced').toList();
      case 'error':
        return _applications.where((app) => app.sync.status == 'error').toList();
      default:
        return _applications;
    }
  }

  /// Debug: imprimir estado atual
  void debugPrintCurrentState() {
    print('🔍 Estado atual do HistoryProvider:');
    print('   - Filtro selecionado: $_selectedFilter');
    print('   - Carregando: $_isLoading');
    print('   - Erro: $_error');
    print('   - Aplicações: ${_applications.length}');
    print('   - Contadores: $_counters');
    print('   - Tem mais dados: $_hasMore');
    print('   - Offset atual: $_currentOffset');
  }

  /// Salvar histórico localmente para acesso offline
  Future<void> _saveHistoryLocally(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Salvar os dados completos como JSON
      final jsonString = jsonEncode(data);
      await prefs.setString('cached_history', jsonString);

      print('💾 Histórico salvo localmente para acesso offline');
    } catch (e) {
      print('❌ Erro ao salvar histórico localmente: $e');
    }
  }

  /// Carregar histórico salvo localmente
  Future<bool> _loadHistoryLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('cached_history');

      if (jsonString != null) {
        final data = jsonDecode(jsonString) as Map<String, dynamic>;

        // Restaurar contadores
        _counters = Map<String, int>.from(data['counters'] ?? {});

        // Restaurar aplicações
        final applications = (data['applications'] as List<dynamic>? ?? [])
            .map((app) => ApplicationHistory.fromJson(app))
            .toList();

        _applications = applications;
        _hasMore = false; // Dados offline não têm paginação
        _currentOffset = applications.length;

        print('✅ Histórico carregado do cache local: ${_applications.length} itens');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Erro ao carregar histórico local: $e');
      return false;
    }
  }
}

/// Modelo para histórico de aplicação
class ApplicationHistory {
  final int id;
  final Questionnaire questionnaire;
  final Respondent respondent;
  final Location location;
  final Timing timing;
  final SyncInfo sync;
  final AdditionalData additionalData;
  final String createdAt;

  ApplicationHistory({
    required this.id,
    required this.questionnaire,
    required this.respondent,
    required this.location,
    required this.timing,
    required this.sync,
    required this.additionalData,
    required this.createdAt,
  });

  factory ApplicationHistory.fromJson(Map<String, dynamic> json) {
    return ApplicationHistory(
      id: json['id'] ?? 0,
      questionnaire: Questionnaire.fromJson(json['questionnaire'] ?? {}),
      respondent: Respondent.fromJson(json['respondent'] ?? {}),
      location: Location.fromJson(json['location'] ?? {}),
      timing: Timing.fromJson(json['timing'] ?? {}),
      sync: SyncInfo.fromJson(json['sync'] ?? {}),
      additionalData: AdditionalData.fromJson(json['additional_data'] ?? {}),
      createdAt: json['created_at'] ?? '',
    );
  }
}

class Questionnaire {
  final int id;
  final String title;
  final String code;

  Questionnaire({
    required this.id,
    required this.title,
    required this.code,
  });

  factory Questionnaire.fromJson(Map<String, dynamic> json) {
    return Questionnaire(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      code: json['code'] ?? '',
    );
  }
}

class Respondent {
  final String? name;
  final String? email;

  Respondent({this.name, this.email});

  factory Respondent.fromJson(Map<String, dynamic> json) {
    return Respondent(
      name: json['name'],
      email: json['email'],
    );
  }
}

class Location {
  final String? name;
  final double? latitude;
  final double? longitude;
  final String fullAddress;

  Location({
    this.name,
    this.latitude,
    this.longitude,
    required this.fullAddress,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      name: json['name'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      fullAddress: json['full_address'] ?? 'Localização não informada',
    );
  }
}

class Timing {
  final String? startedAt;
  final String? completedAt;
  final int? durationMinutes;
  final String? completedAtFormatted;
  final String timeAgo;

  Timing({
    this.startedAt,
    this.completedAt,
    this.durationMinutes,
    this.completedAtFormatted,
    required this.timeAgo,
  });

  factory Timing.fromJson(Map<String, dynamic> json) {
    return Timing(
      startedAt: json['started_at'],
      completedAt: json['completed_at'],
      durationMinutes: json['duration_minutes'],
      completedAtFormatted: json['completed_at_formatted'],
      timeAgo: json['time_ago'] ?? '',
    );
  }
}

class SyncInfo {
  final String status;
  final String statusLabel;
  final String statusColor;
  final String icon;

  SyncInfo({
    required this.status,
    required this.statusLabel,
    required this.statusColor,
    required this.icon,
  });

  factory SyncInfo.fromJson(Map<String, dynamic> json) {
    return SyncInfo(
      status: json['status'] ?? 'pending',
      statusLabel: json['status_label'] ?? 'Pendente',
      statusColor: json['status_color'] ?? '#FF9800',
      icon: json['icon'] ?? 'sync',
    );
  }
}

class AdditionalData {
  final bool hasPhoto;
  final String? photoPath;
  final bool consentGiven;
  final bool hasLocation;

  AdditionalData({
    required this.hasPhoto,
    this.photoPath,
    required this.consentGiven,
    required this.hasLocation,
  });

  factory AdditionalData.fromJson(Map<String, dynamic> json) {
    return AdditionalData(
      hasPhoto: json['has_photo'] ?? false,
      photoPath: json['photo_path'],
      consentGiven: json['consent_given'] ?? false,
      hasLocation: json['has_location'] ?? false,
    );
  }
}