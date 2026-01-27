// stats_models.dart - Arquivo separado com todos os modelos corrigidos

/// Interface comum para estatísticas de período
abstract class PeriodStatsBase {
  int get totalForms;
  int get photosCaptured;
  int get locationsCaptured;
  double get avgPerDay;
  int get periodDays;
}

/// Modelo para estatísticas do usuário
class UserStats {
  final int userId;
  final StatsSummary summary;
  final List<RecentActivity> recentActivity;
  final PeriodStats periodStats;
  final List<TopQuestionnaire> topQuestionnaires;
  final DateTime updatedAt;

  UserStats({
    required this.userId,
    required this.summary,
    required this.recentActivity,
    required this.periodStats,
    required this.topQuestionnaires,
    required this.updatedAt,
  });

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      userId: json['user_id'] ?? 0,
      summary: StatsSummary.fromJson(json['summary'] ?? {}),
      recentActivity: (json['recent_activity'] as List<dynamic>? ?? [])
          .map((activity) => RecentActivity.fromJson(activity))
          .toList(),
      periodStats: PeriodStats.fromJson(json['period_stats'] ?? {}),
      topQuestionnaires: (json['top_questionnaires'] as List<dynamic>? ?? [])
          .map((q) => TopQuestionnaire.fromJson(q))
          .toList(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Modelo para resumo de estatísticas
class StatsSummary {
  final int totalForms;
  final int todayForms;
  final int pendingSync;
  final int successRate;
  final int activeDays;
  final int photosCaptured;

  StatsSummary({
    required this.totalForms,
    required this.todayForms,
    required this.pendingSync,
    required this.successRate,
    required this.activeDays,
    required this.photosCaptured,
  });

  factory StatsSummary.fromJson(Map<String, dynamic> json) {
    return StatsSummary(
      totalForms: json['total_forms'] ?? 0,
      todayForms: json['today_forms'] ?? 0,
      pendingSync: json['pending_sync'] ?? 0,
      successRate: json['success_rate'] ?? 0,
      activeDays: json['active_days'] ?? 0,
      photosCaptured: json['photos_captured'] ?? 0,
    );
  }
}

/// Modelo para atividade recente
class RecentActivity {
  final int id;
  final String action;
  final String description;
  final String time;
  final String syncStatus;
  final String? respondentName;

  RecentActivity({
    required this.id,
    required this.action,
    required this.description,
    required this.time,
    required this.syncStatus,
    this.respondentName,
  });

  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] ?? 0,
      action: json['action'] ?? '',
      description: json['description'] ?? '',
      time: json['time'] ?? '',
      syncStatus: json['sync_status'] ?? '',
      respondentName: json['respondent_name'],
    );
  }
}

/// Modelo para estatísticas de período
class PeriodStats {
  final WeeklyStats weekly;
  final MonthlyStats monthly;

  PeriodStats({
    required this.weekly,
    required this.monthly,
  });

  factory PeriodStats.fromJson(Map<String, dynamic> json) {
    return PeriodStats(
      weekly: WeeklyStats.fromJson(json['weekly'] ?? {}),
      monthly: MonthlyStats.fromJson(json['monthly'] ?? {}),
    );
  }
}

/// Modelo para estatísticas semanais
class WeeklyStats implements PeriodStatsBase {
  @override
  final int totalForms;
  @override
  final int photosCaptured;
  @override
  final int locationsCaptured;
  @override
  final double avgPerDay;
  @override
  final int periodDays;

  WeeklyStats({
    required this.totalForms,
    required this.photosCaptured,
    required this.locationsCaptured,
    required this.avgPerDay,
    required this.periodDays,
  });

  factory WeeklyStats.fromJson(Map<String, dynamic> json) {
    return WeeklyStats(
      totalForms: json['total_forms'] ?? 0,
      photosCaptured: json['photos_captured'] ?? 0,
      locationsCaptured: json['locations_captured'] ?? 0,
      avgPerDay: (json['avg_per_day'] ?? 0).toDouble(),
      periodDays: json['period_days'] ?? 0,
    );
  }
}

/// Modelo para estatísticas mensais
class MonthlyStats implements PeriodStatsBase {
  @override
  final int totalForms;
  @override
  final int photosCaptured;
  @override
  final int locationsCaptured;
  @override
  final double avgPerDay;
  @override
  final int periodDays;

  MonthlyStats({
    required this.totalForms,
    required this.photosCaptured,
    required this.locationsCaptured,
    required this.avgPerDay,
    required this.periodDays,
  });

  factory MonthlyStats.fromJson(Map<String, dynamic> json) {
    return MonthlyStats(
      totalForms: json['total_forms'] ?? 0,
      photosCaptured: json['photos_captured'] ?? 0,
      locationsCaptured: json['locations_captured'] ?? 0,
      avgPerDay: (json['avg_per_day'] ?? 0).toDouble(),
      periodDays: json['period_days'] ?? 0,
    );
  }
}

/// Modelo para questionários mais aplicados
class TopQuestionnaire {
  final int id;
  final String title;
  final int totalApplications;
  final String? lastApplication;
  final String lastApplicationTime;

  TopQuestionnaire({
    required this.id,
    required this.title,
    required this.totalApplications,
    this.lastApplication,
    required this.lastApplicationTime,
  });

  factory TopQuestionnaire.fromJson(Map<String, dynamic> json) {
    return TopQuestionnaire(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      totalApplications: json['total_applications'] ?? 0,
      lastApplication: json['last_application'],
      lastApplicationTime: json['last_application_time'] ?? '',
    );
  }
}