# Estado de servicios de OSM.lat

Página de estado pública que monitorea los servicios que hospeda [osm.lat](https://osm.lat) (OpenStreetMap Latinoamérica). Permite ver qué servicios están operativos o con problemas y reportar incidentes mediante issues de GitHub.

Este proyecto está basado en [Fettle](https://github.com/mehatab/fettle), una página de estado open source impulsada por GitHub Actions, Issues y Pages.

---

## Dónde ver la página

**URL:** [https://status.osm.lat](https://status.osm.lat)

La página se publica en GitHub Pages y el dominio está configurado en el archivo `CNAME`.

Para conocer el listado de servicios que ofrece osm.lat puedes visitar: [Servicios OSM LatAm](https://pad.osm.lat/3796WUVFTlOyg8ZPUocH2Q).

---

## Qué hace este proyecto

### 1. Página de estado (lo que ves en status.osm.lat)

- **Estado global del sistema:** indica si todos los servicios están operativos, hay una interrupción parcial o una caída general.
- **Lista de servicios:** cada uno con su nombre, porcentaje de tiempo operativo en los últimos 90 días y una barra de colores por día (verde = bien, naranja = parcial, rojo = caído).
- **Incidentes recientes:** issues de GitHub con la etiqueta `incident`, agrupados por mes, con estado (resuelto / en investigación) y fechas.

### 2. Monitoreo automático

- Un **workflow de GitHub Actions** se ejecuta **cada 15 minutos** (configurable en `.github/workflows/health-check.yml`).
- Para cada servicio definido en `public/urls.cfg` se hace una petición HTTP; se considera éxito si el código es 200, 202, 301, 302 o 307.
- Cada resultado (fecha/hora, éxito/fallo, tiempo de respuesta) se guarda en `public/status/<servicio>_report.log`.
- Solo se conservan los **últimos 90 días** de datos por servicio (~8640 líneas por log).
- Si hay cambios, se hace commit y push automático con el mensaje `[Automated] Update Health Check Logs`.

### 3. Notificaciones

- **Primera falla:** se envía una alerta inmediata por **Telegram** (si está configurado).
- **Problema persistente:** tras **5 verificaciones consecutivas fallidas** (~75 minutos), se crea automáticamente un **issue en GitHub** con etiquetas `incident` y `automated`, y se notifica por Telegram.
- **Recuperación:** cuando el servicio vuelve a responder, se envía notificación de recuperación por Telegram y se cierra el issue si existía.

La configuración de Telegram y los secrets se explica en:

- [NOTIFICATIONS.md](./NOTIFICATIONS.md) — funcionamiento y configuración de notificaciones.
- [CONFIGURACION_SECRETS.md](./CONFIGURACION_SECRETS.md) — cómo configurar los secrets en GitHub.

### 4. Mantenimiento del repositorio (trim del historial)

- El health check genera muchos commits. Para evitar que el repositorio crezca sin límite, un **workflow de trim** (`.github/workflows/trim-history.yml`) se ejecuta **cada domingo a las 03:00 UTC** y opcionalmente de forma manual.
- Ese workflow deja solo los **últimos 500 commits** (aprox. 5 días de historial) y hace force-push. El número de commits a conservar es configurable en el workflow y en `scripts/trim-history-last-n.sh`.

---

## Cómo se configura

### Servicios monitoreados

Edita **`public/urls.cfg`**. Cada línea tiene el formato:

```text
NombreDelServicio=https://url-del-servicio/
```

Ejemplo:

```text
Website=https://osm.lat/
Pad=https://pad.osm.lat
```

Los nombres no pueden tener espacios; se usan para generar los archivos `public/status/<NombreDelServicio>_report.log`.

### Notificaciones (Telegram e issues)

1. **Telegram (opcional):** crea un bot con [@BotFather](https://t.me/BotFather), obtén el token y el Chat ID, y añade en GitHub (Settings → Secrets and variables → Actions):
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_CHAT_ID`

2. **Issues automáticos:** se usa el `GITHUB_TOKEN` que proporciona GitHub Actions; no hace falta configurar nada más para la creación y cierre de issues.

Detalle completo en [NOTIFICATIONS.md](./NOTIFICATIONS.md) y [CONFIGURACION_SECRETS.md](./CONFIGURACION_SECRETS.md).

### Despliegue de la página

- En el repositorio: **Settings → Pages**.
- Origen: **GitHub Actions** (el workflow `.github/workflows/pages.yml` se dispara en cada push a `main` y publica la carpeta `out` de Next.js).

### Cambiar el intervalo de monitoreo

En **`.github/workflows/health-check.yml`** modifica la línea `cron`:

```yaml
schedule:
  - cron: "0/15 * * * *"   # cada 15 minutos (actual)
```

Ejemplos: `"0 * * * *"` = cada hora; `"0 0/6 * * *"` = cada 6 horas.

---

## Reportar un incidente manualmente

1. Ve a [Issues](https://github.com/OSMLatam/status/issues).
2. Crea un nuevo issue (puedes usar la plantilla **"Problema en componente de OSM.lat"**).
3. Añade la etiqueta **`incident`** al issue para que aparezca en la sección de incidentes de la página.

---

## Cómo funciona (resumen técnico)

| Parte            | Detalle                                                                 |
|------------------|-------------------------------------------------------------------------|
| **Hosting**      | GitHub Pages (build con Next.js y export estático).                     |
| **Monitoreo**    | Workflow cada 15 min; escribe en `public/status/*.log` y hace commit.   |
| **Estado**       | `public/status/.service_states.json` guarda fallos consecutivos e ID de issue por servicio. |
| **Incidentes**   | Issues con label `incident`; la página los obtiene vía API de GitHub.  |
| **Datos en la UI** | La página lee los logs desde `raw.githubusercontent.com/OSMLatam/status/main/public/status/` y los issues desde la API del repo. |

---

## Si haces fork de este repositorio

Para adaptar tu fork (basado en [Fettle](https://github.com/mehatab/fettle)):

1. **URLs de servicios:** edita `public/urls.cfg`.
2. **URLs en el código:** sustituye `OSMLatam/status` por `tu-usuario/tu-repo` en:
   - `src/incidents/hooks/useIncidents.tsx` (API de issues)
   - `src/services/hooks/useServices.tsx` (URL de los logs)
   - `src/services/hooks/useSystemStatus.tsx` (URL de los logs)
3. **Pages:** en Settings → Pages, elige **GitHub Actions** como origen.
4. **Label:** crea la etiqueta `incident` en tu repo para que los incidentes se muestren en la página.

---

## Contribuir

Las contribuciones son bienvenidas: pull requests, reporte de bugs o sugerencias mediante [issues](https://github.com/OSMLatam/status/issues).
