#!/bin/bash

###############################################################################
# n8n Google Cloud Platform Setup
# Instala n8n en una VM de GCP con $300 créditos gratis
#
# Prerequisitos:
# - Cuenta Google Cloud (nuevo usuario = $300 créditos gratis)
# - Tarjeta de crédito (no se cobra dentro de créditos)
# - VM Ubuntu 22.04 creada en Compute Engine
# - SSH conectado a la VM
#
# Uso:
# gcloud compute ssh nombre-vm --zone=us-central1-a
# curl -O https://raw.githubusercontent.com/nneira/lab-n8n-install/main/gcp/gcp-setup.sh
# chmod +x gcp-setup.sh
# ./gcp-setup.sh
#
# Autor: Nicolás Neira (https://youtube.com/@NicolasNeiraGarcia)
# Créditos: $300 gratis por 90 días
###############################################################################

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

###############################################################################
# PASO 1: Actualizar sistema
###############################################################################

print_section "PASO 1: Actualizando sistema Ubuntu"

print_info "Actualizando paquetes..."
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

print_success "Sistema actualizado"

###############################################################################
# PASO 2: Instalar Docker
###############################################################################

print_section "PASO 2: Instalando Docker"

if command -v docker &> /dev/null; then
    print_warning "Docker ya instalado: $(docker --version)"
else
    print_info "Instalando dependencias..."
    sudo apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    print_info "Agregando repositorio Docker..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    print_info "Instalando Docker Engine..."
    sudo apt-get update -qq
    sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    print_success "Docker instalado: $(docker --version)"
fi

sudo usermod -aG docker $USER
print_success "Docker configurado"

###############################################################################
# PASO 3: Configurar Firewall (GCP tiene firewall a nivel cloud)
###############################################################################

print_section "PASO 3: Configurando Firewall Local"

print_info "Instalando UFW..."
sudo apt-get install -y -qq ufw

print_info "Configurando reglas..."
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 5678/tcp comment 'n8n'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

echo "y" | sudo ufw enable

print_success "Firewall local configurado"

print_warning "IMPORTANTE: También debes configurar firewall en GCP Console"
print_info "Ver instrucciones en: firewall-config.md"

###############################################################################
# PASO 4: Crear directorio de datos
###############################################################################

print_section "PASO 4: Creando directorio de datos n8n"

N8N_DATA_DIR="$HOME/.n8n"

if [ -d "$N8N_DATA_DIR" ]; then
    print_warning "Directorio $N8N_DATA_DIR ya existe"
else
    mkdir -p "$N8N_DATA_DIR"
    print_success "Directorio creado: $N8N_DATA_DIR"
fi

# CRÍTICO: Ajustar permisos para que Docker pueda escribir
# El contenedor n8n corre internamente como UID 1000:1000
print_info "Ajustando permisos del directorio..."
sudo chown -R 1000:1000 "$N8N_DATA_DIR"
print_success "Permisos configurados (UID 1000:1000)"

###############################################################################
# PASO 5: Detectar IP Externa GCP
###############################################################################

print_section "PASO 5: Detectando IP Externa"

# GCP metadata service
print_info "Obteniendo IP externa..."

# Intentar con metadata service de GCP
EXTERNAL_IP=$(curl -s --max-time 3 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip 2>/dev/null)

# Si metadata service falló, intentar con servicio externo
if [ -z "$EXTERNAL_IP" ]; then
    print_warning "Metadata service no disponible, usando servicio externo..."
    EXTERNAL_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null)
fi

if [ -n "$EXTERNAL_IP" ]; then
    print_success "IP externa detectada: $EXTERNAL_IP"
else
    print_warning "No se pudo detectar IP externa automáticamente"
    print_info "Puedes obtenerla en GCP Console > Compute Engine > VM instances"
    EXTERNAL_IP="YOUR_EXTERNAL_IP"
fi

###############################################################################
# PASO 6: Crear docker-compose.yml
###############################################################################

print_section "PASO 6: Creando configuración Docker"

cat > docker-compose.yml <<EOF
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - TZ=America/Santiago
      - WEBHOOK_URL=http://${EXTERNAL_IP}:5678/
      - N8N_SECURE_COOKIE=false
      - N8N_COMMUNITY_PACKAGES_ENABLED=true
      - EXECUTIONS_TIMEOUT=300
      - EXECUTIONS_TIMEOUT_MAX=600
    volumes:
      - $HOME/.n8n:/home/node/.n8n
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 45s
EOF

print_success "docker-compose.yml creado"

###############################################################################
# PASO 7: Iniciar n8n
###############################################################################

print_section "PASO 7: Iniciando n8n"

print_info "Descargando imagen n8n..."
sudo docker pull n8nio/n8n:latest

print_info "Iniciando contenedor..."
sudo docker compose up -d

print_info "Esperando inicio (30 segundos)..."
sleep 30

if sudo docker ps | grep -q n8n; then
    print_success "n8n está corriendo!"
else
    print_error "Problema al iniciar n8n"
    echo ""
    echo "Ver logs: sudo docker logs n8n"
    exit 1
fi

###############################################################################
# PASO 8: Información de acceso
###############################################################################

print_section "🎉 ¡INSTALACIÓN COMPLETA!"

echo ""
echo -e "${GREEN}n8n está corriendo en Google Cloud Platform${NC}"
echo ""

if [ "$EXTERNAL_IP" != "YOUR_EXTERNAL_IP" ]; then
    echo -e "${BLUE}Accede en tu navegador:${NC}"
    echo -e "  ${YELLOW}http://$EXTERNAL_IP:5678${NC}"
    echo ""
fi

echo -e "${BLUE}Primera vez:${NC}"
echo -e "  n8n te mostrará un ${YELLOW}setup wizard${NC}"
echo -e "  Crea tu usuario y contraseña ahí"
echo ""
echo -e "${RED}⚠️  TIP: Usa email y password seguros (servidor público)${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Comandos útiles:"
echo ""
echo "  Ver logs:"
echo "    docker logs n8n -f"
echo ""
echo "  Reiniciar:"
echo "    docker restart n8n"
echo ""
echo "  Actualizar:"
echo "    docker compose pull && docker compose up -d"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${YELLOW}⚠️  SIGUIENTE PASO CRÍTICO:${NC}"
echo ""
echo "  Configura firewall GCP para permitir puerto 5678"
echo "  Ver: firewall-config.md"
echo ""
echo -e "${BLUE}Créditos GCP:${NC}"
echo "  \$300 gratis por 90 días"
echo "  Monitorea en: console.cloud.google.com/billing"
echo ""
echo -e "${GREEN}¡Listo para workflows en producción!${NC}"
echo ""
