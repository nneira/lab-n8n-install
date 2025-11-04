###############################################################################
# n8n Local Setup - Windows PowerShell
# Instala n8n usando Docker en tu PC Windows
#
# Prerequisitos:
# - Docker Desktop instalado y corriendo
# - PowerShell (viene con Windows)
#
# Uso:
# 1. Click derecho en PowerShell → "Ejecutar como Administrador"
# 2. Set-ExecutionPolicy Bypass -Scope Process -Force
# 3. .\windows-setup.ps1
#
# Autor: Nicolás Neira (https://youtube.com/@NicolasNeiraGarcia)
###############################################################################

# Configuración
$ErrorActionPreference = "Stop"

# Funciones para output con color
function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host "  $Title" -ForegroundColor Blue
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Blue
    Write-Host ""
}

###############################################################################
# PASO 1: Verificar Docker
###############################################################################

Write-Section "PASO 1: Verificando Docker"

try {
    $dockerVersion = docker --version
    Write-Success "Docker está instalado: $dockerVersion"
} catch {
    Write-Error "Docker no está instalado"
    Write-Host ""
    Write-Host "Por favor instala Docker Desktop desde:"
    Write-Host "  https://docs.docker.com/desktop/install/windows-install/"
    Write-Host ""
    Write-Host "Después de instalar, reinicia tu PC y vuelve a ejecutar este script"
    Write-Host ""
    exit 1
}

# Verificar que Docker daemon esté corriendo
try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker daemon no responde"
    }
    Write-Success "Docker daemon está corriendo"
} catch {
    Write-Error "Docker daemon no está corriendo"
    Write-Host ""
    Write-Host "Por favor:"
    Write-Host "  1. Abre Docker Desktop desde el menú inicio"
    Write-Host "  2. Espera que el ícono en la bandeja del sistema esté en verde"
    Write-Host "  3. Vuelve a ejecutar este script"
    Write-Host ""
    exit 1
}

###############################################################################
# PASO 2: Verificar puerto 5678
###############################################################################

Write-Section "PASO 2: Verificando puerto 5678"

$portInUse = Get-NetTCPConnection -LocalPort 5678 -ErrorAction SilentlyContinue

if ($portInUse) {
    Write-Warning "Puerto 5678 está en uso"
    Write-Host ""
    Write-Host "Opciones:"
    Write-Host "  1. Detener el proceso que usa el puerto"
    Write-Host "  2. Cambiar puerto en docker-compose.yml (línea 15: '5679:5678')"
    Write-Host ""

    $response = Read-Host "¿Quieres que intente detener contenedores Docker en ese puerto? (S/N)"

    if ($response -match "[SsYy]") {
        Write-Info "Deteniendo contenedores en puerto 5678..."
        $containers = docker ps --filter "publish=5678" -q
        if ($containers) {
            docker stop $containers
            Write-Success "Contenedores detenidos"
            Start-Sleep -Seconds 2
        } else {
            Write-Warning "No hay contenedores Docker usando el puerto"
            Write-Host "El puerto puede estar usado por otra aplicación"
            Write-Host "Usa 'netstat -ano | findstr :5678' para identificar el proceso"
            exit 1
        }
    } else {
        Write-Warning "Por favor libera el puerto 5678 manualmente y vuelve a ejecutar"
        exit 1
    }
} else {
    Write-Success "Puerto 5678 disponible"
}

###############################################################################
# PASO 3: Crear directorio de datos n8n
###############################################################################

Write-Section "PASO 3: Creando directorio de datos"

# Directorio donde se guardarán los workflows y credenciales
$N8N_DATA_DIR = "$env:USERPROFILE\.n8n"

if (Test-Path $N8N_DATA_DIR) {
    Write-Warning "Directorio $N8N_DATA_DIR ya existe"
    Write-Info "Se usará el existente (workflows previos se mantendrán)"
} else {
    New-Item -ItemType Directory -Path $N8N_DATA_DIR -Force | Out-Null
    Write-Success "Directorio creado: $N8N_DATA_DIR"
}

