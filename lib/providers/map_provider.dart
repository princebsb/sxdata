import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class MapProvider with ChangeNotifier {
  List<MapLocationData> _locationData = [];
  List<ApplicatorStats> _applicatorsStats = [];
  LocationCoverage? _coverage;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;

  List<MapLocationData> get locationData => _locationData;
  List<ApplicatorStats> get applicatorsStats => _applicatorsStats;
  LocationCoverage? get coverage => _coverage;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;

  /// Carregar dados do mapa
  Future<void> loadMapData({
    required String period,
    required String filter,
  }) async {
    print('🗺️ Carregando dados do mapa - Período: $period, Filtro: $filter');
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final dateFrom = _getPeriodDateFrom(period);
      final filters = {
        'date_from': dateFrom,
        'date_to': DateTime.now().toIso8601String().split('T')[0],
        'status': filter,
      };

      // Carregar dados de localização e aplicadores em paralelo
      final results = await Future.wait([
        ApiService.getLocationsData(filters),
        ApiService.getApplicatorsStats(filters),
      ]);

      final locationResponse = results[0];
      final applicatorsResponse = results[1];

      // Processar dados de localização
      if (locationResponse['success'] == true && locationResponse['data'] != null) {
        final mapData = locationResponse['data']['map_data'] as List<dynamic>? ?? [];
        _locationData = mapData.map((data) => MapLocationData.fromJson(data)).toList();
        
        // Processar dados de cobertura se disponível
        final coverageData = locationResponse['data']['coverage'];
        if (coverageData != null) {
          _coverage = LocationCoverage.fromJson(coverageData);
        }
      }

      // Processar dados de aplicadores
      if (applicatorsResponse['success'] == true && applicatorsResponse['data'] != null) {
        final applicators = applicatorsResponse['data']['applicators'] as List<dynamic>? ?? [];
        _applicatorsStats = applicators.map((data) => ApplicatorStats.fromJson(data)).toList();
      }

      _lastUpdated = DateTime.now();
      _error = null;
      
      print('✅ Dados do mapa carregados com sucesso');
      print('📍 ${_locationData.length} localizações encontradas');
      print('👥 ${_applicatorsStats.length} aplicadores encontrados');

    } catch (e, stackTrace) {
      _error = 'Erro ao carregar dados do mapa: $e';
      print('❌ Erro ao carregar dados do mapa: $e');
      print('📋 Stack trace: $stackTrace');
      
      // Carregar dados simulados em caso de erro
      _loadSimulatedData();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Obter data de início baseada no período
  String _getPeriodDateFrom(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'last_7_days':
        return now.subtract(const Duration(days: 7)).toIso8601String().split('T')[0];
      case 'last_30_days':
        return now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
      case 'last_3_months':
        return now.subtract(const Duration(days: 90)).toIso8601String().split('T')[0];
      default:
        return now.subtract(const Duration(days: 30)).toIso8601String().split('T')[0];
    }
  }

  /// Carregar dados simulados para desenvolvimento/fallback
  void _loadSimulatedData() {
    _locationData = [
      MapLocationData(
        lat: -15.7801,
        lng: -47.9292,
        applicatorName: 'João Silva',
        locationName: 'Centro - Brasília',
        formsCount: 23,
        applicatorId: 1,
      ),
      MapLocationData(
        lat: -15.7901,
        lng: -47.9392,
        applicatorName: 'Maria Santos',
        locationName: 'Asa Norte',
        formsCount: 18,
        applicatorId: 2,
      ),
      MapLocationData(
        lat: -15.8301,
        lng: -47.9192,
        applicatorName: 'Carlos Lima',
        locationName: 'Asa Sul',
        formsCount: 31,
        applicatorId: 3,
      ),
      MapLocationData(
        lat: -15.7601,
        lng: -47.9492,
        applicatorName: 'Ana Costa',
        locationName: 'Lago Norte',
        formsCount: 12,
        applicatorId: 4,
      ),
    ];

    _applicatorsStats = [
      ApplicatorStats(
        id: 1,
        name: 'João Silva',
        totalForms: 23,
        lastActivity: '2 horas atrás',
        isActive: true,
        primaryLocation: 'Centro',
      ),
      ApplicatorStats(
        id: 2,
        name: 'Maria Santos',
        totalForms: 18,
        lastActivity: '5 horas atrás',
        isActive: true,
        primaryLocation: 'Asa Norte',
      ),
      ApplicatorStats(
        id: 3,
        name: 'Carlos Lima',
        totalForms: 31,
        lastActivity: '1 dia atrás',
        isActive: true,
        primaryLocation: 'Asa Sul',
      ),
      ApplicatorStats(
        id: 4,
        name: 'Ana Costa',
        totalForms: 12,
        lastActivity: '3 dias atrás',
        isActive: false,
        primaryLocation: 'Lago Norte',
      ),
    ];

    _coverage = LocationCoverage(
      uniqueCollectionPoints: 45,
      coveragePercentage: 78,
      newAreasThisMonth: 5,
      highDensityZones: 3,
    );
  }

  /// Calcular estatísticas de localização
  List<LocationStat> getLocationStats() {
    final locationStats = <String, LocationStat>{};
    
    for (final location in _locationData) {
      final key = location.locationName;
      if (locationStats.containsKey(key)) {
        locationStats[key]!.forms += location.formsCount;
        locationStats[key]!.applicators.add(location.applicatorId);
      } else {
        locationStats[key] = LocationStat(
          name: key,
          forms: location.formsCount,
          applicators: {location.applicatorId},
        );
      }
    }

    final sortedStats = locationStats.values.toList()
      ..sort((a, b) => b.forms.compareTo(a.forms));

    return sortedStats;
  }

  /// Limpar dados
  void clearData() {
    _locationData.clear();
    _applicatorsStats.clear();
    _coverage = null;
    _error = null;
    _lastUpdated = null;
    notifyListeners();
  }

  /// Verificar se precisa atualizar
  bool get needsUpdate {
    return _lastUpdated == null || 
           DateTime.now().difference(_lastUpdated!).inMinutes > 10;
  }
}

