class Consumer {
  final String accountNo;
  final String barangay;
  final String street;
  final String consumerType;
  final String meterNo;
  final int lastReading;
  final String status;

  const Consumer({
    required this.accountNo,
    required this.barangay,
    required this.street,
    required this.consumerType,
    required this.meterNo,
    required this.lastReading,
    this.status = 'Active',
  });

  bool get isActive => status == 'Active';
}
