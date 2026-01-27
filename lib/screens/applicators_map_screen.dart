import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;  // ← Esta linha deve estar presente
import '../providers/stats_provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class BrazilMapScreen extends StatefulWidget {
  const BrazilMapScreen({super.key});

  @override
  State<BrazilMapScreen> createState() => _BrazilMapScreenState();
}

class _BrazilMapScreenState extends State<BrazilMapScreen> {
  final String _selectedFilter = 'all';
  String _selectedPeriod = 'last_30_days';
  List<MapLocationData> _locationData = [];
  List<ApplicatorStats> _applicatorsStats = [];
  bool _mapLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String? _selectedState;
  bool _mapInitialized = false;
  bool _showDataTable = false;
  
  // Controlador do mapa
  final MapController _mapController = MapController();
  
  // Centro do Brasil
  static const LatLng _brazilCenter = LatLng(-14.2350, -51.9253);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      // Força um refresh do mapa após um pequeno delay
      Future.delayed(const Duration(milliseconds: 500), () {
        _forceMapRefresh();
      });
    });
  }

  void _forceMapRefresh() {
    if (mounted) {
      setState(() {
        _mapInitialized = true;
      });
      
      // Força uma pequena mudança de zoom para "acordar" o mapa
      final currentZoom = _mapController.camera.zoom;
      _mapController.move(_brazilCenter, currentZoom + 0.001);
      
      // Volta ao zoom original após um pequeno delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _mapController.move(_brazilCenter, currentZoom);
        }
      });
    }
  }

  void _loadData() async {
    setState(() {
      _mapLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final statsProvider = Provider.of<StatsProvider>(context, listen: false);
    
    final userId = authProvider.user?.id;
    if (userId != null) {
      await statsProvider.loadUserStats(userId);
      await _loadLocationData();
      await _loadApplicatorsData();
    }

    setState(() {
      _mapLoading = false;
    });

    // Refresh do mapa após carregar os dados
    if (_locationData.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _forceMapRefresh();
      });
    }
  }

  Future<void> _loadLocationData() async {
    try {
      print('🗺️ Carregando dados de localização do Brasil...');
      
      final response = await ApiService.getLocationsData({
        'date_from': _getPeriodDateFrom(),
        'date_to': DateTime.now().toIso8601String().split('T')[0],
        'status': _selectedFilter,
        'state': _selectedState ?? 'all',
      });

      if (response['success'] == true && response['data'] != null) {
        final mapData = response['data']['map_data'] as List<dynamic>? ?? [];
        
        final validLocations = mapData
            .map((data) => MapLocationData.fromJson(data))
            .where((location) => _isValidCoordinate(location.lat, location.lng))
            .toList();
        
        setState(() {
          _locationData = validLocations;
        });
        
        print('✅ ${_locationData.length} localizações válidas carregadas');
        
        if (_locationData.isEmpty) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Nenhuma localização encontrada para o período selecionado';
          });
        }
      } else {
        throw Exception(response['message'] ?? 'Dados não encontrados');
      }
    } catch (e) {
      print('❌ Erro ao carregar dados de localização: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Erro ao carregar dados de localização: $e';
      });
    }
  }

  Future<void> _loadApplicatorsData() async {
    try {
      print('👥 Carregando dados de aplicadores...');
      
      final response = await ApiService.getApplicatorsStats({
        'date_from': _getPeriodDateFrom(),
        'date_to': DateTime.now().toIso8601String().split('T')[0],
        'status': _selectedFilter,
        'state': _selectedState ?? 'all',
      });

      if (response['success'] == true && response['data'] != null) {
        final applicators = response['data']['applicators'] as List<dynamic>? ?? [];
        setState(() {
          _applicatorsStats = applicators.map((data) => ApplicatorStats.fromJson(data)).toList();
        });
        
        print('✅ ${_applicatorsStats.length} aplicadores carregados');
      } else {
        throw Exception(response['message'] ?? 'Dados de aplicadores não encontrados');
      }
    } catch (e) {
      print('❌ Erro ao carregar dados de aplicadores: $e');
    }
  }

  bool _isValidCoordinate(double lat, double lng) {
    return lat != 0 && 
           lng != 0 && 
           lat >= -35 && // Limite sul do Brasil
           lat <= 5 &&   // Limite norte do Brasil
           lng >= -75 && // Limite oeste do Brasil
           lng <= -30;   // Limite leste do Brasil
  }

  String _getPeriodDateFrom() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
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

  void _onStateSelected(String stateName, String stateCode) {
    setState(() {
      _selectedState = stateCode;
    });
    _loadData();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Estado selecionado: $stateName'),
        backgroundColor: const Color(0xFF8fae5d),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _centerOnBrazil() {
    _mapController.move(_brazilCenter, 4.0);
    // Força refresh após centralizar
    Future.delayed(const Duration(milliseconds: 100), () {
      _forceMapRefresh();
    });
  }

  void _toggleDataView() {
    setState(() {
      _showDataTable = !_showDataTable;
    });
    
    if (!_showDataTable && _locationData.isNotEmpty) {
      // Se voltou para o mapa e há dados, centraliza nos dados
      _centerOnData();
    }
  }

  void _centerOnData() {
    if (_locationData.isNotEmpty) {
      // Calcular bounds dos dados
      double minLat = _locationData.first.lat;
      double maxLat = _locationData.first.lat;
      double minLng = _locationData.first.lng;
      double maxLng = _locationData.first.lng;

      for (final location in _locationData) {
        minLat = math.min(minLat, location.lat);
        maxLat = math.max(maxLat, location.lat);
        minLng = math.min(minLng, location.lng);
        maxLng = math.max(maxLng, location.lng);
      }

      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );

      _mapController.fitBounds(bounds, options: const FitBoundsOptions(
        padding: EdgeInsets.all(50.0),
      ));
      
      // Força refresh após ajustar bounds
      Future.delayed(const Duration(milliseconds: 200), () {
        _forceMapRefresh();
      });
    }
  }

  void _goToLocationOnMap(MapLocationData location) {
  print('🗺️ Dados recebidos - Lat: ${location.lat}, Lng: ${location.lng}');
  
  // Validar coordenadas antes de usar
  if (location.lat == 0 && location.lng == 0) {
    print('❌ Coordenadas inválidas: 0,0');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordenadas inválidas para esta localização'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  // Verificar se as coordenadas estão dentro do Brasil
  if (!_isValidCoordinate(location.lat, location.lng)) {
    print('❌ Coordenadas fora dos limites do Brasil: ${location.lat}, ${location.lng}');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Localização fora dos limites do Brasil'),
        backgroundColor: Colors.orange,
      ),
    );
    return;
  }
  
  try {
    // Muda para a visualização do mapa
    setState(() {
      _showDataTable = false;
    });
    
    print('🗺️ Mudou para visualização do mapa');
    
    // Aguarda um frame para garantir que o mapa foi renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // IMPORTANTE: LatLng(latitude, longitude) - ordem correta
        final targetLocation = LatLng(location.lat, location.lng);
        print('🗺️ Coordenadas finais para o mapa: $targetLocation');
        print('🗺️ Latitude: ${location.lat} | Longitude: ${location.lng}');
        
        // Centraliza o mapa na localização selecionada
        _mapController.move(targetLocation, 16.0); // Zoom bem próximo
        
        print('🗺️ Comando move() executado com sucesso');
        
        // Força refresh do mapa após um pequeno delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _forceMapRefresh();
            print('🗺️ Refresh do mapa executado');
            
            // Segundo movimento para garantir que funcionou
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                _mapController.move(targetLocation, 16.0);
                print('🗺️ Segundo movimento executado');
              }
            });
          }
        });
        
        // Mostra feedback para o usuário
        if (mounted) {
          final locationName = location.locationName.isNotEmpty 
              ? location.locationName 
              : 'Coordenadas: ${location.lat.toStringAsFixed(4)}°, ${location.lng.toStringAsFixed(4)}°';
              
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Navegando para: $locationName',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${location.lat.toStringAsFixed(6)} | Lng: ${location.lng.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF8fae5d),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Voltar',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _showDataTable = true;
                  });
                },
              ),
            ),
          );
          print('🗺️ SnackBar exibido com coordenadas detalhadas');
        }
      } catch (e) {
        print('❌ Erro ao mover mapa: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao navegar para o mapa: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  } catch (e) {
    print('❌ Erro geral na navegação: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao processar a navegação: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header customizado
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(35, 52, 95, 1.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        _showDataTable ? 'Dados de Aplicadores' : 'Mapa de Aplicadores',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _selectedState != null 
                            ? 'Estado: ${BrazilStates.getStateName(_selectedState!)}'
                            : _showDataTable ? 'Tabela de Dados' : 'Localizações',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Consumer<StatsProvider>(
                    builder: (context, statsProvider, child) {
                      return IconButton(
                        onPressed: statsProvider.isLoading ? null : () {
                          _loadData();
                          // Força refresh após reload
                          Future.delayed(const Duration(milliseconds: 500), () {
                            _forceMapRefresh();
                          });
                        },
                        icon: statsProvider.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.refresh,
                                color: Color(0xFF8fae5d),
                                size: 24,
                              ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Filtros
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterDropdown(
                          'Estado',
                          _selectedState ?? 'all',
                          [
                            {'value': 'all', 'label': 'Todos os Estados'},
                            ...BrazilStates.getAllStates().map((state) => {
                              'value': state.code,
                              'label': state.name,
                            }),
                          ],
                          (value) {
                            setState(() {
                              _selectedState = value == 'all' ? null : value;
                            });
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFilterDropdown(
                          'Período',
                          _selectedPeriod,
                          [
                            {'value': 'last_7_days', 'label': 'Últimos 7 dias'},
                            {'value': 'last_30_days', 'label': 'Últimos 30 dias'},
                            {'value': 'last_3_months', 'label': 'Últimos 3 meses'},
                          ],
                          (value) {
                            setState(() => _selectedPeriod = value);
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Botões de controle do mapa/dados
                  Row(
                    children: [
                      if (!_showDataTable) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _centerOnBrazil,
                            icon: const Icon(Icons.my_location, size: 16),
                            label: const Text('Centralizar Brasil'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF8fae5d),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _locationData.isNotEmpty ? _toggleDataView : null,
                          icon: Icon(
                            _showDataTable ? Icons.map : Icons.table_chart,
                            size: 16,
                          ),
                          label: Text(_showDataTable ? 'Ver Mapa' : 'Ver Dados'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _showDataTable ? const Color(0xFF8fae5d) : Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Info bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF8fae5d).withOpacity(0.1),
              child: Row(
                children: [
                  Icon(
                    _showDataTable ? Icons.table_chart : Icons.map,
                    size: 16,
                    color: const Color(0xFF8fae5d),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_locationData.length} pontos no Brasil${_selectedState != null ? ' - ${BrazilStates.getStateName(_selectedState!)}' : ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF23345F),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _showDataTable ? 'Visualização Tabular' : '',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8fae5d),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo principal (Mapa ou Tabela)
            Expanded(
              child: Consumer<StatsProvider>(
                builder: (context, statsProvider, child) {
                  if (statsProvider.isLoading && _locationData.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8fae5d)),
                      ),
                    );
                  }

                  return _showDataTable ? _buildDataTable() : _buildOpenStreetMap();
                },
              ),
            ),

            // Estatísticas por estado
            if (_selectedState != null) ...[
              _buildStateInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    // Filtrar dados localmente baseado no estado selecionado
    List<MapLocationData> filteredData = _locationData;
    
    if (_selectedState != null && _selectedState != 'all') {
      filteredData = _locationData.where((location) {
        // Garantir que o estado seja identificado corretamente
        String locationState = location.state ?? 
          MapLocationData.getStateFromCoordinates(location.lat, location.lng);
        return locationState == _selectedState;
      }).toList();
    }

    if (filteredData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.table_chart_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum dado encontrado',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedState != null 
                  ? 'Nenhum registro encontrado para ${BrazilStates.getStateName(_selectedState!)}'
                  : 'Ajuste os filtros ou tente novamente',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho da tabela
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF23345F),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _selectedState != null 
                      ? 'Dados - ${BrazilStates.getStateName(_selectedState!)}'
                      : 'Dados por Localização',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8fae5d),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${filteredData.length} registros',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tabela de dados
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF8fae5d).withOpacity(0.1),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'Localização',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Aplicador',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Estado',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Formulários',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'Intensidade',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                      ),
                    ),
                  ),
                ],
                rows: filteredData.map((location) {
                  // Garantir que o estado seja identificado
                  String locationState = location.state ?? 
                    MapLocationData.getStateFromCoordinates(location.lat, location.lng);
                  
                  // Determinar intensidade
                  String intensity;
                  Color intensityColor;
                  
                  if (location.formsCount >= 25) {
                    intensity = 'Alto';
                    intensityColor = Colors.red[600]!;
                  } else if (location.formsCount >= 15) {
                    intensity = 'Médio';
                    intensityColor = Colors.orange[600]!;
                  } else if (location.formsCount >= 5) {
                    intensity = 'Baixo';
                    intensityColor = Colors.yellow[700]!;
                  } else {
                    intensity = 'Mínimo';
                    intensityColor = Colors.green[600]!;
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        GestureDetector(
                          onTap: () {
                            print('🗺️ Clicou na coordenada: ${location.lat}, ${location.lng}');
                            _goToLocationOnMap(location);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2, 
                              vertical: 2
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        '${location.lat.toStringAsFixed(4)}°, ${location.lng.toStringAsFixed(4)}°',
                                        style: const TextStyle(
                                          color: Color(0xFF8fae5d),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),                                
                              ],
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          location.applicatorName.isNotEmpty 
                              ? location.applicatorName 
                              : 'Aplicador ${location.applicatorId}',
                          style: const TextStyle(
                            color: Color(0xFF23345F),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8fae5d).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            BrazilStates.getStateName(locationState),
                            style: const TextStyle(
                              color: Color(0xFF23345F),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${location.formsCount}',
                          style: const TextStyle(
                            color: Color(0xFF23345F),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: intensityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: intensityColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            intensity,
                            style: TextStyle(
                              color: intensityColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenStreetMap() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _brazilCenter,
                initialZoom: 4.0, // Mudança do zoom inicial para melhor visualização
                minZoom: 2.0,
                maxZoom: 18.0,
                backgroundColor: Colors.lightBlue[50]!,
                interactiveFlags: InteractiveFlag.all,
                // Callback quando o mapa é iniciado
                onMapReady: () {
                  print('🗺️ Mapa inicializado');
                  Future.delayed(const Duration(milliseconds: 200), () {
                    _forceMapRefresh();
                  });
                },
                // Callback para eventos de movimento do mapa
                onPositionChanged: (camera, hasGesture) {
                  if (!_mapInitialized && hasGesture) {
                    setState(() {
                      _mapInitialized = true;
                    });
                  }
                },
              ),
              children: [
                // Camada do mapa base (OpenStreetMap)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app_cnes',
                  maxZoom: 18,
                  backgroundColor: Colors.lightBlue[50]!,
                  // Configurações para melhor carregamento
                  retinaMode: true,
                  // Adiciona headers para melhor performance
                  additionalOptions: const {
                    'attribution': '',
                  },
                  // Configurações de cache e carregamento
                  tileProvider: CancellableNetworkTileProvider(),
                ),
                
                // Camada de markers dos dados
                MarkerLayer(
                  markers: _buildDataMarkers(),
                ),
                
                // Camada de polígonos dos estados (opcional)
                if (_selectedState != null)
                  PolygonLayer(
                    polygons: _buildStatePolygons(),
                  ),
              ],
            ),
            
            // Loading overlay
            if (_mapLoading)
              Container(
                color: Colors.white.withOpacity(0.8),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8fae5d)),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Carregando mapa...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Botão de refresh manual do mapa (temporário para debug)
            if (!_mapInitialized)
              Positioned(
                top: 10,
                left: 10,
                child: FloatingActionButton.small(
                  onPressed: _forceMapRefresh,
                  backgroundColor: const Color(0xFF8fae5d),
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
              ),

            // Legenda
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Legenda',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF23345F),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildLegendItem('Alto (25+)', Colors.red[600]!),
                    _buildLegendItem('Médio (15-24)', Colors.orange[600]!),
                    _buildLegendItem('Baixo (5-14)', Colors.yellow[700]!),
                    _buildLegendItem('Mínimo (1-4)', Colors.green[600]!),
                  ],
                ),
              ),
            ),

            // Attribution (obrigatório para OpenStreetMap)
            Positioned(
              bottom: 5,
              right: 5,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildDataMarkers() {
    return _locationData.map((location) {
      // Definir cor e tamanho baseado na intensidade
      Color markerColor;
      double size;
      
      if (location.formsCount >= 25) {
        markerColor = Colors.red[600]!;
        size = 20.0;
      } else if (location.formsCount >= 15) {
        markerColor = Colors.orange[600]!;
        size = 16.0;
      } else if (location.formsCount >= 5) {
        markerColor = Colors.yellow[700]!;
        size = 14.0;
      } else {
        markerColor = Colors.green[600]!;
        size = 12.0;
      }

      return Marker(
        point: LatLng(location.lat, location.lng),
        width: size,
        height: size,
        child: GestureDetector(
          onTap: () => _showLocationDetails(location),
          child: Container(
            decoration: BoxDecoration(
              color: markerColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${location.formsCount}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Polygon> _buildStatePolygons() {
    if (_selectedState == null) return [];
    
    final state = BrazilStates.getAllStates()
        .firstWhere((s) => s.code == _selectedState, orElse: () => 
            BrazilState(code: '', name: '', coordinates: []));
    
    if (state.coordinates.isEmpty) return [];

    return [
      Polygon(
        points: state.coordinates.map((coord) => LatLng(coord.latitude, coord.longitude)).toList(),
        color: const Color(0xFF8fae5d).withOpacity(0.3),
        borderColor: const Color(0xFF8fae5d),
        borderStrokeWidth: 2,
        isFilled: true,
      ),
    ];
  }

  void _showLocationDetails(MapLocationData location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: location.formsCount >= 25 ? Colors.red[600] :
                           location.formsCount >= 15 ? Colors.orange[600] :
                           location.formsCount >= 5 ? Colors.yellow[700] :
                           Colors.green[600],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location.locationName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF23345F),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailItem('Aplicador', location.applicatorName),
            _buildDetailItem('Formulários', '${location.formsCount}'),
            _buildDetailItem('Estado', location.state ?? 'N/A'),
            _buildDetailItem('Coordenadas', '${location.lat.toStringAsFixed(4)}, ${location.lng.toStringAsFixed(4)}'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8fae5d),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Fechar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF23345F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<Map<String, String>> options,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF23345F),
              ),
              onChanged: (newValue) => onChanged(newValue!),
              items: options.map((option) {
                return DropdownMenuItem<String>(
                  value: option['value'],
                  child: Text(
                    option['label']!,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateInfo() {
    if (_selectedState == null) return const SizedBox.shrink();

    final stateName = BrazilStates.getStateName(_selectedState!);
    
    // Usar dados filtrados localmente
    final stateData = _locationData.where((location) {
      String locationState = location.state ?? 
        MapLocationData.getStateFromCoordinates(location.lat, location.lng);
      return locationState == _selectedState;
    }).toList();
    
    final applicatorsInState = _applicatorsStats.where((app) => 
      app.state == _selectedState).toList();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Color(0xFF8fae5d),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                stateName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF23345F),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8fae5d).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${stateData.length} registros',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8fae5d),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Aplicadores',
                  '${applicatorsInState.length}',
                  Icons.people,
                  const Color(0xFF8fae5d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Formulários',
                  '${stateData.fold<int>(0, (sum, item) => sum + item.formsCount)}',
                  Icons.description,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Locais',
                  '${stateData.map((e) => e.locationName).toSet().length}',
                  Icons.place,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class BrazilState {
  final String code;
  final String name;
  final List<LatLng> coordinates;

  BrazilState({
    required this.code,
    required this.name,
    required this.coordinates,
  });
}

class BrazilStates {
  static List<BrazilState> getAllStates() {
    return [
      // Região Norte
      BrazilState(
        code: 'AC',
        name: 'Acre',
        coordinates: [
          const LatLng(-7.5, -73.8),
          const LatLng(-7.2, -72.8),
          const LatLng(-8.8, -70.5),
          const LatLng(-10.8, -68.7),
          const LatLng(-11.1, -69.3),
          const LatLng(-11.0, -72.2),
          const LatLng(-9.2, -73.7),
        ],
      ),
      BrazilState(
        code: 'AM',
        name: 'Amazonas',
        coordinates: [
          const LatLng(-2.0, -69.8),
          const LatLng(2.2, -63.8),
          const LatLng(2.5, -60.1),
          const LatLng(-3.2, -56.0),
          const LatLng(-7.8, -58.2),
          const LatLng(-10.2, -67.2),
          const LatLng(-7.5, -73.0),
        ],
      ),
      BrazilState(
        code: 'AP',
        name: 'Amapá',
        coordinates: [
          const LatLng(4.4, -54.5),
          const LatLng(3.8, -51.2),
          const LatLng(1.8, -50.5),
          const LatLng(-1.2, -51.8),
          const LatLng(-0.8, -54.2),
        ],
      ),
      BrazilState(
        code: 'PA',
        name: 'Pará',
        coordinates: [
          const LatLng(2.6, -58.2),
          const LatLng(1.8, -55.8),
          const LatLng(1.2, -48.8),
          const LatLng(-8.2, -46.2),
          const LatLng(-12.5, -48.5),
          const LatLng(-11.8, -54.2),
          const LatLng(-7.8, -58.5),
        ],
      ),
      BrazilState(
        code: 'RO',
        name: 'Rondônia',
        coordinates: [
          const LatLng(-7.8, -66.8),
          const LatLng(-7.9, -60.1),
          const LatLng(-13.7, -59.8),
          const LatLng(-13.6, -66.2),
        ],
      ),
      BrazilState(
        code: 'RR',
        name: 'Roraima',
        coordinates: [
          const LatLng(5.3, -64.0),
          const LatLng(5.2, -59.8),
          const LatLng(1.8, -58.2),
          const LatLng(-1.0, -61.2),
          const LatLng(1.2, -64.8),
        ],
      ),
      BrazilState(
        code: 'TO',
        name: 'Tocantins',
        coordinates: [
          const LatLng(-5.2, -50.0),
          const LatLng(-5.1, -46.4),
          const LatLng(-13.5, -46.1),
          const LatLng(-13.4, -50.3),
        ],
      ),

      // Região Nordeste
      BrazilState(
        code: 'AL',
        name: 'Alagoas',
        coordinates: [
          const LatLng(-8.8, -37.8),
          const LatLng(-8.8, -35.1),
          const LatLng(-10.5, -35.7),
          const LatLng(-10.4, -37.9),
        ],
      ),
      BrazilState(
        code: 'BA',
        name: 'Bahia',
        coordinates: [
          const LatLng(-8.5, -46.6),
          const LatLng(-8.8, -38.2),
          const LatLng(-12.2, -37.3),
          const LatLng(-18.3, -39.8),
          const LatLng(-18.1, -46.2),
          const LatLng(-10.8, -46.8),
        ],
      ),
      BrazilState(
        code: 'CE',
        name: 'Ceará',
        coordinates: [
          const LatLng(-2.8, -41.4),
          const LatLng(-2.7, -37.2),
          const LatLng(-4.8, -37.1),
          const LatLng(-7.9, -40.1),
          const LatLng(-7.2, -41.3),
        ],
      ),
      BrazilState(
        code: 'MA',
        name: 'Maranhão',
        coordinates: [
          const LatLng(-1.0, -48.6),
          const LatLng(-1.2, -41.8),
          const LatLng(-7.8, -42.2),
          const LatLng(-10.3, -46.2),
          const LatLng(-8.2, -48.4),
        ],
      ),
      BrazilState(
        code: 'PB',
        name: 'Paraíba',
        coordinates: [
          const LatLng(-6.0, -38.8),
          const LatLng(-6.1, -34.8),
          const LatLng(-8.3, -35.2),
          const LatLng(-8.2, -38.6),
        ],
      ),
      BrazilState(
        code: 'PE',
        name: 'Pernambuco',
        coordinates: [
          const LatLng(-7.3, -41.4),
          const LatLng(-7.2, -34.8),
          const LatLng(-9.5, -35.2),
          const LatLng(-9.6, -40.8),
        ],
      ),
      BrazilState(
        code: 'PI',
        name: 'Piauí',
        coordinates: [
          const LatLng(-2.7, -45.9),
          const LatLng(-2.8, -40.4),
          const LatLng(-10.9, -40.8),
          const LatLng(-10.8, -45.2),
        ],
      ),
      BrazilState(
        code: 'RN',
        name: 'Rio Grande do Norte',
        coordinates: [
          const LatLng(-4.8, -38.6),
          const LatLng(-4.9, -34.9),
          const LatLng(-6.9, -35.2),
          const LatLng(-6.8, -38.4),
        ],
      ),
      BrazilState(
        code: 'SE',
        name: 'Sergipe',
        coordinates: [
          const LatLng(-9.5, -38.2),
          const LatLng(-9.6, -36.4),
          const LatLng(-11.6, -36.8),
          const LatLng(-11.5, -37.9),
        ],
      ),

      // Região Centro-Oeste
      BrazilState(
        code: 'DF',
        name: 'Distrito Federal',
        coordinates: [
          const LatLng(-15.5, -48.3),
          const LatLng(-15.4, -47.2),
          const LatLng(-16.1, -47.3),
          const LatLng(-16.0, -48.2),
        ],
      ),
      BrazilState(
        code: 'GO',
        name: 'Goiás',
        coordinates: [
          const LatLng(-12.4, -53.2),
          const LatLng(-12.2, -45.9),
          const LatLng(-19.9, -46.2),
          const LatLng(-19.8, -53.0),
        ],
      ),
      BrazilState(
        code: 'MT',
        name: 'Mato Grosso',
        coordinates: [
          const LatLng(-7.3, -65.4),
          const LatLng(-7.2, -50.2),
          const LatLng(-18.0, -50.8),
          const LatLng(-17.9, -65.2),
        ],
      ),
      BrazilState(
        code: 'MS',
        name: 'Mato Grosso do Sul',
        coordinates: [
          const LatLng(-17.9, -58.2),
          const LatLng(-17.8, -51.0),
          const LatLng(-24.1, -51.4),
          const LatLng(-24.0, -57.8),
        ],
      ),

      // Região Sudeste
      BrazilState(
        code: 'ES',
        name: 'Espírito Santo',
        coordinates: [
          const LatLng(-17.9, -41.9),
          const LatLng(-18.1, -39.7),
          const LatLng(-21.3, -40.1),
          const LatLng(-21.2, -41.6),
        ],
      ),
      BrazilState(
        code: 'MG',
        name: 'Minas Gerais',
        coordinates: [
          const LatLng(-14.2, -51.0),
          const LatLng(-14.1, -39.9),
          const LatLng(-22.9, -41.2),
          const LatLng(-22.8, -50.8),
        ],
      ),
      BrazilState(
        code: 'RJ',
        name: 'Rio de Janeiro',
        coordinates: [
          const LatLng(-20.8, -45.0),
          const LatLng(-20.9, -40.9),
          const LatLng(-23.4, -41.2),
          const LatLng(-23.3, -44.8),
        ],
      ),
      BrazilState(
        code: 'SP',
        name: 'São Paulo',
        coordinates: [
          const LatLng(-19.8, -53.1),
          const LatLng(-19.9, -44.2),
          const LatLng(-25.3, -44.8),
          const LatLng(-25.2, -52.8),
        ],
      ),

      // Região Sul
      BrazilState(
        code: 'PR',
        name: 'Paraná',
        coordinates: [
          const LatLng(-22.5, -54.6),
          const LatLng(-22.4, -48.0),
          const LatLng(-26.7, -48.4),
          const LatLng(-26.6, -54.2),
        ],
      ),
      BrazilState(
        code: 'RS',
        name: 'Rio Grande do Sul',
        coordinates: [
          const LatLng(-27.1, -57.6),
          const LatLng(-27.2, -49.7),
          const LatLng(-33.8, -50.1),
          const LatLng(-33.7, -57.2),
        ],
      ),
      BrazilState(
        code: 'SC',
        name: 'Santa Catarina',
        coordinates: [
          const LatLng(-25.9, -53.8),
          const LatLng(-26.0, -48.3),
          const LatLng(-29.4, -48.7),
          const LatLng(-29.3, -53.4),
        ],
      ),
    ];
  }

  static String getStateName(String code) {
    final states = getAllStates();
    final state = states.firstWhere(
      (s) => s.code == code,
      orElse: () => BrazilState(code: 'XX', name: 'Desconhecido', coordinates: []),
    );
    return state.name;
  }
}

// Modelos de dados existentes
class MapLocationData {
  final double lat;
  final double lng;
  final String applicatorName;
  final String locationName;
  final int formsCount;
  final int applicatorId;
  final String? state;

  MapLocationData({
    required this.lat,
    required this.lng,
    required this.applicatorName,
    required this.locationName,
    required this.formsCount,
    required this.applicatorId,
    this.state,
  });

  factory MapLocationData.fromJson(Map<String, dynamic> json) {
    final lat = (json['lat'] ?? 0).toDouble();
    final lng = (json['lng'] ?? 0).toDouble();
    
    return MapLocationData(
      lat: lat,
      lng: lng,
      applicatorName: json['applicator_name'] ?? '',
      locationName: json['location_name'] ?? '',
      formsCount: json['forms_count'] ?? 0,
      applicatorId: json['applicator_id'] ?? 0,
      state: json['state'] ?? _getStateFromCoordinates(lat, lng),
    );
  }

  static String _getStateFromCoordinates(double lat, double lng) {
    // Verificar se as coordenadas são válidas
    if (lat == 0 && lng == 0) return 'XX';
    
    // Região Norte
    if (lat >= -2.5 && lat <= 5.3 && lng >= -75.0 && lng <= -56.0) {
      // Amazonas - maior estado, região central da Amazônia
      if (lat >= -10.0 && lat <= 2.2 && lng >= -73.8 && lng <= -56.0) return 'AM';
      
      // Roraima - extremo norte
      if (lat >= 1.0 && lat <= 5.3 && lng >= -64.8 && lng <= -58.2) return 'RR';
      
      // Amapá - nordeste da região norte
      if (lat >= -1.2 && lat <= 4.4 && lng >= -54.5 && lng <= -50.0) return 'AP';
      
      // Pará - leste da região norte
      if (lat >= -8.2 && lat <= 2.6 && lng >= -58.5 && lng <= -46.0) return 'PA';
      
      // Acre - extremo oeste
      if (lat >= -11.1 && lat <= -7.0 && lng >= -73.8 && lng <= -66.7) return 'AC';
      
      // Rondônia - sudoeste da região norte
      if (lat >= -13.7 && lat <= -7.8 && lng >= -66.8 && lng <= -59.8) return 'RO';
    }
    
    // Tocantins - transição norte/centro-oeste
    if (lat >= -13.5 && lat <= -5.0 && lng >= -50.3 && lng <= -46.0) return 'TO';
    
    // Região Nordeste
    if (lat >= -18.5 && lat <= 5.0 && lng >= -48.5 && lng <= -34.8) {
      // Maranhão - oeste do nordeste
      if (lat >= -10.3 && lat <= -1.0 && lng >= -48.6 && lng <= -41.8) return 'MA';
      
      // Piauí - interior do nordeste
      if (lat >= -10.9 && lat <= -2.7 && lng >= -45.9 && lng <= -40.4) return 'PI';
      
      // Ceará - norte do nordeste
      if (lat >= -7.9 && lat <= -2.7 && lng >= -41.4 && lng <= -37.1) return 'CE';
      
      // Rio Grande do Norte - extremo nordeste
      if (lat >= -6.9 && lat <= -4.8 && lng >= -38.6 && lng <= -34.9) return 'RN';
      
      // Paraíba - costa nordeste
      if (lat >= -8.3 && lat <= -6.0 && lng >= -38.8 && lng <= -34.8) return 'PB';
      
      // Pernambuco - centro-leste do nordeste
      if (lat >= -9.6 && lat <= -7.2 && lng >= -41.4 && lng <= -34.8) return 'PE';
      
      // Alagoas - pequeno estado costeiro
      if (lat >= -10.5 && lat <= -8.8 && lng >= -37.9 && lng <= -35.1) return 'AL';
      
      // Sergipe - menor estado do nordeste
      if (lat >= -11.6 && lat <= -9.5 && lng >= -38.2 && lng <= -36.4) return 'SE';
      
      // Bahia - maior estado do nordeste (coordenadas corrigidas)
      if (lat >= -18.5 && lat <= -8.5 && lng >= -46.8 && lng <= -37.1) return 'BA';
    }
    
    // Região Centro-Oeste
    if (lat >= -24.1 && lat <= -7.0 && lng >= -65.4 && lng <= -45.9) {
      // Mato Grosso - norte do centro-oeste
      if (lat >= -18.0 && lat <= -7.2 && lng >= -65.4 && lng <= -50.2) return 'MT';
      
      // Mato Grosso do Sul - sul do centro-oeste
      if (lat >= -24.1 && lat <= -17.8 && lng >= -58.2 && lng <= -50.8) return 'MS';
      
      // Goiás - leste do centro-oeste
      if (lat >= -19.9 && lat <= -12.2 && lng >= -53.2 && lng <= -45.9) return 'GO';
      
      // Distrito Federal - centro de Goiás
      if (lat >= -16.1 && lat <= -15.4 && lng >= -48.3 && lng <= -47.2) return 'DF';
    }
    
    // Região Sudeste
    if (lat >= -25.3 && lat <= -14.1 && lng >= -53.1 && lng <= -39.7) {
      // Minas Gerais - maior estado do sudeste
      if (lat >= -22.9 && lat <= -14.1 && lng >= -51.0 && lng <= -39.9) return 'MG';
      
      // São Paulo - sul do sudeste
      if (lat >= -25.3 && lat <= -19.8 && lng >= -53.1 && lng <= -44.2) return 'SP';
      
      // Rio de Janeiro - costa sudeste
      if (lat >= -23.4 && lat <= -20.8 && lng >= -45.0 && lng <= -40.9) return 'RJ';
      
      // Espírito Santo - costa nordeste do sudeste
      if (lat >= -21.3 && lat <= -17.9 && lng >= -41.9 && lng <= -39.7) return 'ES';
    }
    
    // Região Sul
    if (lat >= -33.8 && lat <= -22.4 && lng >= -57.6 && lng <= -48.0) {
      // Paraná - norte da região sul
      if (lat >= -26.7 && lat <= -22.4 && lng >= -54.6 && lng <= -48.0) return 'PR';
      
      // Santa Catarina - centro da região sul
      if (lat >= -29.4 && lat <= -25.9 && lng >= -53.8 && lng <= -48.3) return 'SC';
      
      // Rio Grande do Sul - extremo sul
      if (lat >= -33.8 && lat <= -27.1 && lng >= -57.6 && lng <= -49.7) return 'RS';
    }
    
    return 'XX'; // Estado desconhecido
  }

  static String getStateFromCoordinates(double lat, double lng) {
    return _getStateFromCoordinates(lat, lng);
  }
}

class ApplicatorStats {
  final int id;
  final String name;
  final int totalForms;
  final String lastActivity;
  final bool isActive;
  final String primaryLocation;
  final String? state;

  ApplicatorStats({
    required this.id,
    required this.name,
    required this.totalForms,
    required this.lastActivity,
    required this.isActive,
    required this.primaryLocation,
    this.state,
  });

  factory ApplicatorStats.fromJson(Map<String, dynamic> json) {
    return ApplicatorStats(
      id: json['id'] ?? 0,
      name: json['full_name'] ?? json['name'] ?? '',
      totalForms: json['total_forms'] ?? 0,
      lastActivity: json['last_activity_formatted'] ?? json['last_activity'] ?? '',
      isActive: json['is_active'] ?? json['status'] == 'active',
      primaryLocation: json['primary_location'] ?? '',
      state: json['state'],
    );
  }
}