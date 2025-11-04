# n8n Instalación Local con Docker

Instala n8n en tu máquina local (Mac, Linux, o Windows) usando Docker.

---

## 📋 Prerequisitos

Antes de empezar, necesitas:

1. **Docker Desktop instalado:**
   - Mac: https://docs.docker.com/desktop/install/mac-install/
   - Windows: https://docs.docker.com/desktop/install/windows-install/
   - Linux: https://docs.docker.com/engine/install/

2. **Docker corriendo:**
   - Abre Docker Desktop y espera que el ícono esté en verde
   - Verifica con: `docker --version`

---

## 🚀 Instalación Rápida

### Mac / Linux

```bash
# 1. Descarga el script
curl -O https://raw.githubusercontent.com/nneira/lab-n8n-install/main/docker-local/mac-linux-setup.sh

# 2. Dale permisos de ejecución
chmod +x mac-linux-setup.sh

# 3. Ejecuta
./mac-linux-setup.sh
```

### Windows (PowerShell como Administrador)

```powershell
# 1. Permitir ejecución de scripts (solo primera vez)
Set-ExecutionPolicy Bypass -Scope Process -Force

# 2. Descarga el script
Invoke-WebRequest -Uri https://raw.githubusercontent.com/nneira/lab-n8n-install/main/docker-local/windows-setup.ps1 -OutFile windows-setup.ps1

# 3. Ejecuta
.\windows-setup.ps1
```

---

## 🎯 Instalación Manual (Docker Compose)

Si prefieres más control:

### 1. Descarga docker-compose.yml

```bash
curl -O https://raw.githubusercontent.com/nneira/lab-n8n-install/main/docker-local/docker-compose.yml
```

### 2. Inicia n8n

```bash
docker compose up -d
```

### 3. Accede

Abre tu navegador en: http://localhost:5678

---

## ⚙️ Configuración

### Cambiar Puerto

Si el puerto 5678 está ocupado, edita `docker-compose.yml`:

```yaml
ports:
  - "5679:5678"  # Usa 5679 en tu máquina, n8n sigue en 5678 interno
```

Luego accede en: http://localhost:5679

### Cambiar Zona Horaria

Edita `docker-compose.yml`:

```yaml
environment:
  - TZ=America/Santiago  # Tu zona horaria (Chile)
```

Lista de zonas: https://en.wikipedia.org/wiki/List_of_tz_database_time_zones

### Primera Vez - Setup Wizard

La primera vez que accedes a n8n (`http://localhost:5678`), verás un **setup wizard** donde:

1. Creas tu usuario
2. Defines tu email
3. Estableces tu contraseña

**No hay credenciales por defecto** - tú las creas en el wizard.

**Tip:** Usa un email y password que recuerdes. Los datos se guardan en `~/.n8n` encriptados.

---

## 📁 ¿Dónde se Guardan los Datos?

n8n guarda todo en:

- **Mac/Linux:** `~/.n8n`
- **Windows:** `C:\Users\TU_USUARIO\.n8n`

Esto incluye:
- Workflows
- Credenciales (encriptadas)
- Historial de ejecuciones
- Configuración

**Backup recomendado:** Copia esta carpeta regularmente.

---

## 🔧 Comandos Útiles

### Ver Logs

```bash
docker logs n8n -f
```

### Detener n8n

```bash
docker stop n8n
```

### Iniciar n8n (después de detener)

```bash
docker start n8n
```

### Reiniciar n8n

```bash
docker restart n8n
```

### Actualizar n8n a última versión

```bash
docker pull n8nio/n8n:latest
docker stop n8n
docker rm n8n
docker compose up -d
```

### Eliminar todo (⚠️ CUIDADO)

```bash
docker stop n8n
docker rm n8n
# Si quieres borrar datos también:
rm -rf ~/.n8n  # Mac/Linux
# O en Windows:
Remove-Item -Recurse -Force $env:USERPROFILE\.n8n
```

---

## 🐛 Troubleshooting

### Error: "Port 5678 already in use"

**Solución 1:** Detén el proceso que usa el puerto

```bash
# Mac/Linux
lsof -i :5678
kill -9 <PID>

# Windows PowerShell
Get-NetTCPConnection -LocalPort 5678
Stop-Process -Id <PID> -Force
```

**Solución 2:** Cambia el puerto en `docker-compose.yml` (ver arriba)

---

### Error: "Docker daemon is not running"

**Solución:**
1. Abre Docker Desktop
2. Espera que el ícono esté en verde
3. Ejecuta el script nuevamente

---

### Error: "Cannot connect to localhost:5678"

**Posibles causas:**

1. n8n aún está iniciando (espera 30 segundos más)
2. Firewall bloqueando (desactiva temporalmente)
3. Contenedor no corriendo

Verifica:

```bash
docker ps  # Debe mostrar contenedor 'n8n'
```

Si no aparece:

```bash
docker logs n8n  # Ver error
```

---

### Workflows desaparecieron

**Causa:** Volumen no montado correctamente.

**Solución:**

```bash
# Verifica que el directorio exista
ls ~/.n8n  # Mac/Linux
dir $env:USERPROFILE\.n8n  # Windows

# Reinicia con volumen correcto
docker stop n8n
docker rm n8n
docker compose up -d
```

---


## 📄 Archivos en Esta Carpeta

- `mac-linux-setup.sh` - Script automático Mac/Linux
- `windows-setup.ps1` - Script automático Windows
- `docker-compose.yml` - Configuración Docker
- `README.md` - Este archivo

---


**Autor:** Nicolás Neira
**Canal:** https://youtube.com/@NicolasNeiraGarcia
