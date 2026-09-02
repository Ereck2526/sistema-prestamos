# Diagnostico de Nuevos Problemas — App de Prestamos
**Fecha:** 2 de septiembre 2026

---

## Problema #1 — "Capital Prestado" muestra un valor mayor al real

### Que deberia mostrar
La suma del capital original de todos los prestamos **activos** que aun tienen saldo pendiente de cobrar.

### Que muestra actualmente
La suma del `original_principal` de todos los prestamos activos, **sin importar cuanto capital ya haya recuperado tu papa**.

### Causa raiz (codigo en `home_screen.dart`, linea 53-55)

```dart
for (var loan in loans) {
  lent += (loan['original_principal'] ?? 0).toDouble(); // Suma el capital ORIGINAL
}
```

**El problema:** si tu papa presto S/. 1,000 a alguien y ese cliente ya le abono S/. 600 de capital, el prestamo sigue siendo "activo" (porque aun debe S/. 400). Pero el panel suma los S/. 1,000 completos, cuando en realidad solo tiene S/. 400 en riesgo.

### Ejemplo concreto

| Cliente | Prestamo original | Ya abono capital | Capital real en riesgo |
|---------|------------------|-----------------|----------------------|
| Juan    | S/. 1,000        | S/. 600         | **S/. 400**          |
| Pedro   | S/. 500          | S/. 0           | **S/. 500**          |
| Maria   | S/. 2,000        | S/. 500         | **S/. 1,500**        |
| **Total** | **S/. 3,500**  | —               | **S/. 2,400**        |

Lo que tu papa ve: **S/. 3,500** (incorrecto)
Lo que deberia ver: **S/. 2,400** (capital aun por recuperar)

### Solucion propuesta
Para cada prestamo activo, restar la suma de todos los abonos de capital que ya se hicieron:

```dart
for (var loan in loans) {
  double original = (loan['original_principal'] ?? 0).toDouble();
  double capitalPagado = 0;
  if (loan['payments'] != null) {
    for (var p in loan['payments']) {
      capitalPagado += (p['principal_paid'] ?? 0).toDouble();
    }
  }
  lent += (original - capitalPagado); // Solo el capital pendiente real
}
```

Los datos ya estan disponibles porque `fetchActiveLoansWithDetails()` trae `payments(*)` junto con cada prestamo. No se necesita ninguna consulta adicional a la base de datos.

---

## Problema #2 — El reporte de interes clasifica pagos por fecha de pago real, no por periodo al que pertenecen

### Que deberia mostrar
El interes de agosto deberia aparecer en el reporte de **agosto**, aunque el cliente haya pagado fisicamente en septiembre.

### Que muestra actualmente
El interes se clasifica por la **fecha en que se registro el pago** (`payment_date`). Si el vencimiento era el 28 de agosto pero se pago el 1 de septiembre, ese interes aparece en el reporte de septiembre.

### Causa raiz (codigo en `database_service.dart`, linea 109)

```dart
// Agrupa por la fecha REAL del pago:
final DateTime date = _normalizeDate(DateTime.parse(p['payment_date']));
final String key = '${date.year}-${date.month.toString().padLeft(2, '0')}';
```

El campo `payment_date` es la fecha en que tu papa registra el pago, no la fecha del periodo que se esta cobrando.

### Ejemplo concreto

| Situacion | Periodo que corresponde | Fecha de pago registrada | Aparece en reporte de... |
|-----------|------------------------|--------------------------|--------------------------|
| Pago puntual el 28/ago | Agosto | 28/agosto | Agosto ✅ |
| Pago tardio el 1/sep | **Agosto** | 1/septiembre | Septiembre ❌ |
| Pago adelantado el 20/ago | Agosto | 20/agosto | Agosto ✅ |

### Solucion propuesta
La logica de clasificacion debe basarse en la **fecha de vencimiento del periodo**, no en la fecha del pago. La fecha de vencimiento es la `next_payment_date` que tenia el prestamo **justo antes** de que se registrara el pago.

**Opcion A — Guardar el periodo al que pertenece cada pago (recomendada)**

Al momento de registrar un pago en `registerPayment()`, junto con el pago guardar tambien la fecha del periodo al que pertenece (la `next_payment_date` actual del prestamo antes de avanzarla). Se añadiria una columna `period_date` a la tabla `payments` en Supabase.

```sql
ALTER TABLE payments ADD COLUMN period_date DATE;
```

Y en `registerPayment()`:
```dart
insertData['period_date'] = loan['next_payment_date']; // La fecha del periodo antes de avanzar
```

El reporte entonces agruparia por `period_date` en vez de `payment_date`.

**Opcion B — Logica aproximada sin cambio de esquema**

Si el pago se hizo despues de la fecha de vencimiento del prestamo (es decir, `payment_date > next_payment_date`), clasificar el pago en el mes de `next_payment_date`. Esta opcion es menos precisa en casos de multiples periodos pendientes a la vez.

### Recomendacion
La **Opcion A** es mas robusta y limpia. Requiere una migracion pequeña en la base de datos (agregar una columna), pero garantiza que cada pago siempre quede correctamente asociado a su periodo, sin importar cuando se pago.

---

## Resumen

| # | Problema | Impacto | Archivo afectado | Requiere cambio BD |
|---|----------|---------|-----------------|-------------------|
| 1 | Capital mostrado incluye lo ya cobrado | El total es mayor al real | `home_screen.dart` linea 53 | No |
| 2 | Pagos tardios aparecen en el mes equivocado | Reporte mensual incorrecto | `database_service.dart` + `reports_screen.dart` | Si (Opcion A) / No (Opcion B) |
