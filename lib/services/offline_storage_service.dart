import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:aquis_rm_flutter/models/consumer.dart';
import 'package:aquis_rm_flutter/models/reading_record.dart';

class OfflineStorageService {
  static const _storage = FlutterSecureStorage();
  static const _readingsKey = 'offline_readings';

  static Future<String> get _localPath async {
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  static Future<String> _savePhotoLocal(File photo, String readingId) async {
    final path = await _localPath;
    final ext = photo.path.split('.').last;
    final localFile = File('$path/reading_$readingId.$ext');
    await photo.copy(localFile.path);
    return localFile.path;
  }

  static Future<void> saveReading({
    required ReadingRecordMobile record,
    File? photo,
  }) async {
    String? localPhotoPath;
    if (photo != null) {
      localPhotoPath = await _savePhotoLocal(photo, record.id);
    }

    final savedRecord = ReadingRecordMobile(
      id: record.id,
      accountNo: record.accountNo,
      consumer: record.consumer,
      previousReading: record.previousReading,
      presentReading: record.presentReading,
      consumption: record.consumption,
      time: record.time,
      date: record.date,
      syncStatus: SyncStatus.pending,
      photoPath: localPhotoPath ?? record.photoPath,
      rejectionReason: record.rejectionReason,
      attempts: record.attempts,
      recordedByUserId: record.recordedByUserId,
      recordedByName: record.recordedByName,
    );

    final existing = await getOfflineReadings();
    existing.add(savedRecord);
    await _saveReadingsList(existing, _readingsKey);
  }

  static Future<List<ReadingRecordMobile>> getOfflineReadings() async {
    final json = await _storage.read(key: _readingsKey);
    if (json == null || json.isEmpty) return [];
    final List<dynamic> decoded = jsonDecode(json);
    return decoded.map((e) => _fromJson(e)).toList();
  }

  static Future<List<ReadingRecordMobile>> getPendingReadings() async {
    final all = await getOfflineReadings();
    return all.where((r) => r.isPending || r.isFailed).toList();
  }

  static Future<void> markAsSynced(String readingId) async {
    final readings = await getOfflineReadings();
    final idx = readings.indexWhere((r) => r.id == readingId);
    if (idx != -1) {
      readings[idx] = readings[idx].copyWith(syncStatus: SyncStatus.synced);
      await _saveReadingsList(readings, _readingsKey);
    }
  }

  static Future<void> markAsNeedsCorrection(String readingId, String message) async {
    final readings = await getOfflineReadings();
    final idx = readings.indexWhere((r) => r.id == readingId);
    if (idx != -1) {
      readings[idx] = readings[idx].copyWith(
        syncStatus: SyncStatus.needsCorrection,
        rejectionReason: message,
      );
      await _saveReadingsList(readings, _readingsKey);
    }
  }

  static Future<void> removeReading(String readingId) async {
    final readings = await getOfflineReadings();
    readings.removeWhere((r) => r.id == readingId);
    await _saveReadingsList(readings, _readingsKey);
  }

  static Future<int> get pendingCount async {
    final pending = await getPendingReadings();
    return pending.length;
  }

  static Future<void> _saveReadingsList(List<ReadingRecordMobile> readings, String key) async {
    final json = jsonEncode(readings.map((r) => _toJson(r)).toList());
    await _storage.write(key: key, value: json);
  }

  static Map<String, dynamic> _toJson(ReadingRecordMobile r) {
    return {
      'id': r.id,
      'accountNo': r.accountNo,
      'consumerAccountNo': r.consumer.accountNo,
      'consumerBarangay': r.consumer.barangay,
      'consumerStreet': r.consumer.street,
      'consumerType': r.consumer.consumerType,
      'consumerMeterNo': r.consumer.meterNo,
      'consumerLastReading': r.consumer.lastReading,
      'consumerStatus': r.consumer.status,
      'previousReading': r.previousReading,
      'presentReading': r.presentReading,
      'consumption': r.consumption,
      'time': r.time,
      'date': r.date?.toIso8601String(),
      'syncStatus': r.syncStatus.index,
      'photoPath': r.photoPath,
      'rejectionReason': r.rejectionReason,
      'attempts': r.attempts,
      'recordedByUserId': r.recordedByUserId,
      'recordedByName': r.recordedByName,
    };
  }

  static ReadingRecordMobile _fromJson(Map<String, dynamic> json) {
    final consumer = Consumer(
      accountNo: json['consumerAccountNo'] ?? '',
      barangay: json['consumerBarangay'] ?? '',
      street: json['consumerStreet'] ?? '',
      consumerType: json['consumerType'] ?? 'Residential',
      meterNo: json['consumerMeterNo'] ?? '',
      lastReading: json['consumerLastReading'] ?? 0,
      status: json['consumerStatus'] ?? 'Active',
    );
    return ReadingRecordMobile(
      id: json['id'] ?? '',
      accountNo: json['accountNo'] ?? '',
      consumer: consumer,
      previousReading: json['previousReading'] ?? 0,
      presentReading: json['presentReading'] ?? 0,
      consumption: json['consumption'] ?? 0,
      time: json['time'] ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      syncStatus: SyncStatus.values[json['syncStatus'] ?? 0],
      photoPath: json['photoPath'],
      rejectionReason: json['rejectionReason'],
      attempts: json['attempts'] ?? 1,
      recordedByUserId: json['recordedByUserId'] ?? '',
      recordedByName: json['recordedByName'] ?? '',
    );
  }
}
