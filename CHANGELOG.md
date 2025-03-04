# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2025-02-XX

### Añadido
- Exportación de canciones a PDF con formato mejorado
  - Soporte para múltiples páginas
  - Acordes en color azul
  - Secciones (entre guiones bajos) en amarillo
  - Notas (entre corchetes) en azul
  - Manejo mejorado de caracteres especiales
- Selección múltiple de canciones para exportación
  - Selección con toque largo
  - Checkbox para selección rápida
  - Botón flotante para exportar selección
- Sistema de copias de seguridad
  - Exportación de canciones del grupo
  - Restauración desde archivo de backup
  - Importación como borradores

### Cambiado
- Interfaz más limpia en la lista de canciones
  - Eliminación de tags visuales para mejor legibilidad
  - Diseño más compacto y eficiente
- Mejora en la navegación de playlists
  - Acceso directo a detalles de playlist
  - Contador de canciones en la lista

### Corregido
- Navegación a detalles de playlist desde la lista
- Manejo de caracteres especiales en la exportación PDF
- Visualización de canciones en modo selección

## [1.1.0] - 2025-01-XX

### Añadido
- Navegación por gestos entre canciones en la lista de reproducción
  - Deslizar horizontalmente para cambiar de canción
  - Mantiene el estado de transposición y metrónomo
  - Transiciones suaves entre canciones
- Minireproductor de YouTube móvil en la pantalla de detalles de canción
  - Arrastrable a cualquier posición de la pantalla
  - Controles de reproducción y barra de progreso
  - Botón para cerrar el reproductor
- Botón de cierre para el metrónomo
- Resaltado en amarillo y negrita para texto entre guiones bajos (ej: _coro_)
- Menú de transposición agrupado para evitar cambios accidentales
- Navegación directa a detalles de canción desde la búsqueda
- Botón de información con guía de símbolos musicales
  - Explicación de acordes, estructuras y comentarios
  - Ejemplos visuales de cada símbolo
  - Consejos de uso
- Nueva pantalla de configuración accesible desde el menú de perfil

### Cambiado
- Unificación del diseño de la pantalla de detalles de canción
  - Mismo diseño al acceder desde playlist o directamente
  - Interfaz más limpia y moderna
  - Mejor organización de controles y funcionalidades
- Reorganización de los controles de transposición en un menú desplegable
- Mejora en la visibilidad de las tonalidades en la lista de reproducción
- Optimización del rendimiento en la carga de canciones
- Mejora en el movimiento del minireproductor para seguir el gesto del usuario
- Reorganización del menú de perfil con acceso directo a configuración

### Corregido
- Actualización correcta de la lista de canciones al volver de la pantalla de edición
- Manejo mejorado de errores en la transposición de acordes
- Validación de URLs de YouTube

## [1.0.0] - 2025-XX-XX

### Características iniciales
- Gestión de canciones y listas de reproducción
- Sistema de transposición de acordes
- Modo teleprompter
- Metrónomo integrado
- Búsqueda y filtrado de canciones
- Sistema de etiquetas
- Colaboración en tiempo real
- Gestión de grupos y roles de usuario

## [2.0.1] - 2024-05-20

### Added
- Sistema de actualización forzada/opcional
- Integración con Firestore para gestión remota de versiones
- Lógica de comparación semántica de versiones
- Nueva pantalla de Splash con chequeo de versión

### Changed
- Flujo de navegación inicial para incluir chequeo de versión
- Actualización de dependencias: url_launcher a 6.2.0

### Improved
- Manejo de actualizaciones críticas con modal no descartable
- Visualización dinámica de release notes desde Firestore

### Correcciones
- 🛠 Parámetro faltante `isEditing` en `EditSongScreen`
- 🚪 Cierre automático de menús al navegar entre pantallas
- 🔄 Sincronización Firestore-UI para cambios de BPM en tiempo real
- 🎚 Estado persistente en transposiciones múltiples

### Técnicas
- 📱 Prioridad de hilo `THREAD_PRIORITY_URGENT_AUDIO` en Android
- 🧹 Limpieza de listeners y timers no utilizados
- 📦 Actualización a `audioplayers: ^5.2.1`

## [Unreleased]
### Added
- 🚧 Pantalla temporal de "Videos en Desarrollo" con mensaje informativo
- 🛠️ Sistema de notificación de estado de desarrollo en vistas de video

### Changed
- ♻️ Actualización de `youtube_player_flutter` a v13.1.0
- 🎥 Mejoras en la configuración del reproductor de YouTube Shorts
- 🖼️ Rediseño del overlay de información de videos

### Fixed
- 🐛 Posicionamiento correcto de elementos en Stack
- 🔧 Manejo de URLs de YouTube Shorts con diferentes formatos
- 🚑 Corrección de errores de referencia a controladores

### Removed
- 🔇 Eliminación temporal del reproductor de videos funcional
- 🗑️ Código obsoleto de la implementación anterior

## [2.0.2] - 2024-05-20

### Added
- Sistema de aviso de mantenimiento preventivo
- Integración con Firestore para gestión remota de estados
- Diálogo de mantenimiento no descartable

### Improved
- Flujo de chequeo inicial con prioridad a mantenimiento
- Manejo de errores en conexión con Firestore

## [2.0.3] - 2024-05-20

### Added
- Sistema de cooldown para recordatorios de actualización
- Integración con SharedPreferences para tracking de recordatorios
- Configuración remota de intervalo entre recordatorios

### Improved
- Experiencia de usuario al posponer actualizaciones
- Manejo de frecuencia de recordatorios no intrusivos

## [2.1.0] - 2024-03-03

### Added
- Sistema de actualización en tiempo real con Firestore
- Manejo de mantenimiento con mensajes centrados
- Registro detallado de eventos en consola

### Changed
- Mejorado el sistema de expiración de sesión
- Optimizado el manejo de estados de la aplicación
- Actualizadas dependencias de Firebase y Riverpod

### Fixed
- Errores de sincronización de estado de usuario
- Problemas de caché en chequeo de actualizaciones
- Centrado de texto en diálogos de mantenimiento 