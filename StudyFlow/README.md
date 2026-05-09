# StudyFlow

App multiplataforma (iOS, Android, Windows, macOS, Linux, Web) de organización de estudios, trabajo y rutinas, con IA local (Ollama) y sincronización en la nube (Supabase free tier).

## Stack

- **Flutter** + Riverpod + go_router
- **Supabase** (auth, base de datos PostgreSQL, realtime, storage) — plan gratuito
- **Ollama** local en `http://localhost:11434` con `llama3.2` por defecto
- **Hive** para caché local
- **flutter_local_notifications** para recordatorios

Todo gratis y open-source. Sin claves API hardcodeadas.

## Pantallas

1. **Hoy** — tareas del día con barra de progreso, filtro por categoría y FAB para añadir.
2. **Horario** — cuadrícula semanal Lun-Dom (07:00–22:00). Tap en celda crea bloque, tap en bloque edita.
3. **Rutinas** — asistente con 4 flujos (Exámenes, Proyectos, Deporte, Organización diaria). La IA genera y guarda las tareas en la base de datos.
4. **Ajustes** — cuenta, tema, idioma (es/en), URL/modelo de Ollama, exportar datos en JSON, eliminar cuenta.

---

## Setup

### 1. Flutter

Instala Flutter ≥ 3.19: https://docs.flutter.dev/get-started/install

Verifica:

```
flutter --version
flutter doctor
```

### 2. Supabase

1. Crea un proyecto gratis en https://supabase.com
2. En el SQL Editor, pega el contenido de `supabase/schema.sql` y ejecútalo.
3. Copia `Project URL` y `anon public key` desde *Settings → API*.
4. Pégalos en `.env` (copia `.env.example` si no existe):

```
SUPABASE_URL=https://XXXX.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOi...
```

5. **Auth → Providers**: habilita Email. Para desarrollo puedes desactivar la verificación de email.

### 3. Ollama (IA local)

Instala Ollama: https://ollama.ai

Descarga el modelo:

```
ollama pull llama3.2
```

Arráncalo (se queda escuchando en `localhost:11434`):

```
ollama serve
```

Si prefieres otro modelo, edita `OLLAMA_MODEL` en `.env` (por ejemplo `mistral`, `phi3`, `qwen2.5`).

### 4. (Opcional) Fallback a Anthropic

Si no tienes Ollama disponible, la app puede usar la API de Anthropic. Añade tu clave en `.env`:

```
ANTHROPIC_API_KEY=sk-ant-...
```

### 5. Instalar dependencias

```
flutter pub get
```

---

## Ejecutar

### Web
```
flutter run -d chrome
```

### Android (con dispositivo o emulador conectado)
```
flutter run -d android
```

### iOS (solo macOS, con Xcode instalado)
```
flutter run -d ios
```

### macOS
```
flutter run -d macos
```

### Windows
```
flutter run -d windows
```

### Linux
```
flutter run -d linux
```

---

## Compilar release

```
flutter build apk --release            # Android
flutter build appbundle --release      # Android (Play Store)
flutter build ios --release            # iOS
flutter build macos --release          # macOS
flutter build windows --release        # Windows
flutter build linux --release          # Linux
flutter build web --release            # Web (carpeta build/web)
```

---

## Estructura del proyecto

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── constants/        # Constantes globales
│   ├── services/         # Supabase, Ollama, notifications, storage
│   ├── theme/            # Colores, ThemeData
│   └── utils/            # Helpers de fechas
├── features/
│   ├── auth/             # Login, signup
│   ├── today/            # Pantalla "Hoy"
│   ├── schedule/         # Horario semanal
│   ├── routines/         # Wizard + 4 sub-wizards + AI planner
│   └── settings/         # Ajustes
├── shared/
│   ├── models/           # TaskModel, ScheduleBlockModel, RoutineModel
│   ├── providers/        # Riverpod (auth, settings, router)
│   └── widgets/          # AppShell, EmptyState, LoadingOverlay
└── l10n/                 # i18n manual (es/en)
```

---

## Notas

- La app funciona sin Supabase configurado, pero solo para inspeccionar la UI: las tareas no se persisten.
- La generación con IA exige Ollama corriendo o una `ANTHROPIC_API_KEY` válida.
- Las notificaciones locales no funcionan en Web.
- En la primera ejecución, registra una cuenta y verifica el email si lo tienes activado en Supabase.

## Licencia

MIT.
