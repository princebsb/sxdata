import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/stats_provider.dart';
import '../providers/auth_provider.dart';

class StatsGraphsScreen extends StatefulWidget {
  const StatsGraphsScreen({super.key});

  @override
  State<StatsGraphsScreen> createState() => _StatsGraphsScreenState();
}

class _StatsGraphsScreenState extends State<StatsGraphsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = 'monthly';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadStats() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final statsProvider = Provider.of<StatsProvider>(context, listen: false);
    
    final userId = authProvider.user?.id;
    if (userId != null) {
      statsProvider.loadUserStats(userId);
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
                  const Column(
                    children: [
                      Text(
                        'Gráficos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Análise Visual',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                  Consumer<StatsProvider>(
                    builder: (context, statsProvider, child) {
                      return IconButton(
                        onPressed: statsProvider.isLoading ? null : _loadStats,
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

            // Tab Bar
            Container(
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
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF8fae5d),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF8fae5d),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.pie_chart),
                    text: 'Resumo',
                  ),
                  Tab(
                    icon: Icon(Icons.show_chart),
                    text: 'Tendências',
                  ),
                  Tab(
                    icon: Icon(Icons.bar_chart),
                    text: 'Comparativo',
                  ),
                ],
              ),
            ),

            // Conteúdo das abas
            Expanded(
              child: Consumer<StatsProvider>(
                builder: (context, statsProvider, child) {
                  if (statsProvider.isLoading && statsProvider.userStats == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8fae5d)),
                      ),
                    );
                  }

                  if (statsProvider.error != null && statsProvider.userStats == null) {
                    return _buildErrorState(statsProvider.error!);
                  }

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(statsProvider.userStats),
                      _buildTrendsTab(statsProvider.userStats),
                      _buildComparisonTab(statsProvider.userStats),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Erro ao carregar dados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8fae5d),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab(UserStats? userStats) {
    return RefreshIndicator(
      onRefresh: () async => _loadStats(),
      color: const Color(0xFF8fae5d),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Visão Geral',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF23345F),
              ),
            ),
            const SizedBox(height: 20),
            
            // Gráfico de Pizza - Distribuição de Formulários
            _buildPieChartCard(userStats),
            const SizedBox(height: 20),
            
            // Gráfico de Barras - Métricas Principais
            _buildMainMetricsChart(userStats),
            const SizedBox(height: 20),
            
            // Card de Taxa de Sucesso
            _buildSuccessRateCard(userStats),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab(UserStats? userStats) {
    return RefreshIndicator(
      onRefresh: () async => _loadStats(),
      color: const Color(0xFF8fae5d),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tendências',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF23345F),
                  ),
                ),
                _buildPeriodSelector(),
              ],
            ),
            const SizedBox(height: 20),
            
            // Gráfico de Linha - Formulários por Período
            _buildLineChart(userStats),
            const SizedBox(height: 20),
            
            // Estatísticas de Período
            _buildPeriodStats(userStats),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonTab(UserStats? userStats) {
    return RefreshIndicator(
      onRefresh: () async => _loadStats(),
      color: const Color(0xFF8fae5d),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Comparativo',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF23345F),
              ),
            ),
            const SizedBox(height: 20),
            
            // Gráfico de Barras Horizontal - Top Questionários
            _buildTopQuestionnairesChart(userStats),
            const SizedBox(height: 20),
            
            // Comparativo Semanal vs Mensal
            _buildWeeklyVsMonthlyChart(userStats),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartCard(UserStats? userStats) {
    final summary = userStats?.summary;
    
    return Container(
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
          const Text(
            'Distribuição de Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 60,
                sections: [
                  PieChartSectionData(
                    color: const Color(0xFF8fae5d),
                    value: (summary?.totalForms ?? 1).toDouble() - (summary?.pendingSync ?? 0).toDouble(),
                    title: '',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.orange,
                    value: (summary?.pendingSync ?? 0).toDouble(),
                    title: 'Pendentes',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem('Sincronizados', const Color(0xFF8fae5d), 
                  (summary?.totalForms ?? 0) - (summary?.pendingSync ?? 0)),
              _buildLegendItem('Pendentes', Colors.orange, summary?.pendingSync ?? 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainMetricsChart(UserStats? userStats) {
    final summary = userStats?.summary;
    
    return Container(
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
          const Text(
            'Métricas Principais',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (summary?.totalForms ?? 10).toDouble() * 1.2,
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Total', style: TextStyle(fontSize: 10));
                          case 1:
                            return const Text('Hoje', style: TextStyle(fontSize: 10));
                          case 2:
                            return const Text('Fotos', style: TextStyle(fontSize: 10));
                          case 3:
                            return const Text('Dias', style: TextStyle(fontSize: 10));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: (summary?.totalForms ?? 0).toDouble(),
                        color: const Color(0xFF8fae5d),
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: (summary?.todayForms ?? 0).toDouble(),
                        color: Colors.blue,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: (summary?.photosCaptured ?? 0).toDouble(),
                        color: Colors.purple,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(
                        toY: (summary?.activeDays ?? 0).toDouble(),
                        color: Colors.indigo,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessRateCard(UserStats? userStats) {
    final successRate = userStats?.summary.successRate ?? 0;
    
    return Container(
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
          const Text(
            'Taxa de Sucesso',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: successRate / 100,
                  strokeWidth: 8,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    successRate >= 90 ? Colors.green :
                    successRate >= 70 ? Colors.orange : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 30),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$successRate%',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: successRate >= 90 ? Colors.green :
                             successRate >= 70 ? Colors.orange : Colors.red,
                    ),
                  ),
                  Text(
                    _getSuccessRateDescription(successRate),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart(UserStats? userStats) {
    return Container(
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
          Text(
            'Formulários - ${_selectedPeriod == 'weekly' ? 'Últimos 7 dias' : 'Últimos 30 dias'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateDummyLineData(),
                    isCurved: true,
                    color: const Color(0xFF8fae5d),
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF8fae5d).withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStats(UserStats? userStats) {
    final weeklyStats = userStats?.periodStats.weekly;
    final monthlyStats = userStats?.periodStats.monthly;
    
    // Usando tipagem dinâmica para evitar problemas de cast
    final currentStats = _selectedPeriod == 'weekly' ? weeklyStats : monthlyStats;
    
    return Container(
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
          Text(
            'Estatísticas ${_selectedPeriod == 'weekly' ? 'Semanais' : 'Mensais'}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total',
                  '${_getTotalForms(currentStats)}',
                  Icons.assignment,
                  const Color(0xFF8fae5d),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Média/Dia',
                  _getAvgPerDay(currentStats),
                  Icons.timeline,
                  Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Fotos',
                  '${_getPhotosCaptured(currentStats)}',
                  Icons.camera_alt,
                  Colors.purple,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Localizações',
                  '${_getLocationsCaptured(currentStats)}',
                  Icons.location_on,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares para acessar propriedades de forma segura
  int _getTotalForms(dynamic stats) {
    if (stats == null) return 0;
    return stats.totalForms ?? 0;
  }

  String _getAvgPerDay(dynamic stats) {
    if (stats == null) return '0.0';
    final avgPerDay = stats.avgPerDay ?? 0.0;
    return avgPerDay.toStringAsFixed(1);
  }

  int _getPhotosCaptured(dynamic stats) {
    if (stats == null) return 0;
    return stats.photosCaptured ?? 0;
  }

  int _getLocationsCaptured(dynamic stats) {
    if (stats == null) return 0;
    return stats.locationsCaptured ?? 0;
  }

  Widget _buildTopQuestionnairesChart(UserStats? userStats) {
    final topQuestionnaires = userStats?.topQuestionnaires ?? [];
    
    return Container(
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
          const Text(
            'Questionários Mais Aplicados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 20),
          if (topQuestionnaires.isEmpty)
            const Center(
              child: Text(
                'Nenhum questionário aplicado ainda',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...topQuestionnaires.take(5).map((questionnaire) => 
              _buildQuestionnaireBar(questionnaire)
            ),
        ],
      ),
    );
  }

  Widget _buildWeeklyVsMonthlyChart(UserStats? userStats) {
    final weeklyStats = userStats?.periodStats.weekly;
    final monthlyStats = userStats?.periodStats.monthly;
    
    // Valor máximo para escala do gráfico
    final maxValue = [
      _getTotalForms(weeklyStats),
      _getTotalForms(monthlyStats),
      _getPhotosCaptured(weeklyStats),
      _getPhotosCaptured(monthlyStats),
      _getLocationsCaptured(weeklyStats),
      _getLocationsCaptured(monthlyStats),
    ].reduce((a, b) => a > b ? a : b).toDouble();
    
    return Container(
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
          const Text(
            'Comparativo Períodos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: (maxValue * 1.2),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        switch (value.toInt()) {
                          case 0:
                            return const Text('Formulários', style: TextStyle(fontSize: 10));
                          case 1:
                            return const Text('Fotos', style: TextStyle(fontSize: 10));
                          case 2:
                            return const Text('Localizações', style: TextStyle(fontSize: 10));
                          default:
                            return const Text('');
                        }
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: _getTotalForms(weeklyStats).toDouble(),
                        color: Colors.blue,
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: _getTotalForms(monthlyStats).toDouble(),
                        color: const Color(0xFF8fae5d),
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: _getPhotosCaptured(weeklyStats).toDouble(),
                        color: Colors.blue,
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: _getPhotosCaptured(monthlyStats).toDouble(),
                        color: const Color(0xFF8fae5d),
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(
                        toY: _getLocationsCaptured(weeklyStats).toDouble(),
                        color: Colors.blue,
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: _getLocationsCaptured(monthlyStats).toDouble(),
                        color: const Color(0xFF8fae5d),
                        width: 15,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Semanal', Colors.blue, 0),
              const SizedBox(width: 20),
              _buildLegendItem('Mensal', const Color(0xFF8fae5d), 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          onChanged: (value) {
            setState(() {
              _selectedPeriod = value!;
            });
          },
          items: const [
            DropdownMenuItem(value: 'weekly', child: Text('Semanal')),
            DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        if (value > 0) ...[
          const SizedBox(width: 4),
          Text(
            '($value)',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaireBar(TopQuestionnaire questionnaire) {
    const maxApplications = 50; // Valor máximo para normalizar a barra
    final percentage = (questionnaire.totalApplications / maxApplications).clamp(0.0, 1.0);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  questionnaire.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF23345F),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${questionnaire.totalApplications}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8fae5d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF8fae5d),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            questionnaire.lastApplicationTime,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  String _getSuccessRateDescription(int rate) {
    if (rate >= 95) return 'Excelente!';
    if (rate >= 90) return 'Muito Bom';
    if (rate >= 80) return 'Bom';
    if (rate >= 70) return 'Regular';
    return 'Precisa Melhorar';
  }

  List<FlSpot> _generateDummyLineData() {
    // Gerar dados dummy para demonstração
    // Em produção, isso viria dos dados reais da API
    if (_selectedPeriod == 'weekly') {
      return [
        const FlSpot(1, 3),
        const FlSpot(2, 7),
        const FlSpot(3, 5),
        const FlSpot(4, 12),
        const FlSpot(5, 8),
        const FlSpot(6, 15),
        const FlSpot(7, 10),
      ];
    } else {
      return List.generate(15, (index) {
        return FlSpot(
          (index + 1).toDouble(),
          (5 + (index * 2) + (index % 3 == 0 ? 5 : 0)).toDouble(),
        );
      });
    }
  }
}