// Modelos de dados adicionais
class LocationCoverage {
  final int uniqueCollectionPoints;
  final int coveragePercentage;
  final int newAreasThisMonth;
  final int highDensityZones;

  LocationCoverage({
    required this.uniqueCollectionPoints,
    required this.coveragePercentage,
    required this.newAreasThisMonth,
    required this.highDensityZones,
  });

  factory LocationCoverage.fromJson(Map<String, dynamic> json) {
    return LocationCoverage(
      uniqueCollectionPoints: json['unique_collection_points'] ?? 0,
      coveragePercentage: json['coverage_percentage'] ?? 0,
      newAreasThisMonth: json['new_areas_this_month'] ?? 0,
      highDensityZones: json['high_density_zones'] ?? 0,
    );
  }
}

// Reutilizando os modelos já definidos
class MapLocationData {
  final double lat;
  final double lng;
  final String applicatorName;
  final String locationName;
  final int formsCount;
  final int applicatorId;

  MapLocationData({
    required this.lat,
    required this.lng,
    required this.applicatorName,
    required this.locationName,
    required this.formsCount,
    required this.applicatorId,
  });

  factory MapLocationData.fromJson(Map<String, dynamic> json) {
    return MapLocationData(
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      applicatorName: json['applicator_name'] ?? '',
      locationName: json['location_name'] ?? '',
      formsCount: json['forms_count'] ?? 0,
      applicatorId: json['applicator_id'] ?? 0,
    );
  }
}

class ApplicatorStats {
  final int id;
  final String name;
  final int totalForms;
  final String lastActivity;
  final bool isActive;
  final String primaryLocation;

  ApplicatorStats({
    required this.id,
    required this.name,
    required this.totalForms,
    required this.lastActivity,
    required this.isActive,
    required this.primaryLocation,
  });

  factory ApplicatorStats.fromJson(Map<String, dynamic> json) {
    return ApplicatorStats(
      id: json['id'] ?? 0,
      name: json['full_name'] ?? json['name'] ?? '',
      totalForms: json['total_forms'] ?? 0,
      lastActivity: json['last_activity_formatted'] ?? json['last_activity'] ?? '',
      isActive: json['is_active'] ?? json['status'] == 'active',
      primaryLocation: json['primary_location'] ?? '',
    );
  }
}

class LocationStat {
  final String name;
  int forms;
  final Set<int> applicators;

  LocationStat({
    required this.name,
    required this.forms,
    required this.applicators,
  });
}