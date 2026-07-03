# Plan de Implementación (Reconstrucción desde Cero)

Basado en el documento de requisitos (SRS), este es el plan técnico paso a paso para construir la aplicación desde cero.

## Fase 1: Fundamentos y Base de Datos
1.  **Esquema Supabase:** Proporcionar script SQL para crear las tablas `clients`, `loans` y `payments`.
2.  **Modelos de Datos (`lib/models/`)**: Crear las clases `Client`, `Loan`, `Payment` en Dart.
3.  **Servicio de Base de Datos (`lib/services/database_service.dart`)**: Implementar CRUD de clientes, préstamos y pagos.

## Fase 2: Autenticación y Enrutamiento
1.  **Servicio de Autenticación (`lib/services/auth_service.dart`)**: Implementar login del administrador.
2.  **Enrutador (`lib/utils/app_router.dart`)**: Configuración de navegación con `GoRouter`.
3.  **Configuración Global (`lib/main.dart`)**: Inicialización de Supabase y `Providers`.

## Fase 3: Pantallas (UI)
*   **`login_screen.dart`**: Acceso de administrador.
*   **`home_screen.dart`**: Dashboard principal.
*   **`clients_screen.dart`**: Directorio de clientes.
*   **`create_loan_screen.dart`**: Formulario de nuevo crédito.
*   **`loan_detail_screen.dart`**: Ledger (Historial) y registro de pagos.
