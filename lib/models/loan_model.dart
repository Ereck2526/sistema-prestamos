class Loan {
  final String id;
  final String clientId;
  final double originalPrincipal;
  final double interestRate;
  final String paymentFrequency;
  final DateTime? startDate;
  final String status;

  Loan({
    required this.id,
    required this.clientId,
    required this.originalPrincipal,
    required this.interestRate,
    required this.paymentFrequency,
    this.startDate,
    required this.status,
  });

  factory Loan.fromJson(Map<String, dynamic> json) {
    return Loan(
      id: json['id'],
      clientId: json['client_id'],
      originalPrincipal: (json['original_principal'] ?? 0).toDouble(),
      interestRate: (json['interest_rate'] ?? 0).toDouble(),
      paymentFrequency: json['payment_frequency'] ?? 'Mensual',
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      status: json['status'] ?? 'active',
    );
  }
}
