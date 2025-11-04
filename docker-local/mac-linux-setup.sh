#!/bin/bash

###############################################################################
# n8n Local Setup - Mac/Linux
# Instala n8n usando Docker en tu máquina local
#
# Prerequisitos:
# - Docker Desktop instalado y corriendo
# - Bash shell (Terminal en Mac, Bash en Linux)
#
# Uso:
# chmod +x mac-linux-setup.sh
# ./mac-linux-setup.sh
#
# Autor: Nicolás Neira (https://youtube.com/@NicolasNeiraGarcia)
###############################################################################

set -e  # Detener si hay error

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para imprimir con color
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

###############################################################################
# PASO 1: Verificar Docker
###############################################################################

print_section "PASO 1: Verificando Docker"

if ! command -v docker &> /dev/null; then
    print_error "Docker no está instalado"
    echo ""
    echo "Por favor instala Docker Desktop desde:"
    echo "  Mac: https://docs.docker.com/desktop/install/mac-install/"
    echo "  Linux: https://docs.docker.com/engine/install/"
    echo ""
    exit 1
fi

print_success "Docker está instalado: $(docker --version)"

# Verificar que Docker daemon esté corriendo
if ! docker info &> /dev/null; then
    print_error "Docker daemon no está corriendo"
    echo ""
    echo "Por favor:"
    echo "  1. Abre Docker Desktop"
    echo "  2. Espera que el ícono en la barra superior esté en verde"
    echo "  3. Vuelve a ejecutar este script"
    echo ""
    exit 1
fi

print_success "Docker daemon está corriendo"

###############################################################################
# PASO 2: Verificar puerto 5678
###############################################################################

print_section "PASO 2: Verificando puerto 5678"

# Detectar OS para comando correcto
if [[ "$OSTYPE" == "darwin"* ]]; then
    # Mac
    PORT_IN_USE=$(lsof -i :5678 -t 2>/dev/null || true)
else
    # Linux
    PORT_IN_USE=$(lsof -i :5678 -t 2>/dev/null || ss -tuln | grep :5678 || true)
fi

if [ -n "$PORT_IN_USE" ]; then
    print_warning "Puerto 5678 está en uso"
    echo ""
    echo "Opciones:"
    echo "  1. Detener el proceso que usa el puerto"
    echo "  2. Cambiar puerto en docker-compose.yml (línea 15: '5679:5678')"
    echo ""
    read -p "¿Quieres que intente detener contenedores Docker en ese puerto? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        print_info "Deteniendo contenedores en puerto 5678..."
        docker ps --filter "publish=5678" -q | xargs -r docker stop || true
        print_success "Contenedores detenidos"
    else
        print_warning "Por favor libera el puerto 5678 manualmente y vuelve a ejecutar"
        exit 1
    fi
else
    print_success "Puerto 5678 disponible"
fi

###############################################################################
# PASO 3: Crear directorio de datos n8n
###############################################################################

print_section "PASO 3: Creando directorio de datos"

# Directorio donde se guardarán los workflows y credenciales
N8N_DATA_DIR="$HOME/.n8n"

if [ -d "$N8N_DATA_DIR" ]; then
    print_warning "Directorio $N8N_DATA_DIR ya existe"
    print_info "Se usará el existente (workflows previos se mantendrán)"
else
    mkdir -p "$N8N_DATA_DIR"
    print_success "Directorio creado: $N8N_DATA_DIR"
fi

###############################################################################
# PASO 4: Crear docker-compose.yml
###############################################################################

print_section "PASO 4: Creando configuración Docker"

# Verificar si ya existe
if [ -f "docker-compose.yml" ]; then
    print_warning "docker-compose.yml ya existe"
    read -p "¿Quieres reemplazarlo? (s/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
        print_info "Usando docker-compose.yml existente"
        SKIP_CREATE_COMPOSE=true
    fi
fi

if [ "$SKIP_CREATE_COMPOSE" != "true" ]; then
    print_info "Creando docker-compose.yml..."
    cat > docker-compose.yml <<'EOF'
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
EOF
    print_success "docker-compose.yml creado"
fi

print_success "Configuración Docker lista"

###############################################################################
# PASO 5: Descargar imagen n8n
###############################################################################

print_section "PASO 5: Descargando n8n (puede tardar 1-2 min)"

print_info "Descargando imagen Docker de n8n..."
docker pull n8nio/n8n:latest

print_success "Imagen n8n descargada"

###############################################################################
# PASO 6: Iniciar n8n
###############################################################################

print_section "PASO 6: Iniciando n8n"

print_info "Levantando contenedor n8n..."

docker compose up -d

# Esperar a que n8n esté listo
print_info "Esperando a que n8n inicie (15 segundos)..."
sleep 15

# Verificar que el contenedor esté corriendo
if docker ps | grep -q n8n; then
    print_success "n8n está corriendo!"
else
    print_error "Hubo un problema al iniciar n8n"
    echo ""
    echo "Ver logs con: docker logs n8n"
    exit 1
fi

###############################################################################
# PASO 7: Información de acceso
###############################################################################

print_section "🎉 ¡INSTALACIÓN COMPLETA!"

echo ""
echo -e "${GREEN}n8n está corriendo en tu máquina${NC}"
echo ""
echo -e "${BLUE}Accede en tu navegador:${NC}"
echo -e "  ${YELLOW}http://localhost:5678${NC}"
echo ""
echo -e "${BLUE}Primera vez:${NC}"
echo -e "  n8n te mostrará un ${YELLOW}setup wizard${NC}"
echo -e "  Crea tu usuario y contraseña ahí"
echo ""
echo -e "${BLUE}⚠️  TIP: Usa un email y password que recuerdes${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Comandos útiles:"
echo ""
echo "  Ver logs:"
echo "    docker logs n8n -f"
echo ""
echo "  Detener n8n:"
echo "    docker stop n8n"
echo ""
echo "  Iniciar n8n nuevamente:"
echo "    docker start n8n"
echo ""
echo "  Eliminar contenedor:"
echo "    docker rm -f n8n"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}Datos guardados en:${NC} $N8N_DATA_DIR"
echo ""
echo -e "${GREEN}¡Listo para crear workflows!${NC}"
echo ""
echo "  https://youtube.com/@NicolasNeiraGarcia"
echo ""
