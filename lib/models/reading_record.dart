import 'consumer.dart';

enum SyncStatus {
  synced,
  pending,
  needsCorrection,
  failed,
}

class ReadingRecordMobile {
  final String id;
  final String accountNo;
  final Consumer consumer;
  final int previousReading;
  final int presentReading;
  final int consumption;
  final String time;
  final DateTime? date;
  final SyncStatus syncStatus;
  final String? photoPath;
  final String? rejectionReason;
  final int attempts;
  final String recordedByUserId;
  final String recordedByName;

  const ReadingRecordMobile({
    required this.id,
    required this.accountNo,
    required this.consumer,
    required this.previousReading,
    required this.presentReading,
    required this.consumption,
    required this.time,
    this.date,
    required this.syncStatus,
    this.photoPath,
    this.rejectionReason,
    this.attempts = 1,
    this.recordedByUserId = '',
    this.recordedByName = '',
  });

  bool get isSynced => syncStatus == SyncStatus.synced;
  bool get isPending => syncStatus == SyncStatus.pending;
  bool get needsCorrection => syncStatus == SyncStatus.needsCorrection;
  bool get isFailed => syncStatus == SyncStatus.failed;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get dateLabel {
    final d = date;
    if (d == null) return '';
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }

  String get recordedAt => date == null ? time : '$dateLabel \u00B7 $time';

  String get timestamp {
    final d = date;
    if (d == null) return time;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day $time';
  }

  ReadingRecordMobile copyWith({
    int? presentReading,
    SyncStatus? syncStatus,
    String? photoPath,
    String? rejectionReason,
    int? attempts,
  }) {
    final newPresent = presentReading ?? this.presentReading;
    return ReadingRecordMobile(
      id: id,
      accountNo: accountNo,
      consumer: consumer,
      previousReading: previousReading,
      presentReading: newPresent,
      consumption: newPresent - previousReading,
      time: time,
      date: date,
      syncStatus: syncStatus ?? this.syncStatus,
      photoPath: photoPath ?? this.photoPath,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      attempts: attempts ?? this.attempts,
      recordedByUserId: recordedByUserId,
      recordedByName: recordedByName,
    );
  }
}
