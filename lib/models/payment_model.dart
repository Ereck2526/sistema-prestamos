class Payment {
  final String id;
  final String loanId;
  final DateTime paymentDate;
  final double principalPaid;
  final double interestPaid;
  final String? notes;

  Payment({
    required this.id,
    required this.loanId,
    required this.paymentDate,
    required this.principalPaid,
    required this.interestPaid,
    this.notes,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      loanId: json['loan_id'],
      paymentDate: DateTime.parse(json['payment_date']).toLocal(),
      principalPaid: (json['principal_paid'] ?? 0).toDouble(),
      interestPaid: (json['interest_paid'] ?? 0).toDouble(),
      notes: json['notes'],
    );
  }
}
