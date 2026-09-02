import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../models/loan_model.dart';
import '../models/payment_model.dart';

class DatabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ==========================
  // HELPER: CALCULO DE FECHAS
  // ==========================

  /// Avanza [base] un mes preservando [anchorDay].
  /// Si [anchorDay] no existe en el mes destino (ej: dia 31 en septiembre),
  /// usa el ultimo dia valido de ese mes (snap-to-end-of-month).
  DateTime _addOneMonthSafe(DateTime base, int anchorDay) {
    int targetMonth = base.month + 1;
    int targetYear = base.year;
    if (targetMonth > 12) {
      targetMonth = 1;
      targetYear += 1;
    }
    // DateTime(year, month+1, 0) da el ultimo dia del mes. Funciona incluso con month=12.
    final int lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    return DateTime(targetYear, targetMonth, anchorDay.clamp(1, lastDay));
  }

  /// Retrocede [base] un mes preservando [anchorDay].
  DateTime _subtractOneMonthSafe(DateTime base, int anchorDay) {
    int targetMonth = base.month - 1;
    int targetYear = base.year;
    if (targetMonth < 1) {
      targetMonth = 12;
      targetYear -= 1;
    }
    final int lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    return DateTime(targetYear, targetMonth, anchorDay.clamp(1, lastDay));
  }

  /// Normaliza un DateTime a medianoche local, eliminando la componente horaria
  /// para evitar problemas de zona horaria al comparar o guardar fechas.
  DateTime _normalizeDate(DateTime dt) {
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

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
  // PRESTAMOS
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

  /// Devuelve el interes cobrado agrupado por mes/año, con detalle de cada pago.
  Future<List<Map<String, dynamic>>> fetchMonthlyInterest() async {
    final response = await _supabase
        .from('payments')
        .select('interest_paid, payment_date, period_date, loan:loans(client:clients(name))')
        .order('payment_date', ascending: false);

    final Map<String, Map<String, dynamic>> grouped = {};
    for (var p in response) {
      final double interest = (p['interest_paid'] ?? 0).toDouble();
      if (interest <= 0) continue;

      // FIX #2: Usar period_date si existe (pagos nuevos), si no usar payment_date (pagos antiguos).
      // Esto garantiza que pagos tardios se clasifiquen en el mes al que pertenecen,
      // no en el mes en que fisicamente se pagaron.
      final String rawDateStr = (p['period_date'] ?? p['payment_date']) as String;
      final DateTime date = _normalizeDate(DateTime.parse(rawDateStr));
      final String key = '${date.year}-${date.month.toString().padLeft(2, '0')}';

      String clientName = 'Desconocido';
      if (p['loan'] != null && p['loan']['client'] != null) {
        clientName = p['loan']['client']['name'] ?? 'Desconocido';
      }

      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'year': date.year,
          'month': date.month,
          'total': 0.0,
          'payments': [],
        };
      }
      grouped[key]!['total'] += interest;
      grouped[key]!['payments'].add({
        'date': date,
        'amount': interest,
        'clientName': clientName,
      });
    }

    final List<Map<String, dynamic>> result = grouped.values.toList();
    result.sort((a, b) {
      final aDate = DateTime(a['year'] as int, a['month'] as int);
      final bDate = DateTime(b['year'] as int, b['month'] as int);
      return bDate.compareTo(aDate);
    });
    return result;
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
    DateTime? startDate,
  }) async {
    // FIX #1 / TZ: Normalizar a medianoche local para evitar desfases de zona horaria
    final DateTime base = _normalizeDate(startDate ?? DateTime.now());

    DateTime nextDate;
    if (paymentFrequency == 'Mensual') {
      // FIX dia-31: _addOneMonthSafe ajusta al ultimo dia del mes si no existe el dia ancla
      nextDate = _addOneMonthSafe(base, base.day);
    } else if (paymentFrequency == 'Quincenal') {
      nextDate = base.add(const Duration(days: 15));
    } else {
      nextDate = base.add(const Duration(days: 7));
    }

    await _supabase.from('loans').insert({
      'client_id': clientId,
      'original_principal': originalPrincipal,
      'interest_rate': interestRate,
      'payment_frequency': paymentFrequency,
      'next_payment_date': nextDate.toIso8601String().split('T')[0],
      'created_at': base.toIso8601String(),
      'status': 'active',
    });
  }

  Future<void> updateLoan({
    required String id,
    required double originalPrincipal,
    required double interestRate,
    DateTime? startDate,
    DateTime? nextDate,
    String? paymentFrequency,
  }) async {
    Map<String, dynamic> updates = {
      'original_principal': originalPrincipal,
      'interest_rate': interestRate,
    };

    if (startDate != null) {
      final DateTime base = _normalizeDate(startDate);
      updates['created_at'] = base.toIso8601String();
    }

    if (paymentFrequency != null) {
      updates['payment_frequency'] = paymentFrequency;
    }

    // Si se cambio la frecuencia, recalcular next_payment_date desde la fecha de inicio
    if (paymentFrequency != null) {
      DateTime base;
      if (startDate != null) {
        base = _normalizeDate(startDate);
      } else {
        // FIX: Si no se provee startDate, obtener created_at actual desde la BD
        final loan = await _supabase.from('loans').select('created_at').eq('id', id).single();
        base = _normalizeDate(DateTime.parse(loan['created_at']));
      }

      DateTime recalculated;
      if (paymentFrequency == 'Mensual') {
        recalculated = _addOneMonthSafe(base, base.day);
      } else if (paymentFrequency == 'Quincenal') {
        recalculated = base.add(const Duration(days: 15));
      } else {
        recalculated = base.add(const Duration(days: 7));
      }
      updates['next_payment_date'] = recalculated.toIso8601String().split('T')[0];
    } else if (nextDate != null) {
      updates['next_payment_date'] = nextDate.toIso8601String().split('T')[0];
    }

    await _supabase.from('loans').update(updates).eq('id', id);
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
    DateTime? paymentDate,
  }) async {
    final loan = await _supabase
        .from('loans')
        .select('original_principal, interest_rate, payment_frequency, next_payment_date, created_at')
        .eq('id', loanId)
        .single();

    double originalPrincipal = (loan['original_principal'] ?? 0).toDouble();
    double interestRate = (loan['interest_rate'] ?? 0).toDouble();
    double expectedInterest = (originalPrincipal * interestRate) / 100.0;

    final allPayments = await _supabase
        .from('payments')
        .select('interest_paid, notes')
        .eq('loan_id', loanId)
        .order('created_at', ascending: false);

    // FIX #3: El break debe ocurrir ANTES de sumar el interes del pago que ya cerro un periodo.
    // Iteramos del mas reciente al mas antiguo y acumulamos solo los adelantos del periodo actual.
    double accumulatedInterest = 0;
    for (var p in allPayments) {
      if (p['notes'] != null && p['notes'].toString().contains('[PERIODO_COMPLETO]')) {
        break; // Encontramos el cierre del periodo anterior: detener sin sumar este pago
      }
      accumulatedInterest += (p['interest_paid'] ?? 0).toDouble();
    }

    accumulatedInterest += interestPaid;

    int periodsToAdvance = 0;
    if (expectedInterest > 0) {
      // FIX #6: Epsilon para absorber errores de punto flotante en aritmetica decimal
      const double epsilon = 0.001;
      periodsToAdvance = ((accumulatedInterest + epsilon) / expectedInterest).floor();
    } else if (interestPaid > 0) {
      periodsToAdvance = 1;
    }

    String finalNotes = notes ?? '';
    if (periodsToAdvance > 0) {
      finalNotes = finalNotes.isEmpty ? '[PERIODO_COMPLETO]' : '$finalNotes [PERIODO_COMPLETO]';
    }

    Map<String, dynamic> insertData = {
      'loan_id': loanId,
      'principal_paid': principalPaid,
      'interest_paid': interestPaid,
      'notes': finalNotes.isEmpty ? null : finalNotes,
      // FIX #2: Guardar el periodo al que pertenece este pago (fecha de vencimiento antes de avanzar).
      // Si el cliente paga tarde, el pago igual queda clasificado en el mes correcto.
      if (loan['next_payment_date'] != null) 'period_date': loan['next_payment_date'],
    };
    if (paymentDate != null) insertData['payment_date'] = paymentDate.toIso8601String();

    await _supabase.from('payments').insert(insertData);

    final allPaymentsAfterInsert = await _supabase
        .from('payments')
        .select('principal_paid')
        .eq('loan_id', loanId);
    double totalPrincipalPaid = 0;
    for (var p in allPaymentsAfterInsert) {
      totalPrincipalPaid += (p['principal_paid'] ?? 0).toDouble();
    }

    if (totalPrincipalPaid >= originalPrincipal) {
      await _supabase.from('loans').update({'status': 'paid'}).eq('id', loanId);
    } else if (periodsToAdvance > 0) {
      String freq = loan['payment_frequency'];
      // FIX #1 / TZ: Normalizar created_at para obtener el dia ancla correcto
      final DateTime createdAt = _normalizeDate(DateTime.parse(loan['created_at']));
      final int anchorDay = createdAt.day;

      // Contar total de periodos completados: los de este pago + los historicos
      int totalCompletedPeriods = periodsToAdvance;
      for (var p in allPayments) {
        final String n = p['notes']?.toString() ?? '';
        totalCompletedPeriods += '[PERIODO_COMPLETO]'.allMatches(n).length;
      }

      // FIX #2: Avanzar exactamente totalCompletedPeriods veces (eliminar el +1 extra)
      // FIX dia-31: Usar _addOneMonthSafe para respetar el dia ancla en meses cortos
      DateTime newNext = createdAt;
      for (int i = 0; i < totalCompletedPeriods; i++) {
        if (freq == 'Mensual') {
          newNext = _addOneMonthSafe(newNext, anchorDay);
        } else if (freq == 'Quincenal') {
          newNext = newNext.add(const Duration(days: 15));
        } else {
          newNext = newNext.add(const Duration(days: 7));
        }
      }
      await _supabase.from('loans')
          .update({'next_payment_date': newNext.toIso8601String().split('T')[0]})
          .eq('id', loanId);
    }
  }

  Future<void> deletePayment(String paymentId, String loanId) async {
    final paymentToDelete = await _supabase
        .from('payments')
        .select('notes')
        .eq('id', paymentId)
        .single();
    final String notes = paymentToDelete['notes']?.toString() ?? '';
    final int periodsToRollback = '[PERIODO_COMPLETO]'.allMatches(notes).length;

    await _supabase.from('payments').delete().eq('id', paymentId);

    final allPayments = await _supabase
        .from('payments')
        .select('principal_paid')
        .eq('loan_id', loanId);
    double totalPrincipalPaid = 0;
    for (var p in allPayments) {
      totalPrincipalPaid += (p['principal_paid'] ?? 0).toDouble();
    }

    final loan = await _supabase
        .from('loans')
        .select('original_principal, payment_frequency, next_payment_date, status, created_at')
        .eq('id', loanId)
        .single();
    double originalPrincipal = (loan['original_principal'] ?? 0).toDouble();

    Map<String, dynamic> updates = {};

    final bool wasMarkedPaid = loan['status'] == 'paid';
    final bool willBeReactivated = wasMarkedPaid && totalPrincipalPaid < originalPrincipal;

    if (willBeReactivated) {
      updates['status'] = 'active';
    }

    // FIX #4: Aplicar rollback de fecha tanto si el prestamo ya era 'active'
    // como si se va a reactivar por eliminacion del pago que lo habia cerrado.
    final bool willBeActive = (loan['status'] == 'active') || willBeReactivated;

    if (willBeActive && periodsToRollback > 0) {
      final String? currentNextStr = loan['next_payment_date'];
      final String freq = loan['payment_frequency'];
      final DateTime createdAt = _normalizeDate(DateTime.parse(loan['created_at']));
      final int anchorDay = createdAt.day;

      if (currentNextStr != null) {
        DateTime oldNext = DateTime.parse(currentNextStr);
        for (int i = 0; i < periodsToRollback; i++) {
          if (freq == 'Mensual') {
            oldNext = _subtractOneMonthSafe(oldNext, anchorDay);
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
