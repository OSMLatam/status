# Configuración de Secrets en GitHub

## Pasos para configurar los secrets

### 1. Acceder a la configuración de Secrets

1. Ve a tu repositorio en GitHub: `https://github.com/OSMLatam/status`
2. Haz clic en **Settings** (Configuración) en la parte superior del repositorio
3. En el menú lateral izquierdo, busca y haz clic en **Secrets and variables** → **Actions**

### 2. Agregar los Secrets

Haz clic en el botón **New repository secret** (Nuevo secreto del repositorio) y agrega los siguientes:

#### Secret 1: TELEGRAM_BOT_TOKEN
- **Name:** `TELEGRAM_BOT_TOKEN`
- **Secret:** Pega aquí el token de tu bot (ejemplo: `123456789:ABCdefGHIjklMNOpqrsTUVwxyz`)
- Haz clic en **Add secret**

#### Secret 2: TELEGRAM_CHAT_ID
- **Name:** `TELEGRAM_CHAT_ID`
- **Secret:** Pega aquí tu Chat ID (ejemplo: `123456789`)
- Haz clic en **Add secret**

### 3. Verificar la configuración

Después de agregar los secrets, deberías ver ambos en la lista:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`

### 4. Probar las notificaciones

Para probar que funciona:
1. Puedes esperar a que el próximo health check se ejecute (cada 15 minutos)
2. O puedes ejecutar el workflow manualmente:
   - Ve a la pestaña **Actions**
   - Selecciona el workflow **Scheduled Health Check**
   - Haz clic en **Run workflow** → **Run workflow**

## Notas importantes

- Los secrets son **sensibles** y no se muestran en los logs de GitHub Actions
- Solo los workflows tienen acceso a estos secrets
- Si cambias un secret, el nuevo valor se usará en la próxima ejecución del workflow
- Los secrets están disponibles como variables de entorno en los workflows

## Verificación

Una vez configurado, cuando un servicio falle:
1. Recibirás una notificación inmediata en Telegram
2. Si el problema persiste 5 verificaciones consecutivas, se creará un issue en GitHub
3. Cuando el servicio se recupere, recibirás una notificación de recuperación

