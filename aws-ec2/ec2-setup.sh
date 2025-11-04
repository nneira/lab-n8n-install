#!/bin/bash

###############################################################################
# n8n AWS EC2 Setup
# Instala n8n en una instancia AWS EC2 con Docker
#
# Prerequisitos:
# - Cuenta AWS
# - Instancia EC2 Ubuntu 22.04 LTS creada
# - Security Group con puertos 22, 80, 443, 5678 abiertos
# - SSH conectado a la instancia
#
# Uso:
# ssh -i tu-key.pem ubuntu@TU-IP-PUBLICA
# curl -O https://raw.githubusercontent.com/nneira/lab-n8n-install/main/aws-ec2/ec2-setup.sh
# chmod +x ec2-setup.sh
# ./ec2-setup.sh
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
# PASO 1: Actualizar sistema
###############################################################################

print_section "PASO 1: Actualizando sistema Ubuntu"

print_info "Actualizando lista de paquetes..."
sudo apt-get update -qq

print_info "Instalando actualizaciones de seguridad..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq

print_success "Sistema actualizado"

###############################################################################
# PASO 2: Instalar Docker
###############################################################################

print_section "PASO 2: Instalando Docker"

# Verificar si Docker ya está instalado
if command -v docker &> /dev/null; then
    print_warning "Docker ya está instalado: $(docker --version)"
else
    print_info "Instalando dependencias..."
    sudo apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    print_info "Agregando repositorio oficial Docker..."
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

# Agregar usuario actual a grupo docker
print_info "Configurando permisos Docker..."
sudo usermod -aG docker $USER

print_success "Docker configurado"

###############################################################################
# PASO 3: Configurar Firewall
###############################################################################

print_section "PASO 3: Configurando Firewall (UFW)"

print_info "Instalando UFW (Uncomplicated Firewall)..."
sudo apt-get install -y -qq ufw

print_info "Configurando reglas de firewall..."
# Permitir SSH (CRÍTICO: no bloquear SSH o perderás acceso)
sudo ufw allow 22/tcp comment 'SSH'
# Permitir n8n
sudo ufw allow 5678/tcp comment 'n8n'
# Permitir HTTP/HTTPS (para Cloudflare después)
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Activar firewall
print_warning "Activando firewall (tu conexión SSH seguirá funcionando)..."
echo "y" | sudo ufw enable

print_success "Firewall configurado"

###############################################################################
# PASO 4: Crear directorio de datos
###############################################################################

print_section "PASO 4: Creando directorio de datos n8n"

N8N_DATA_DIR="/home/ubuntu/.n8n"

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
# PASO 5: Crear docker-compose.yml
###############################################################################

print_section "PASO 5: Creando configuración Docker"

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
      - WEBHOOK_URL=http://YOUR_IP:5678/
      - N8N_SECURE_COOKIE=false
      - N8N_COMMUNITY_PACKAGES_ENABLED=true
      - EXECUTIONS_TIMEOUT=300
      - EXECUTIONS_TIMEOUT_MAX=600
    volumes:
      - /home/ubuntu/.n8n:/home/node/.n8n
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:5678/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 45s
EOF

print_success "docker-compose.yml creado"

# Obtener IP pública de la instancia
print_info "Detectando IP pública..."

# Intentar con IMDSv2 (requiere token)
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s --max-time 2 2>/dev/null)

if [ -n "$TOKEN" ]; then
    PUBLIC_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
else
    # Fallback: IMDSv1 (sin token)
    PUBLIC_IP=$(curl -s --max-time 2 http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null)
fi

# Si metadata service falló, intentar con servicio externo
if [ -z "$PUBLIC_IP" ]; then
    print_warning "Metadata service no disponible, usando servicio externo..."
    PUBLIC_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null)
fi

if [ -n "$PUBLIC_IP" ]; then
    print_success "IP pública detectada: $PUBLIC_IP"

    # Actualizar WEBHOOK_URL en docker-compose.yml
    sed -i "s|WEBHOOK_URL=http://YOUR_IP:5678/|WEBHOOK_URL=http://$PUBLIC_IP:5678/|" docker-compose.yml
    print_success "WEBHOOK_URL configurada automáticamente"
else
    print_warning "No se pudo detectar IP pública automáticamente"
    print_info "Actualiza WEBHOOK_URL manualmente en docker-compose.yml"
fi

###############################################################################
# PASO 6: Iniciar n8n
###############################################################################

print_section "PASO 6: Iniciando n8n"

print_info "Descargando imagen n8n..."
sudo docker pull n8nio/n8n:latest

print_info "Iniciando contenedor..."
sudo docker compose up -d

# Esperar a que n8n esté listo
print_info "Esperando a que n8n inicie (30 segundos)..."
sleep 30

# Verificar que esté corriendo
if sudo docker ps | grep -q n8n; then
    print_success "n8n está corriendo!"
else
    print_error "Hubo un problema al iniciar n8n"
    echo ""
    echo "Ver logs con: sudo docker logs n8n"
    exit 1
fi

###############################################################################
# PASO 7: Información de acceso
###############################################################################

print_section "🎉 ¡INSTALACIÓN COMPLETA!"

echo ""
echo -e "${GREEN}n8n está corriendo en AWS EC2${NC}"
echo ""

if [ -n "$PUBLIC_IP" ]; then
    echo -e "${BLUE}Accede en tu navegador:${NC}"
    echo -e "  ${YELLOW}http://$PUBLIC_IP:5678${NC}"
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
echo "  Reiniciar n8n:"
echo "    docker restart n8n"
echo ""
echo "  Actualizar n8n:"
echo "    docker compose pull && docker compose up -d"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${BLUE}Próximos pasos:${NC}"
echo ""
echo "  1. Accede a n8n en tu navegador"
echo "  2. Completa el setup wizard (usuario/password)"
echo "  3. (Opcional) Configura dominio + SSL con Cloudflare"
echo "     Ver: cloudflare-ssl.md"
echo ""
echo -e "${GREEN}¡Listo para crear workflows en producción!${NC}"
echo ""
