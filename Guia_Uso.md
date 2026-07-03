# Guía de Uso Rápido (Capital Vivo)

Tu aplicación ha sido reconstruida desde cero. Aquí te explico cómo probarla:

## 1. Ejecutar la App
Abre una terminal o pídele a tu asistente (yo) que ejecute:
```bash
flutter run
```
Puedes elegir correrla en Chrome (Web) o en tu celular Android si lo tienes conectado.

## 2. Flujo de Trabajo para tu Papá
1. **Crear un Cliente:** 
   * Ve al ícono de personas (Directorio) en la esquina superior derecha del Panel Principal.
   * Haz clic en "+" y añade el nombre y teléfono del cliente.
2. **Prestar Dinero:**
   * En el Panel Principal, toca el botón flotante "+ Nuevo Préstamo".
   * Selecciona al cliente que creaste.
   * Ingresa el monto (ej. 1000) y la tasa (ej. 10).
3. **Registrar un Pago (La Magia):**
   * En el Panel Principal, toca el préstamo que acabas de crear.
   * Verás que el "Saldo Restante" es de $1000.
   * Toca **"REGISTRAR PAGO"**.
   * La app te sugerirá automáticamente $100 de abono a interés (el 10% de 1000). 
   * Digamos que el cliente pagó $600 en total. Dejas los $100 en interés y pones $500 en "Abono a Capital".
   * Al guardar, verás en tiempo real cómo el "Saldo Restante" baja a $500 y el pago queda registrado en el historial con fecha y hora exacta.

## Notas Técnicas
* La aplicación está conectada en tiempo real a Supabase.
* El login requiere un usuario válido registrado en el panel de Authentication de Supabase.

## 3. Guía de Actualizaciones a Futuro (¡Muy Importante!)
Cuando tú (o la Inteligencia Artificial) realicen cambios o mejoras en el código fuente de esta computadora, **la App en el celular de tu papá NO cambiará mágicamente sola**. Tienes que "empujar" esa actualización al servidor usando la consola.

Siempre que quieras publicar una mejora nueva, abre la terminal en la carpeta del proyecto y ejecuta estos **dos comandos en orden**:

**Paso 1: Empaquetar el nuevo código (Compilar)**
```bash
flutter build web
```
*(Espera a que termine y diga "Built build\web")*

**Paso 2: Subir al servidor (Desplegar)**
```bash
npx surge build\web --domain el-link-de-tu-papa.surge.sh
```
*(⚠️ Cambia `el-link-de-tu-papa.surge.sh` por el dominio real que elegiste para él. Si olvidas poner el `--domain...`, el sistema creará un link aleatorio nuevo y tu papá se quedará atascado en la versión vieja).*

**¡Y listo!** Dile a tu papá que cierre y vuelva a abrir la aplicación en su celular, y verá los cambios automáticamente.
