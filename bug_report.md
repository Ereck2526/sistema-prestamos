# Reporte de Bugs — App de Préstamos
**Fecha:** 1 de septiembre 2026  
**Archivos afectados:** `database_service.dart`, `loan_detail_screen.dart`

---

## Bug #1 — Fecha de cobro salta al año incorrecto
**Severidad:** 🔴 Crítico

### Síntoma
Al registrar un préstamo mensual, la fecha de próximo cobro aparecía en enero del 2027 en vez de un mes después.

### Causa raíz
El código usaba `DateTime(now.year, now.month + 1, now.day)` para sumar un mes. Dart maneja el desbordamiento de meses automáticamente (mes 13 = enero del año siguiente), pero el problema real era la **zona horaria**: cuando tu papá selecciona una fecha en el calendario, Flutter la guarda con hora `00:00:00` en hora local (Perú, UTC-5). Al convertirla a ISO 8601 y guardarla en Supabase, este la almacena en UTC, lo que puede desplazar la fecha un día. Al leerla de vuelta, el `.day` podía dar el día incorrecto, y esto se propagaba a todos los cálculos.

```dart
// ANTES (con bug):
DateTime now = startDate ?? DateTime.now();
nextDate = DateTime(now.year, now.month + 1, now.day);
// Si startDate tenía componente horaria desfasada, now.day podía ser incorrecto
```

### Solución
Se creó el método `_normalizeDate()` que elimina la componente horaria antes de cualquier cálculo, fijando siempre la medianoche local:

```dart
// DESPUÉS:
DateTime _normalizeDate(DateTime dt) {
  final local = dt.toLocal(); // Asegurar hora local
  return DateTime(local.year, local.month, local.day); // Solo fecha, sin hora
}

// Se aplica al inicio de createLoan, registerPayment y updateLoan:
final DateTime base = _normalizeDate(startDate ?? DateTime.now());
```

---

## Bug #2 — Pago completo avanza 2 meses en vez de 1
**Severidad:** 🔴 Crítico

### Síntoma
Un préstamo con vencimiento el 28 de agosto, al registrar el pago completo el 1 de septiembre, mostraba como próxima fecha el 28 de **octubre** en vez del 28 de **septiembre**.

### Causa raíz
El bucle que recalcula la fecha de próximo cobro iteraba `totalCompletedPeriods + 1` veces en lugar de `totalCompletedPeriods`. Ese `+ 1` extra hacía que siempre se saltara un período adicional.

```dart
// ANTES (con bug):
DateTime newNext = createdAt; // Inicio: 28 de agosto
for (int i = 0; i < totalCompletedPeriods + 1; i++) { // ← +1 de más
  newNext = DateTime(newNext.year, newNext.month + 1, createdAt.day);
}
// Con totalCompletedPeriods = 1:
// Iteración 0: 28 ago → 28 sep
// Iteración 1: 28 sep → 28 oct  ← una de más
// Resultado: 28 octubre ❌
```

### Solución
Eliminar el `+ 1` del bucle. El número de períodos completados ya incluye el período que se acaba de pagar:

```dart
// DESPUÉS:
for (int i = 0; i < totalCompletedPeriods; i++) { // ← sin +1
  newNext = _addOneMonthSafe(newNext, anchorDay);
}
// Con totalCompletedPeriods = 1:
// Iteración 0: 28 ago → 28 sep
// Resultado: 28 septiembre ✅
```

---

## Bug #3 — Acumulador de adelantos incluía el período ya cerrado
**Severidad:** 🔴 Crítico

### Síntoma
Si un cliente había dado adelantos en meses anteriores, el siguiente pago podía ser marcado como "período completo" prematuramente, aun cuando el monto no alcanzaba el interés del período actual.

### Causa raíz
El código recorría los pagos del más reciente al más antiguo sumando intereses, y hacía el `break` **después** de sumar el interés del pago que tenía la marca `[PERIODO_COMPLETO]`. Esto incluía el interés del período anterior ya cerrado en el acumulado del período actual.

```dart
// ANTES (con bug):
// Pagos existentes (más reciente primero):
// → Adelanto actual: S/. 100 (sin marca)
// → Pago que cerró mes pasado: S/. 200 (con [PERIODO_COMPLETO])

for (var p in allPayments) {
  accumulatedInterest += p['interest_paid']; // Suma 100, luego suma 200
  if (p['notes'].contains('[PERIODO_COMPLETO]')) {
    break; // Rompe DESPUÉS de sumar los 200
  }
}
// accumulatedInterest = 300 ← INCORRECTO (debería ser 100)
```

### Solución
El `break` debe ocurrir **antes** de sumar el interés del pago marcado como período completo:

```dart
// DESPUÉS:
for (var p in allPayments) {
  if (p['notes'] != null && p['notes'].contains('[PERIODO_COMPLETO]')) {
    break; // ← Rompe ANTES de sumar
  }
  accumulatedInterest += (p['interest_paid'] ?? 0).toDouble();
}
// Con adelanto de 100 y pago anterior de 200 (cerrado):
// → Suma 100, llega al de 200 → break
// accumulatedInterest = 100 ✅
```

---

## Bug #4 — Eliminar pago no revertía la fecha si el préstamo estaba marcado como pagado
**Severidad:** 🔴 Crítico

### Síntoma
Si el último pago que había cerrado el préstamo (marcándolo como `paid`) se eliminaba, el préstamo volvía a estado `active` correctamente, pero la fecha de próximo cobro quedaba en el pasado o incorrecta porque no se revertía.

### Causa raíz
La condición para revertir la fecha verificaba `loan['status'] == 'active'`, pero en ese momento el préstamo todavía figuraba como `'paid'` en la base de datos (el cambio de estado se preparaba pero aún no se ejecutaba en las evaluaciones):

