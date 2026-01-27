import 'question_response.dart';

class FormResponse {
  final int? id;
  final int questionnaireId;
  final String? respondentName;
  final String? respondentEmail;
  final int appliedBy;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final String? photoPath;
  final String? photoPath2;
  final bool consentGiven;
  final String syncStatus;
  final DateTime startedAt;
  final DateTime? completedAt;
  final DateTime? editedAt;
  final List<QuestionResponse> responses;

  FormResponse({
    this.id,
    required this.questionnaireId,
    this.respondentName,
    this.respondentEmail,
    required this.appliedBy,
    this.latitude,
    this.longitude,
    this.locationName,
    this.photoPath,
    this.photoPath2,
    required this.consentGiven,
    this.syncStatus = 'pending',
    required this.startedAt,
    this.completedAt,
    this.editedAt,
    this.responses = const [],
  });

  // Método copyWith para facilitar atualizações
  FormResponse copyWith({
    int? id,
    int? questionnaireId,
    String? respondentName,
    String? respondentEmail,
    int? appliedBy,
    double? latitude,
    double? longitude,
    String? locationName,
    String? photoPath,
    String? photoPath2,
    bool? consentGiven,
    String? syncStatus,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? editedAt,
    List<QuestionResponse>? responses,
  }) {
    return FormResponse(
      id: id ?? this.id,
      questionnaireId: questionnaireId ?? this.questionnaireId,
      respondentName: respondentName ?? this.respondentName,
      respondentEmail: respondentEmail ?? this.respondentEmail,
      appliedBy: appliedBy ?? this.appliedBy,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      photoPath: photoPath ?? this.photoPath,
      photoPath2: photoPath2 ?? this.photoPath2,
      consentGiven: consentGiven ?? this.consentGiven,
      syncStatus: syncStatus ?? this.syncStatus,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      editedAt: editedAt ?? this.editedAt,
      responses: responses ?? this.responses,
    );
  }

  factory FormResponse.fromJson(Map<String, dynamic> json) {
    try {
      return FormResponse(
        id: json['id'] as int?,
        questionnaireId: json['questionnaire_id'] as int,
        respondentName: json['respondent_name'] as String?,
        respondentEmail: json['respondent_email'] as String?,
        appliedBy: json['applied_by'] as int,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        locationName: json['location_name'] as String?,
        photoPath: json['photo_path'] as String?,
        photoPath2: json['photo_path_2'] as String?,
        consentGiven: json['consent_given'] as bool? ?? false,
        syncStatus: json['sync_status'] as String? ?? 'pending',
        startedAt: DateTime.parse(json['started_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        editedAt: json['edited_at'] != null
            ? DateTime.parse(json['edited_at'] as String)
            : null,
        responses: (json['responses'] as List<dynamic>?)
            ?.map((r) => QuestionResponse.fromJson(r as Map<String, dynamic>))
            .toList() ?? [],
      );
    } catch (e, stackTrace) {
      print('❌ Erro ao parsear FormResponse: $e');
      print('📋 JSON: $json');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    try {
      return {
        if (id != null) 'id': id,
        'questionnaire_id': questionnaireId,
        'respondent_name': respondentName,
        'respondent_email': respondentEmail,
        'applied_by': appliedBy,
        'latitude': latitude,
        'longitude': longitude,
        'location_name': locationName,
        'photo_path': photoPath,
        'photo_path_2': photoPath2,
        'consent_given': consentGiven,
        'sync_status': syncStatus,
        'started_at': startedAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'edited_at': editedAt?.toIso8601String(),
        'responses': responses.map((r) => r.toJson()).toList(),
      };
    } catch (e, stackTrace) {
      print('❌ Erro ao serializar FormResponse: $e');
      print('📋 Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  String toString() {
    return 'FormResponse{id: $id, questionnaireId: $questionnaireId, appliedBy: $appliedBy, responses: ${responses.length}, syncStatus: $syncStatus}';
  }
}