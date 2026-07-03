# Documentación del Proyecto: Sistema de Gestión de Préstamos

**Propósito del Sistema:**
La aplicación tiene como objetivo principal digitalizar y automatizar el registro (actualmente llevado en un cuaderno físico) de los préstamos informales realizados por un prestamista independiente. El sistema se basará en el modelo de "Amortización sobre Saldo" (Capital Vivo) para permitir máxima flexibilidad en los cobros (abonos parciales, pagos solo de interés, cancelaciones totales).

---

## 1. Requisitos de Desarrollo y Arquitectura

*   **Tipo de Aplicación:** Aplicación Móvil (Android/iOS) con capacidad de exportarse a Web.
*   **Framework Frontend:** Flutter (Dart).
*   **Arquitectura de Software:** MVVM (Model-View-ViewModel) utilizando `Provider` para la gestión del estado.
*   **Backend y Base de Datos:** Supabase (PostgreSQL).
*   **Tipo de Usuario:** Sistema *Single-User* (Administrador único). No habrá portal ni login para clientes finales.

---

## 2. Requisitos Funcionales (RF)

Los requisitos funcionales describen lo que el sistema *debe hacer*.

*   **RF-01 (Autenticación):** El sistema debe permitir el inicio de sesión exclusivo para el administrador mediante correo y contraseña o biometría local.
*   **RF-02 (Gestión de Clientes):** El sistema debe permitir registrar, listar, editar y eliminar clientes. Un cliente se compone de: Nombre completo, Teléfono, y Alias.
*   **RF-03 (Registro de Préstamos):** El sistema debe permitir registrar un nuevo préstamo asociándolo a un cliente existente, indicando el monto original (Capital Inicial), la tasa de interés (%) y la frecuencia de cobro (Diario, Semanal, Mensual).
*   **RF-04 (Cálculo de Capital Restante):** El sistema debe calcular y mostrar automáticamente el "Capital Vivo" (Saldo restante) de cada préstamo, restando todos los abonos a capital realizados del monto original prestado.
*   **RF-05 (Cálculo de Interés Sugerido):** El sistema debe calcular sugerir el interés a cobrar en el periodo actual basado en el *Capital Restante* y la *Tasa de Interés*.
*   **RF-06 (Registro de Pagos/Abonos):** El sistema debe permitir registrar un pago o transacción, solicitando al administrador que desglose cuánto dinero de ese pago va dirigido a "Intereses" y cuánto a "Capital".
*   **RF-07 (Cierre Automático de Préstamo):** Cuando la sumatoria de todos los abonos al capital sea igual o mayor al capital prestado original, el sistema debe cambiar el estado del préstamo a "Pagado" (Cerrado).
*   **RF-08 (Dashboard General):** La pantalla principal debe mostrar el total de dinero (Capital) que el prestamista tiene "en la calle" y un resumen rápido de los próximos cobros.
*   **RF-09 (Historial / Ledger):** El sistema debe mostrar un historial cronológico (tipo estado de cuenta o libro mayor) de todos los abonos y cargos realizados a un préstamo específico.

---

## 3. Requisitos No Funcionales (RNF)

Los requisitos no funcionales describen *cómo* debe comportarse el sistema (calidad, rendimiento, restricciones).

*   **RNF-01 (Usabilidad):** La interfaz debe ser extremadamente intuitiva y tener un botón principal y accesible ("+") para la acción más común: registrar un pago. Los textos deben ser grandes y legibles.
*   **RNF-02 (Disponibilidad):** Al depender de Supabase (Cloud), el sistema requiere conexión a internet para leer y escribir datos. 
*   **RNF-03 (Seguridad):** La base de datos debe estar protegida mediante Row Level Security (RLS) en Supabase para que ninguna otra persona sin el token del administrador pueda consultar o modificar los registros.
*   **RNF-04 (Rendimiento):** El tiempo de respuesta al guardar un pago o cargar el historial de un préstamo no debe superar los 2 segundos bajo una conexión a internet estable.
*   **RNF-05 (Escalabilidad):** El diseño de la base de datos (modelo Ledger/Historial de transacciones) debe soportar miles de registros de pagos sin degradar el rendimiento de la consulta del Capital Restante.

---

## 4. Esquema de Base de Datos Propuesto

*   **Tabla `clients`**: Directorio de prestatarios.
*   **Tabla `loans`**: Registro maestro de cada crédito.
*   **Tabla `payments`**: El libro mayor donde se registran todas las entradas de dinero (separando capital de interés).
