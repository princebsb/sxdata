import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stats_provider.dart';
import '../providers/auth_provider.dart'; // Assumindo que existe para obter o userId

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStats();
    });
  }

  void _loadStats() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final statsProvider = Provider.of<StatsProvider>(context, listen: false);
    
    // Assumindo que você tem o userId no authProvider
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
                  // Botão voltar
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  // Logo centralizado
                  Image.asset(
                    'assets/images/Logo_verde2.png',
                    width: 120,             
                    fit: BoxFit.contain,
                  ),
                  // Ícone de refresh
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
                            'Erro ao carregar estatísticas',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            statsProvider.error!,
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

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Suas Estatísticas',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF23345F),
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  'Desempenho de coleta de dados',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            if (statsProvider.lastUpdated != null)
                              Text(
                                'Atualizado: ${_formatLastUpdate(statsProvider.lastUpdated!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async => _loadStats(),
                            color: const Color(0xFF8fae5d),
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                children: [
                                  _buildStatsGrid(statsProvider.userStats),
                                  const SizedBox(height: 30),
                                  _buildRecentActivity(statsProvider.userStats),
                                ],
                              ),
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
      ),
    );
  }

  Widget _buildStatsGrid(UserStats? userStats) {
    final summary = userStats?.summary;
    
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '${summary?.totalForms ?? 0}', 
                'Total de\nFormulários', 
                const Color(0xFF8fae5d)
              )
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                '${summary?.todayForms ?? 0}', 
                'Aplicados\nHoje', 
                Colors.blue
              )
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '${summary?.pendingSync ?? 0}', 
                'Pendentes\nSync', 
                Colors.orange
              )
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                '${summary?.successRate ?? 0}%', 
                'Taxa de\nSucesso', 
                Colors.green
              )
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                '${summary?.activeDays ?? 0}', 
                'Dias\nAtivos', 
                Colors.purple
              )
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildStatCard(
                '${summary?.photosCaptured ?? 0}', 
                'Fotos\nCapturadas', 
                Colors.indigo
              )
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String number, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
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
          Text(
            number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity(UserStats? userStats) {
    final activities = userStats?.recentActivity ?? [];
    
    return Container(
      width: double.infinity,
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
            'Atividade Recente',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF23345F),
            ),
          ),
          const SizedBox(height: 15),
          if (activities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'Nenhuma atividade recente',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          else
            ...activities.take(4).map((activity) => 
              _buildActivityItem(
                activity.action,
                activity.description,
                activity.time,
                _getSyncStatusColor(activity.syncStatus),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String action, String description, String time, Color statusColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF23345F),
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSyncStatusColor(String syncStatus) {
    switch (syncStatus.toLowerCase()) {
      case 'synced':
        return const Color(0xFF8fae5d);
      case 'pending':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatLastUpdate(DateTime lastUpdate) {
    final now = DateTime.now();
    final difference = now.difference(lastUpdate);
    
    if (difference.inMinutes < 1) {
      return 'agora';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m atrás';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h atrás';
    } else {
      return '${difference.inDays}d atrás';
    }
  }
}