```dart
// ANTES (con bug):
if (loan['status'] == 'paid' && totalPrincipalPaid < originalPrincipal) {
  updates['status'] = 'active'; // Se prepara el cambio, pero...
}

if (loan['status'] == 'active' && periodsToRollback > 0) {
  // ← Esta condición nunca se cumple si el préstamo venía de 'paid'
  // porque loan['status'] sigue siendo 'paid' en la variable leída
}
```

### Solución
Calcular previamente si el préstamo **quedará activo** después de la eliminación, independientemente de su estado actual:

```dart
// DESPUÉS:
final bool wasMarkedPaid = loan['status'] == 'paid';
final bool willBeReactivated = wasMarkedPaid && totalPrincipalPaid < originalPrincipal;

if (willBeReactivated) updates['status'] = 'active';

// Verificar si quedará activo (ya era active, o se va a reactivar)
final bool willBeActive = (loan['status'] == 'active') || willBeReactivated;

if (willBeActive && periodsToRollback > 0) {
  // Ahora sí revierte la fecha en ambos casos ✅
}
```

---

## Bug #5 — Interés sugerido calculado sobre el capital restante
**Severidad:** 🟡 Funcional

### Síntoma
En el modal de "Registrar Pago", el monto de interés sugerido disminuía cada vez que el cliente abonaba capital. Por ejemplo, si el préstamo era de S/. 1,000 al 10%, el interés correcto siempre es S/. 100. Pero si el cliente ya había abonado S/. 400 de capital, el sistema sugería S/. 60 (el 10% de S/. 600 restantes).

### Causa raíz
Se usaba `_remainingPrincipal` (capital pendiente de cobrar) en vez de `_originalPrincipal` (monto original del préstamo):

```dart
// ANTES (con bug):
double suggestedInterest = _remainingPrincipal * (_interestRate / 100);
// Si original=1000, ya abonó 400, queda 600:
// suggestedInterest = 600 * 0.10 = S/. 60 ❌
```

### Solución
El interés de un préstamo siempre se calcula sobre el **capital original**:

```dart
// DESPUÉS:
double suggestedInterest = _originalPrincipal * (_interestRate / 100);
// suggestedInterest = 1000 * 0.10 = S/. 100 ✅
```

> **Nota:** Esta corrección era especialmente importante porque la lógica interna de `registerPayment` ya usaba `originalPrincipal` correctamente. Solo la sugerencia visual en la pantalla estaba mal, lo que podía confundir a tu papá.

---

## Bug #6 — Error de punto flotante bloqueaba el avance del período
**Severidad:** 🟡 Potencial / Intermitente

### Síntoma
En casos específicos, después de pagar exactamente el interés completo, el período no avanzaba y la fecha de cobro no se actualizaba.

### Causa raíz
Los números decimales en computadoras no son exactos. El número `200.00` en aritmética de punto flotante puede ser en realidad `199.9999999999998`. Al dividir y aplicar `.floor()`:

```dart
// ANTES (con bug):
periodsToAdvance = (accumulatedInterest / expectedInterest).floor();
// Si el resultado real es 0.9999999... en vez de 1.0:
// floor(0.9999...) = 0 ← el período NO avanza ❌
```

### Solución
Añadir un pequeño margen de tolerancia (`epsilon = 0.001`) que absorba el error de punto flotante sin afectar la lógica real:

```dart
// DESPUÉS:
const double epsilon = 0.001;
periodsToAdvance = ((accumulatedInterest + epsilon) / expectedInterest).floor();
// (199.9999 + 0.001) / 200 = 200.0009 / 200 = 1.000004...
// floor(1.000004) = 1 ✅
```

> El epsilon de 0.001 (1/10 de centavo) es lo suficientemente pequeño para no crear falsos positivos, pero suficientemente grande para absorber cualquier error de punto flotante real.

---

## Mejora adicional — Soporte para día 31 (snap-to-end-of-month)

### Necesidad
Si un préstamo se registra el 31 de un mes, el siguiente cobro debería ser el último día del mes siguiente (30 si tiene 30, 31 si tiene 31), y así sucesivamente.

### Implementación
Se crearon dos métodos helper que reemplazan el uso directo de `DateTime(year, month+1, day)`:

```dart
DateTime _addOneMonthSafe(DateTime base, int anchorDay) {
  int targetMonth = base.month + 1;
  int targetYear = base.year;
  if (targetMonth > 12) { targetMonth = 1; targetYear++; }
  
  // DateTime(year, month+1, 0) da el último día del mes - truco estándar en Dart
  final int lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
  return DateTime(targetYear, targetMonth, anchorDay.clamp(1, lastDay));
}

DateTime _subtractOneMonthSafe(DateTime base, int anchorDay) {
  // Lógica inversa para cuando se elimina un pago
  int targetMonth = base.month - 1;
  int targetYear = base.year;
  if (targetMonth < 1) { targetMonth = 12; targetYear--; }
  final int lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
  return DateTime(targetYear, targetMonth, anchorDay.clamp(1, lastDay));
}
```

**Ejemplo con préstamo del 31 de agosto:**

| Cobro | Mes destino | Último día | Día usado |
|-------|------------|-----------|-----------|
| 1° | Septiembre | 30 | **30** |
| 2° | Octubre | 31 | **31** |
| 3° | Noviembre | 30 | **30** |
| 4° | Diciembre | 31 | **31** |

El `anchorDay` (día original del préstamo = 31) se lee siempre desde `created_at`, garantizando que meses con 31 días usen el día 31 y meses con menos días usen su último día válido.
