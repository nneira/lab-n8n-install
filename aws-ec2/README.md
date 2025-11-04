# n8n en AWS EC2

Instala n8n en una instancia AWS EC2 con Docker.

---

## 📋 Prerequisitos

1. **Cuenta AWS**

2. **Instancia EC2 con Ubuntu 22.04 LTS:**
   - ⚠️ **IMPORTANTE:** Este script está diseñado para Ubuntu/Debian
   - Si usas Amazon Linux, CentOS o RHEL, deberás adaptar los comandos
   - Recomendado: Ubuntu Server 22.04 LTS (más soporte, documentación)

3. **SSH Client:**
   - Mac/Linux: Terminal (viene por defecto)
   - Windows: PowerShell o PuTTY

---

## 🚀 Paso a Paso

### PASO 1: Crear Instancia EC2

1. Ve a [AWS EC2 Console](https://console.aws.amazon.com/ec2)
2. Click **"Launch Instance"**

3. **Name:**
   - Ejemplo: `n8n-production`

4. **Application and OS Images (AMI):**
   - **Quick Start:** Ubuntu
   - **Version:** Ubuntu Server 22.04 LTS (64-bit x86)

5. **Instance type:**
   - Elige según tus necesidades (ej: t2.micro, t3.small)

6. **Key pair:**
   - Click **"Create new key pair"**
   - Name: `n8n-key`
   - Key pair type: RSA
   - Private key format: `.pem` (Mac/Linux) o `.ppk` (Windows PuTTY)
   - Click **"Create key pair"** (descarga automáticamente)

7. **Network settings:**
   - Click **"Edit"**
   - **Firewall (security groups):** Create security group
   - **Security group name:** `n8n-sg`

   **Reglas de entrada (Inbound rules):**
   - ✅ SSH (22) - Source: My IP
   - ✅ HTTP (80) - Source: 0.0.0.0/0
   - ✅ HTTPS (443) - Source: 0.0.0.0/0
   - ✅ Custom TCP (5678) - Source: 0.0.0.0/0 (o tu IP para más seguridad)

8. **Configure storage:**
   - Default (8-10 GB) es suficiente

9. Click **"Launch instance"**

⏱️ **Espera 2-3 minutos** mientras se crea.

---

### PASO 2: Conectar por SSH

**Mac/Linux:**

```bash
# Dar permisos a la key
chmod 400 ~/Downloads/n8n-key.pem

# Conectar (reemplaza IP pública de tu instancia)
ssh -i ~/Downloads/n8n-key.pem ubuntu@IP_INSTANCIA
```

**Windows PowerShell:**

```powershell
# Conectar (reemplaza IP y ruta)
ssh -i C:\Users\TU_USUARIO\Downloads\n8n-key.pem ubuntu@IP_INSTANCIA
```

**Windows PuTTY:**
1. Descarga `.ppk` en paso anterior
2. Usa `.ppk` en PuTTY para conectar

---

### PASO 3: Ejecutar Script de Instalación

Una vez conectado por SSH:

```bash
# Descargar script
curl -O https://raw.githubusercontent.com/nneira/lab-n8n-install/main/aws-ec2/ec2-setup.sh

# Dar permisos
chmod +x ec2-setup.sh

# Ejecutar
./ec2-setup.sh
```

El script:
1. ✅ Actualiza Ubuntu
2. ✅ Instala Docker
3. ✅ Configura firewall (UFW)
4. ✅ Crea docker-compose.yml
5. ✅ Detecta tu IP pública automáticamente
   - Soporta IMDSv2 (con token de seguridad)
   - Fallback a IMDSv1 si es necesario
   - Fallback a servicio externo si metadata no disponible
6. ✅ Descarga e inicia n8n

⏱️ **Duración:** 3-5 minutos

**Nota:** El script ejecuta como usuario `ubuntu` (NO usar `sudo su -`). Ya tiene `sudo` donde lo necesita internamente.

---

### PASO 4: Acceder a n8n

Una vez completo, el script mostrará:

```
Accede en tu navegador:
  http://IP_INSTANCIA:5678
```

### Primera Vez - Setup Wizard

La primera vez que accedes a n8n (`http://TU-IP:5678`), verás un **setup wizard** donde:

1. Creas tu usuario
2. Defines tu email
3. Estableces tu contraseña

**No hay credenciales por defecto** - tú las creas en el wizard.

**⚠️ Importante:** Usa email y password seguros (servidor público en internet).

**Datos se guardan en:** `/home/ubuntu/.n8n` (encriptados)

---


## 🔧 Comandos Útiles

**Nota:** Si acabas de instalar y no has cerrado sesión, algunos comandos docker pueden necesitar `sudo` o ejecutar primero:
```bash
newgrp docker
```

### Ver logs n8n:

```bash
docker logs n8n -f
# o si da error de permisos:
sudo docker logs n8n -f
```

### Reiniciar n8n:

```bash
docker restart n8n
```

### Detener n8n:

```bash
docker stop n8n
```

### Actualizar n8n:

```bash
docker compose pull
docker compose up -d
```

### Ver uso de recursos:

```bash
docker stats n8n
```

### Backup workflows:

```bash
# Backup
tar -czf n8n-backup-$(date +%Y%m%d).tar.gz ~/.n8n

# Descargar a tu PC (desde tu terminal local)
scp -i tu-key.pem ubuntu@IP:/home/ubuntu/n8n-backup-*.tar.gz ~/Desktop/
```

---

## 🐛 Troubleshooting

### No puedo conectar por SSH

**Error:** `Connection refused`

**Solución:**
1. Verifica que instancia esté **Running** (verde)
2. Verifica IP correcta
3. Verifica key correcta (`.pem`)
4. Verifica Security Group permite puerto 22 desde tu IP

---

### No puedo acceder a n8n (timeout)

**Causa:** Security Group bloqueando puerto 5678

**Solución:**
1. EC2 Console → Security Groups → `n8n-sg`
2. Inbound rules → Edit
3. Verifica regla TCP 5678 existe
4. Source: `0.0.0.0/0` (o tu IP/32)

También verifica firewall UFW:
```bash
sudo ufw status
sudo ufw allow 5678/tcp
```

---

### n8n no inicia

**Síntomas:** `docker ps` no muestra contenedor

**Solución:**

```bash
# Ver logs
docker logs n8n

# Error común: Puerto ocupado
sudo lsof -i :5678
# Si hay algo, cambiar puerto en docker-compose.yml
```

---

### Error: "Your n8n server is configured to use a secure cookie"

**Síntomas:**
- n8n está corriendo pero muestra error de cookies seguras al acceder via HTTP
- Mensaje sobre usar HTTPS o Safari

**Causa:** Accediendo via HTTP sin configurar `N8N_SECURE_COOKIE=false`

**Solución:**

```bash
# Editar docker-compose.yml
nano docker-compose.yml

# Agregar en environment:
# - N8N_SECURE_COOKIE=false

# Reiniciar
sudo docker compose down && sudo docker compose up -d
```

**Nota:** Si ejecutaste el script actualizado, esto ya está configurado.

---

### Error: "EACCES: permission denied" en logs

**Síntomas:**
- Contenedor crasheando constantemente
- Logs muestran "permission denied" al escribir en `/home/node/.n8n/config`

**Causa:** Ejecutaste el script como root (`sudo su -`) y directorio `.n8n` tiene permisos incorrectos

**Solución:**

```bash
# Arreglar permisos
sudo chown -R ubuntu:ubuntu /home/ubuntu/.n8n

# Reiniciar n8n
sudo docker restart n8n
```

**Prevención:** Ejecuta el script como usuario `ubuntu`, NO como root.

---


## 📚 Recursos

- AWS EC2 Docs: https://docs.aws.amazon.com/ec2/
- n8n Docs: https://docs.n8n.io
- Canal YouTube: https://youtube.com/@NicolasNeiraGarcia

---

**Autor:** Nicolás Neira
**Canal:** https://youtube.com/@NicolasNeiraGarcia
