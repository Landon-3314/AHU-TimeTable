import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CorruptRowDiagnosticCandidate {
  const CorruptRowDiagnosticCandidate({
    required this.sourceKey,
    required this.rawValue,
    required this.reason,
  });

  final String sourceKey;
  final String rawValue;
  final String reason;

  String get dedupeKey => '$sourceKey\u0000$rawValue';
}

class CorruptRowDiagnosticRecord {
  const CorruptRowDiagnosticRecord({
    required this.sourceKey,
    required this.rawValue,
    required this.reason,
    required this.detectedAt,
  });

  final String sourceKey;
  final String rawValue;
  final String reason;
  final DateTime detectedAt;

  String get dedupeKey => '$sourceKey\u0000$rawValue';

  Map<String, dynamic> toJson() {
    return {
      'sourceKey': sourceKey,
      'rawValue': rawValue,
      'reason': reason,
      'detectedAt': detectedAt.toUtc().toIso8601String(),
    };
  }

  factory CorruptRowDiagnosticRecord.fromJson(Map<String, dynamic> json) {
    final sourceKey = json['sourceKey'];
    final rawValue = json['rawValue'];
    final reason = json['reason'];
    final detectedAt = DateTime.tryParse('${json['detectedAt'] ?? ''}');
    if (sourceKey is! String ||
        rawValue is! String ||
        reason is! String ||
        detectedAt == null) {
      throw const FormatException('Invalid corrupt row diagnostic record');
    }
    return CorruptRowDiagnosticRecord(
      sourceKey: sourceKey,
      rawValue: rawValue,
      reason: reason,
      detectedAt: detectedAt.toUtc(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CorruptRowDiagnosticRecord &&
        other.sourceKey == sourceKey &&
        other.rawValue == rawValue &&
        other.reason == reason &&
        other.detectedAt == detectedAt;
  }

  @override
  int get hashCode => Object.hash(sourceKey, rawValue, reason, detectedAt);
}

class CorruptRowDiagnosticStore {
  CorruptRowDiagnosticStore({
    required SharedPreferences sharedPreferences,
    DateTime Function()? clock,
  }) : _sharedPreferences = sharedPreferences,
       _clock = clock ?? DateTime.now;

  static const String recordsKey = 'diagnostics.corruptRows.v1';
  static const String pendingCountKey =
      'diagnostics.corruptRowsPendingCount.v1';
  static const int _maxRecords = 100;

  final SharedPreferences _sharedPreferences;
  final DateTime Function() _clock;

  List<CorruptRowDiagnosticRecord> loadRecords() {
    final rawRecords = _sharedPreferences.getStringList(recordsKey);
    if (rawRecords == null) {
      return <CorruptRowDiagnosticRecord>[];
    }

    final result = <CorruptRowDiagnosticRecord>[];
    for (final raw in rawRecords) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          result.add(
            CorruptRowDiagnosticRecord.fromJson(
              Map<String, dynamic>.from(decoded),
            ),
          );
        }
      } catch (_) {
        // Keep diagnostics readable even if an older diagnostic entry is bad.
      }
    }
    return result;
  }

  Future<int> recordAll(Iterable<CorruptRowDiagnosticCandidate> rows) async {
    final records = loadRecords();
    final dedupeKeys = records.map((record) => record.dedupeKey).toSet();
    var addedCount = 0;
    for (final row in rows) {
      if (!dedupeKeys.add(row.dedupeKey)) {
        continue;
      }
      records.add(
        CorruptRowDiagnosticRecord(
          sourceKey: row.sourceKey,
          rawValue: row.rawValue,
          reason: row.reason,
          detectedAt: _clock().toUtc(),
        ),
      );
      addedCount += 1;
    }
    if (addedCount == 0) {
      return 0;
    }

    final retainedRecords = records.length <= _maxRecords
        ? records
        : records.sublist(records.length - _maxRecords);
    await _sharedPreferences.setStringList(
      recordsKey,
      retainedRecords.map((record) => jsonEncode(record.toJson())).toList(),
    );
    final pendingCount = _sharedPreferences.getInt(pendingCountKey) ?? 0;
    await _sharedPreferences.setInt(pendingCountKey, pendingCount + addedCount);
    return addedCount;
  }

  Future<int> consumePendingCount() async {
    final pendingCount = _sharedPreferences.getInt(pendingCountKey) ?? 0;
    await _sharedPreferences.remove(pendingCountKey);
    return pendingCount;
  }
}
