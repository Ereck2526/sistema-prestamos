# Implementación de Notificaciones de Cobro

El objetivo es notificar al prestamista cuando un cobro debe realizarse hoy (Naranja) o cuando ya está atrasado (Rojo), incluyendo la cantidad de días de retraso.

## > [!IMPORTANT]
## User Review Required: Elección de Tecnología

Para enviar estas notificaciones, existen 3 caminos distintos. Por favor, lee las opciones y dime cuál prefieres que implemente:

### Opción 1: Alertas dentro de la App (Recomendada y más rápida)
Cada vez que tu papá abra la aplicación, el sistema calculará todo al instante y le lanzará una **pantalla emergente** (como una alarma visual) diciéndole: 
- "🔔 Hoy debes cobrarle a: Cliente A, Cliente B."
- "⚠️ Atrasados: Cliente C (venció hace 3 días), Cliente D (venció hace 5 días)."
**Pros:** Es 100% exacto con los días de retraso, no falla nunca y es inmediato de programar.
**Contras:** Tiene que abrir la app para ver el aviso.

### Opción 2: Notificaciones Locales (Solo Android)
Instalamos un plugin en el código para que el celular vibre y lance una notificación en la barra superior (como un mensaje de WhatsApp) a las 9:00 AM del día del cobro.
**Pros:** Le avisa sin que tenga que abrir la aplicación.
**Contras:** Para los pagos atrasados, programar que el celular suene todos los días diciendo "hace 1 día", "hace 2 días", "hace 3 días" requiere programar decenas de alarmas invisibles en el celular por cada cliente, lo cual consume más batería y memoria del teléfono.

### Opción 3: Automatización por Servidor (Avanzado)
Programar la base de datos (Supabase) para que todos los días a la medianoche revise las fechas y envíe una Notificación Push real por internet, o incluso un mensaje automático a un servidor de Telegram/WhatsApp.
**Pros:** Súper profesional y funciona en la nube.
**Contras:** Requiere crear cuentas en servicios de terceros (como Firebase para notificaciones, o Twilio/Meta para WhatsApp) y configuraciones complejas que pueden tomar bastante tiempo.

## Open Questions

¿Cuál de las 3 opciones crees que le será más cómoda a tu papá para el día a día? (Si quieres la más práctica y que no falle con los días de retraso, te sugiero fuertemente la **Opción 1** acompañada de una campanita roja en el menú principal).

---

## Proposed Changes

Dependiendo de tu elección, los archivos a modificar serán:

### lib/screens/home_screen.dart
Se agregará la lógica para escanear los préstamos activos al iniciar la aplicación (Opción 1) o solicitar permisos de notificaciones (Opción 2).

### pubspec.yaml
(Si eliges la Opción 2) Agregar dependencias como `flutter_local_notifications`.

## Verification Plan

1. Crearemos un préstamo ficticio con fecha de cobro de ayer para forzar el estado "Rojo".
2. Verificaremos que el mensaje diga exactamente "El préstamo de {Cliente} venció hace 1 días".
3. Crearemos un préstamo para hoy y verificaremos el mensaje Naranja.