###############################################################################
# PASO 4: Crear docker-compose.yml
###############################################################################

Write-Section "PASO 4: Creando configuración Docker"

$skipCreate = $false

if (Test-Path "docker-compose.yml") {
    Write-Warning "docker-compose.yml ya existe"
    $response = Read-Host "¿Quieres reemplazarlo? (S/N)"

    if ($response -match "[SsYy]") {
        Remove-Item "docker-compose.yml" -Force
    } else {
        Write-Info "Usando docker-compose.yml existente"
        $skipCreate = $true
    }
}

if (-not $skipCreate) {
    Write-Info "Creando docker-compose.yml..."

    $composeContent = @"
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - TZ=America/Santiago
      - WEBHOOK_URL=http://localhost:5678/
      - N8N_SECURE_COOKIE=false
      - N8N_COMMUNITY_PACKAGES_ENABLED=true
      - EXECUTIONS_TIMEOUT=300
      - EXECUTIONS_TIMEOUT_MAX=600
    volumes:
      - ~/.n8n:/home/node/.n8n
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 45s
"@

    Set-Content -Path "docker-compose.yml" -Value $composeContent
    Write-Success "docker-compose.yml creado"
}

Write-Success "Configuración Docker lista"

###############################################################################
# PASO 5: Descargar imagen n8n
###############################################################################

Write-Section "PASO 5: Descargando n8n (puede tardar 1-2 min)"

Write-Info "Descargando imagen Docker de n8n..."
docker pull n8nio/n8n:latest

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al descargar imagen n8n"
    exit 1
}

Write-Success "Imagen n8n descargada"

###############################################################################
# PASO 6: Iniciar n8n
###############################################################################

Write-Section "PASO 6: Iniciando n8n"

Write-Info "Levantando contenedor n8n..."

docker compose up -d

if ($LASTEXITCODE -ne 0) {
    Write-Error "Error al iniciar n8n"
    Write-Host ""
    Write-Host "Ver logs con: docker logs n8n"
    exit 1
}

# Esperar a que n8n esté listo
Write-Info "Esperando a que n8n inicie (15 segundos)..."
Start-Sleep -Seconds 15

# Verificar que el contenedor esté corriendo
$running = docker ps | Select-String "n8n"

if ($running) {
    Write-Success "n8n está corriendo!"
} else {
    Write-Error "Hubo un problema al iniciar n8n"
    Write-Host ""
    Write-Host "Ver logs con: docker logs n8n"
    exit 1
}

###############################################################################
# PASO 7: Información de acceso
###############################################################################

Write-Section "🎉 ¡INSTALACIÓN COMPLETA!"

Write-Host ""
Write-Host "n8n está corriendo en tu PC" -ForegroundColor Green
Write-Host ""
Write-Host "Accede en tu navegador:" -ForegroundColor Blue
Write-Host "  http://localhost:5678" -ForegroundColor Yellow
Write-Host ""
Write-Host "Primera vez:" -ForegroundColor Blue
Write-Host "  n8n te mostrará un setup wizard" -ForegroundColor Yellow
Write-Host "  Crea tu usuario y contraseña ahí"
Write-Host ""
Write-Host "⚠️  TIP: Usa un email y password que recuerdes" -ForegroundColor Blue
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Comandos útiles:"
Write-Host ""
Write-Host "  Ver logs:"
Write-Host "    docker logs n8n -f"
Write-Host ""
Write-Host "  Detener n8n:"
Write-Host "    docker stop n8n"
Write-Host ""
Write-Host "  Iniciar n8n nuevamente:"
Write-Host "    docker start n8n"
Write-Host ""
Write-Host "  Eliminar contenedor:"
Write-Host "    docker rm -f n8n"
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""
Write-Host "Datos guardados en: $N8N_DATA_DIR" -ForegroundColor Blue
Write-Host ""
Write-Host "¡Listo para crear workflows!" -ForegroundColor Green
Write-Host ""
Write-Host "  https://youtube.com/@NicolasNeiraGarcia"
Write-Host ""
