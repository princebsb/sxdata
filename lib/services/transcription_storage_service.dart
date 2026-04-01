import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_api_service.dart';

/// Registro de uma transcrição de áudio feita durante o preenchimento.
class TranscriptionRecord {
  final String id;
  final int questionnaireId;
  final int questionId;
  final String questionText;
  final String transcribedText;
  final String? editedText;
  final double? confidence;
  final String? language;
  final int? durationMs;
  final int recordingDurationSecs;
  final String? applicatorName;
  final int? applicatorId;
  final String timestamp;
  final String syncStatus; // 'pending' | 'synced'

  TranscriptionRecord({
    required this.id,
    required this.questionnaireId,
    required this.questionId,
    required this.questionText,
    required this.transcribedText,
    this.editedText,
    this.confidence,
    this.language,
    this.durationMs,
    this.recordingDurationSecs = 0,
    this.applicatorName,
    this.applicatorId,
    String? timestamp,
    this.syncStatus = 'pending',
  }) : timestamp = timestamp ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toJson() => {
        'id': id,
        'questionnaire_id': questionnaireId,
        'question_id': questionId,
        'question_text': questionText,
        'transcribed_text': transcribedText,
        'edited_text': editedText,
        'confidence': confidence,
        'language': language,
        'duration_ms': durationMs,
        'recording_duration_secs': recordingDurationSecs,
        'applicator_name': applicatorName,
        'applicator_id': applicatorId,
        'timestamp': timestamp,
        'sync_status': syncStatus,
      };

  factory TranscriptionRecord.fromJson(Map<String, dynamic> json) {
    return TranscriptionRecord(
      id: json['id']?.toString() ?? '',
      questionnaireId: json['questionnaire_id'] is int
          ? json['questionnaire_id']
          : int.tryParse(json['questionnaire_id']?.toString() ?? '') ?? 0,
      questionId: json['question_id'] is int
          ? json['question_id']
          : int.tryParse(json['question_id']?.toString() ?? '') ?? 0,
      questionText: json['question_text']?.toString() ?? '',
      transcribedText: json['transcribed_text']?.toString() ?? '',
      editedText: json['edited_text']?.toString(),
      confidence: json['confidence'] is num
          ? (json['confidence'] as num).toDouble()
          : null,
      language: json['language']?.toString(),
      durationMs:
          json['duration_ms'] is int ? json['duration_ms'] : null,
      recordingDurationSecs: json['recording_duration_secs'] is int
          ? json['recording_duration_secs']
          : 0,
      applicatorName: json['applicator_name']?.toString(),
      applicatorId: json['applicator_id'] is int
          ? json['applicator_id']
          : int.tryParse(json['applicator_id']?.toString() ?? ''),
      timestamp: json['timestamp']?.toString(),
      syncStatus: json['sync_status']?.toString() ?? 'pending',
    );
  }

  TranscriptionRecord copyWith({String? syncStatus, String? editedText}) {
    return TranscriptionRecord(
      id: id,
      questionnaireId: questionnaireId,
      questionId: questionId,
      questionText: questionText,
      transcribedText: transcribedText,
      editedText: editedText ?? this.editedText,
      confidence: confidence,
      language: language,
      durationMs: durationMs,
      recordingDurationSecs: recordingDurationSecs,
      applicatorName: applicatorName,
      applicatorId: applicatorId,
      timestamp: timestamp,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }
}

/// Serviço para armazenar e sincronizar transcrições de áudio.
/// Segue o mesmo padrão offline-first do AiAuditService.
class TranscriptionStorageService {
  static const String _storageKey = 'audio_transcriptions';
  static const int _maxRecords = 200;

  /// Salva uma transcrição localmente.
  static Future<void> save(TranscriptionRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await _loadAll(prefs);

      records.add(record);

      // Limitar tamanho — remove os mais antigos já sincronizados primeiro
      if (records.length > _maxRecords) {
        records.removeWhere((r) => r.syncStatus == 'synced');
        if (records.length > _maxRecords) {
          records.removeRange(0, records.length - _maxRecords);
        }
      }

      await _saveAll(prefs, records);
    } catch (e) {
      print('⚠️ Erro ao salvar transcrição localmente: $e');
    }
  }

  /// Retorna todas as transcrições pendentes de sincronização.
  static Future<List<TranscriptionRecord>> getPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await _loadAll(prefs);
      return records.where((r) => r.syncStatus == 'pending').toList();
    } catch (_) {
      return [];
    }
  }

  /// Conta as transcrições pendentes.
  static Future<int> getPendingCount() async {
    final pending = await getPending();
    return pending.length;
  }

  /// Sincroniza transcrições pendentes com o backend.
  /// Retorna quantas foram sincronizadas com sucesso.
  static Future<int> syncPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final records = await _loadAll(prefs);
      final pending =
          records.where((r) => r.syncStatus == 'pending').toList();

      if (pending.isEmpty) return 0;

      // Envia em batch para o backend
      final payload = pending.map((r) => r.toJson()).toList();
      await AiApiService.syncTranscriptions(payload);

      // Marca como sincronizadas
      final updatedRecords = records.map((r) {
        if (r.syncStatus == 'pending') {
          return r.copyWith(syncStatus: 'synced');
        }
        return r;
      }).toList();

      await _saveAll(prefs, updatedRecords);
      return pending.length;
    } catch (e) {
      print('⚠️ Erro ao sincronizar transcrições: $e');
      return 0;
    }
  }

  static Future<List<TranscriptionRecord>> _loadAll(
      SharedPreferences prefs) async {
    final json = prefs.getString(_storageKey);
    if (json == null) return [];
    try {
      return (jsonDecode(json) as List<dynamic>)
          .map((e) =>
              TranscriptionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveAll(
      SharedPreferences prefs, List<TranscriptionRecord> records) async {
    await prefs.setString(
      _storageKey,
      jsonEncode(records.map((r) => r.toJson()).toList()),
    );
  }
}
