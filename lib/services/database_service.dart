import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../models/loan_model.dart';
import '../models/payment_model.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================
  // CLIENTES
  // ==========================
  Future<List<Client>> fetchClients() async {
    final response = await _supabase.from('clients').select().order('name', ascending: true);
    return response.map((json) => Client.fromJson(json)).toList();
  }

  Future<void> createClient({required String name, String? phone, String? alias}) async {
    await _supabase.from('clients').insert({
      'name': name,
      'phone': phone,
      'alias': alias,
    });
  }

  Future<void> updateClient({required String id, required String name, String? phone, String? alias}) async {
    final Map<String, dynamic> data = {
      'name': name,
      'phone': phone,
    };
    if (alias != null) data['alias'] = alias;
    await _supabase.from('clients').update(data).eq('id', id);
  }

  Future<void> deleteClient(String id) async {
    await _supabase.from('clients').delete().eq('id', id);
  }

  // ==========================
  // PRÉSTAMOS
  // ==========================
  Future<List<Map<String, dynamic>>> fetchActiveLoansWithDetails() async {
    final response = await _supabase
        .from('loans')
        .select('*, client:clients(*), payments(*)')
        .eq('status', 'active')
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<double> fetchTotalGlobalInterest() async {
    final response = await _supabase.from('payments').select('interest_paid');
    double total = 0;
    for (var p in response) {
      total += (p['interest_paid'] ?? 0).toDouble();
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> fetchPaidLoansWithDetails() async {
    final response = await _supabase
        .from('loans')
        .select('*, client:clients(*), payments(*)')
        .eq('status', 'paid')
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> createLoan({
    required String clientId,
    required double originalPrincipal,
    required double interestRate,
    required String paymentFrequency,
  }) async {
    DateTime now = DateTime.now();
    DateTime nextDate;
    if (paymentFrequency == 'Mensual') {
      nextDate = DateTime(now.year, now.month + 1, now.day);
    } else if (paymentFrequency == 'Quincenal') {
      nextDate = now.add(const Duration(days: 15));
    } else {
      nextDate = now.add(const Duration(days: 7));
    }

    await _supabase.from('loans').insert({
      'client_id': clientId,
      'original_principal': originalPrincipal,
      'interest_rate': interestRate,
      'payment_frequency': paymentFrequency,
      'next_payment_date': nextDate.toIso8601String().split('T')[0],
      'status': 'active'
    });
  }

  Future<void> updateLoan({
    required String id,
    required double originalPrincipal,
    required double interestRate,
  }) async {
    await _supabase.from('loans').update({
      'original_principal': originalPrincipal,
      'interest_rate': interestRate,
    }).eq('id', id);
  }

  // ==========================
  // PAGOS Y LEDGER
  // ==========================
  Future<List<Payment>> fetchLoanLedger(String loanId) async {
    final response = await _supabase
        .from('payments')
        .select()
        .eq('loan_id', loanId)
        .order('payment_date', ascending: false);
    return response.map((json) => Payment.fromJson(json)).toList();
  }

  Future<void> registerPayment({
    required String loanId,
    required double principalPaid,
    required double interestPaid,
    String? notes,
  }) async {
    final loan = await _supabase.from('loans').select('original_principal, interest_rate, payment_frequency, next_payment_date').eq('id', loanId).single();
    double originalPrincipal = (loan['original_principal'] ?? 0).toDouble();
    double interestRate = (loan['interest_rate'] ?? 0).toDouble();
    double expectedInterest = (originalPrincipal * interestRate) / 100.0;

    final allPayments = await _supabase.from('payments').select('interest_paid, notes').eq('loan_id', loanId).order('created_at', ascending: false);
    
    double accumulatedInterest = 0;
    for (var p in allPayments) {
      accumulatedInterest += (p['interest_paid'] ?? 0).toDouble();
      if (p['notes'] != null && p['notes'].toString().contains('[PERIODO_COMPLETO]')) {
        break;
      }
    }
    
    accumulatedInterest += interestPaid;
    
    int periodsToAdvance = 0;
    if (expectedInterest > 0) {
      periodsToAdvance = (accumulatedInterest / expectedInterest).floor();
    } else if (interestPaid > 0) {
      periodsToAdvance = 1;
    }
    
    String finalNotes = notes ?? '';
    if (periodsToAdvance > 0) {
      finalNotes = finalNotes.isEmpty ? '[PERIODO_COMPLETO]' : '$finalNotes [PERIODO_COMPLETO]';
    }
    
    await _supabase.from('payments').insert({
      'loan_id': loanId,
      'principal_paid': principalPaid,
      'interest_paid': interestPaid,
      'notes': finalNotes.isEmpty ? null : finalNotes,
    });

    final allPaymentsAfterInsert = await _supabase.from('payments').select('principal_paid').eq('loan_id', loanId);
    double totalPrincipalPaid = 0;
    for (var p in allPaymentsAfterInsert) {
      totalPrincipalPaid += (p['principal_paid'] ?? 0).toDouble();
    }

    if (totalPrincipalPaid >= originalPrincipal) {
      await _supabase.from('loans').update({'status': 'paid'}).eq('id', loanId);
    } else if (periodsToAdvance > 0) {
      String? currentNextStr = loan['next_payment_date'];
      String freq = loan['payment_frequency'];
      if (currentNextStr != null) {
        DateTime currentNext = DateTime.parse(currentNextStr);
        DateTime newNext = currentNext;
        for (int i = 0; i < periodsToAdvance; i++) {
          if (freq == 'Mensual') {
            newNext = DateTime(newNext.year, newNext.month + 1, newNext.day);
          } else if (freq == 'Quincenal') {
            newNext = newNext.add(const Duration(days: 15));
          } else {
            newNext = newNext.add(const Duration(days: 7));
          }
        }
        await _supabase.from('loans').update({'next_payment_date': newNext.toIso8601String().split('T')[0]}).eq('id', loanId);
      }
    }
  }

  Future<void> deletePayment(String paymentId, String loanId) async {
    final paymentToDelete = await _supabase.from('payments').select('notes').eq('id', paymentId).single();
    String notes = paymentToDelete['notes']?.toString() ?? '';
    int periodsToRollback = '[PERIODO_COMPLETO]'.allMatches(notes).length;

    await _supabase.from('payments').delete().eq('id', paymentId);
    
    final allPayments = await _supabase.from('payments').select('principal_paid').eq('loan_id', loanId);
    double totalPrincipalPaid = 0;
    for (var p in allPayments) {
      totalPrincipalPaid += (p['principal_paid'] ?? 0).toDouble();
    }
    
    final loan = await _supabase.from('loans').select('original_principal, payment_frequency, next_payment_date, status').eq('id', loanId).single();
    double originalPrincipal = (loan['original_principal'] ?? 0).toDouble();
    
    Map<String, dynamic> updates = {};
    if (loan['status'] == 'paid' && totalPrincipalPaid < originalPrincipal) {
      updates['status'] = 'active';
    }
    
    if (loan['status'] == 'active' && periodsToRollback > 0) {
      String? currentNextStr = loan['next_payment_date'];
      String freq = loan['payment_frequency'];
      if (currentNextStr != null) {
        DateTime currentNext = DateTime.parse(currentNextStr);
        DateTime oldNext = currentNext;
        for (int i = 0; i < periodsToRollback; i++) {
          if (freq == 'Mensual') {
            oldNext = DateTime(oldNext.year, oldNext.month - 1, oldNext.day);
          } else if (freq == 'Quincenal') {
            oldNext = oldNext.subtract(const Duration(days: 15));
          } else {
            oldNext = oldNext.subtract(const Duration(days: 7));
          }
        }
        updates['next_payment_date'] = oldNext.toIso8601String().split('T')[0];
      }
    }
    
    if (updates.isNotEmpty) {
      await _supabase.from('loans').update(updates).eq('id', loanId);
    }
  }
}
