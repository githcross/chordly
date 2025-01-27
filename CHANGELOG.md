# Changelog

Todos los cambios notables en este proyecto serán documentados en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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