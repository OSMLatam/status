# Sistema de Notificaciones

Este proyecto incluye un sistema de notificaciones automáticas que alerta cuando los servicios monitoreados tienen problemas.

## Funcionamiento

1. **Primera detección de problema**: Se envía una notificación inmediata por Telegram
2. **Problema persistente**: Si el problema persiste por 5 verificaciones consecutivas (~75 minutos), se crea automáticamente un issue en GitHub
3. **Recuperación**: Cuando el servicio vuelve a funcionar, se envía una notificación de recuperación y se cierra el issue si existe

## Configuración

### 1. Configurar Telegram (Recomendado)

#### Paso 1: Crear un bot de Telegram
1. Abre Telegram y busca `@BotFather`
2. Envía el comando `/newbot`
3. Sigue las instrucciones para crear tu bot
4. Guarda el **token** que te proporciona BotFather (ejemplo: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)

#### Paso 2: Obtener tu Chat ID
1. Busca tu bot en Telegram (el que acabas de crear)
2. Envía cualquier mensaje al bot
3. Visita: `https://api.telegram.org/bot<TOKEN>/getUpdates`
   - Reemplaza `<TOKEN>` con el token de tu bot
4. Busca el campo `"chat":{"id":123456789}` - ese número es tu Chat ID
5. Si quieres usar un grupo, agrega el bot al grupo y obtén el ID del grupo de la misma manera

#### Paso 3: Configurar Secrets en GitHub
1. Ve a tu repositorio en GitHub
2. Settings → Secrets and variables → Actions
3. Agrega los siguientes secrets:
   - `TELEGRAM_BOT_TOKEN`: El token de tu bot
   - `TELEGRAM_CHAT_ID`: Tu Chat ID o el ID del grupo

### 2. Configurar GitHub Issues (Automático)

El sistema usa automáticamente `GITHUB_TOKEN` que GitHub Actions proporciona por defecto. No necesitas configuración adicional.

Si quieres usar un token personalizado con más permisos:
1. Ve a GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Crea un token con permisos `repo`
3. Agrega el secret `GITHUB_TOKEN` con tu token personalizado

## Estructura de Archivos

- `scripts/send-notification.sh`: Script que maneja las notificaciones
- `scripts/health-check.sh`: Script principal que ejecuta los health checks
- `public/status/.service_states.json`: Archivo que trackea el estado de cada servicio

## Ejemplo de Notificaciones

### Telegram - Primera Alerta
```
🚨 ALERTA: Servicio caído

Servicio: Website
URL: https://osm.lat/
Estado: ❌ No disponible
Fecha: 2025-11-22 12:00:00
Ver detalles: https://status.osm.lat

⚠️ Se monitoreará el servicio. Si el problema persiste por 5 verificaciones consecutivas, se creará un issue en GitHub.
```

### Telegram - Issue Creado
```
📋 Issue creado en GitHub

Servicio: Website
Issue: #123
Estado: El problema ha persistido por 5 verificaciones consecutivas
Ver issue: https://github.com/OSMLatam/status/issues/123
```

### Telegram - Recuperación
```
✅ Servicio restaurado

Servicio: Website
URL: https://osm.lat/
Estado: ✅ Operacional
Fecha: 2025-11-22 13:30:00
Ver detalles: https://status.osm.lat
```

## Troubleshooting

### Las notificaciones de Telegram no llegan
- Verifica que los secrets estén configurados correctamente
- Asegúrate de que el bot esté activo y hayas enviado al menos un mensaje
- Verifica que el Chat ID sea correcto

### Los issues no se crean
- Verifica que el workflow tenga permisos para crear issues
- Revisa los logs del workflow en GitHub Actions
- Asegúrate de que el servicio haya fallado 5 veces consecutivas

### El archivo de estados no se persiste
- El archivo `.service_states.json` se guarda en el repositorio
- Verifica que el workflow tenga permisos de escritura

## Desactivar Notificaciones

Para desactivar temporalmente las notificaciones:
1. Elimina o vacía los secrets `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID`
2. Las notificaciones de Telegram se desactivarán automáticamente
3. Los issues de GitHub seguirán creándose si está configurado `GITHUB_TOKEN`

