# n8n en Google Cloud Platform

Instala n8n en una VM de Google Cloud con Docker.

---

## 📋 Prerequisitos

1. **Cuenta Google Cloud:**
   - Gmail o Google Workspace
   - Tarjeta de crédito/débito

2. **VM con Ubuntu 22.04 LTS:**
   - ⚠️ **IMPORTANTE:** Este script está diseñado para Ubuntu/Debian
   - Si usas CentOS, Rocky Linux o AlmaLinux, deberás adaptar los comandos
   - Recomendado: Ubuntu 22.04 LTS (más soporte, documentación)

3. **gcloud CLI (Opcional):**
   - Instalar desde: https://cloud.google.com/sdk/docs/install
   - Facilita SSH y comandos

---

## 🚀 Paso a Paso

### PASO 1: Crear Proyecto

1. Ve a [Google Cloud Console](https://console.cloud.google.com)
2. En Console, arriba: Selector de proyecto
3. Click **"New Project"**
4. Nombre: `n8n-production` (o el que prefieras)
5. Click **"Create"**

⏱️ Espera 10-15 segundos.

---

### PASO 2: Crear VM (Compute Engine)

1. Menú lateral → **Compute Engine > VM instances**
2. Click **"Create Instance"**

3. Configurar VM:

   **Name:** `n8n-vm`

   **Region:** Elige cercana (ej: us-central1, us-east1)

   **Zone:** Dejar por defecto (ej: us-central1-a)

   **Machine configuration:**
   - **Series:** E2
   - **Machine type:** Elige según tus necesidades
     - e2-micro (0.25 vCPU, 1GB RAM): Testing
     - e2-small (0.5 vCPU, 2GB RAM): Producción

   **Boot disk:**
   - Click **"Change"**
   - **Operating system:** Ubuntu
   - **Version:** Ubuntu 22.04 LTS
   - **Boot disk type:** Standard persistent disk
   - **Size:** 10 GB (suficiente)
   - Click **"Select"**

   **Firewall:**
   - ☑️ Allow HTTP traffic
   - ☑️ Allow HTTPS traffic

4. Click **"Create"**

⏱️ **Espera 1-2 minutos** mientras se crea.

---

### PASO 3: Configurar Firewall (CRÍTICO)

**Por defecto GCP bloquea puerto 5678.**

1. Menú → **VPC network > Firewall**
2. Click **"Create Firewall Rule"**
3. Configurar:
   - **Name:** `allow-n8n`
   - **Targets:** All instances in the network
   - **Source IPv4 ranges:** `0.0.0.0/0` (o tu IP/32 para más seguridad)
   - **Protocols and ports:** TCP `5678`
4. Click **"Create"**

---

### PASO 4: Conectar por SSH

**Opción A: Desde navegador (más fácil)**

1. VM instances → Click en tu VM
2. Columna "Connect" → Click **"SSH"**
3. Se abre terminal en navegador

**Opción B: Desde tu terminal local**

```bash
# Instala gcloud CLI primero
# https://cloud.google.com/sdk/docs/install

# Iniciar sesión
gcloud auth login

# Conectar
gcloud compute ssh n8n-vm --zone=us-central1-a
```

---

### PASO 5: Ejecutar Script de Instalación

En SSH:

```bash
# Descargar script
curl -O https://raw.githubusercontent.com/nneira/lab-n8n-install/main/gcp/gcp-setup.sh

# Permisos
chmod +x gcp-setup.sh

# Ejecutar
./gcp-setup.sh
```

El script:
1. ✅ Actualiza Ubuntu
2. ✅ Instala Docker
3. ✅ Configura firewall local
4. ✅ Detecta IP externa GCP automáticamente
   - Usa GCP metadata service
   - Fallback a servicio externo si metadata no disponible
5. ✅ Crea docker-compose.yml
6. ✅ Inicia n8n

⏱️ **Duración:** 3-5 minutos

**Nota:** El script ejecuta como usuario normal (NO usar `sudo su -`). Ya tiene `sudo` donde lo necesita internamente.

---

### PASO 6: Acceder a n8n

Script mostrará:

```
Accede en tu navegador:
  http://IP_INSTANCIA:5678
```

⚠️ **Si no puedes acceder:** Verifica firewall (Paso 3)

### Primera Vez - Setup Wizard

La primera vez que accedes a n8n (`http://TU-IP:5678`), verás un **setup wizard** donde:

1. Creas tu usuario
2. Defines tu email
3. Estableces tu contraseña

**No hay credenciales por defecto** - tú las creas en el wizard.

**⚠️ Importante:** Usa email y password seguros (servidor público en internet).

**Datos se guardan en:** `~/.n8n` (encriptados)

---

## 🔒 Seguridad

### IP Allowlist (Recomendado)

En regla firewall:
- Source IPv4 ranges: `TU-IP/32`

Solo tú podrás acceder.

---

## 🔧 Comandos Útiles

**Nota:** Si acabas de instalar y no has cerrado sesión, algunos comandos docker pueden necesitar `sudo` o ejecutar primero:
```bash
newgrp docker
```

### SSH desde local:

```bash
gcloud compute ssh n8n-vm --zone=us-central1-a
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

### Actualizar n8n:

```bash
docker compose pull
docker compose up -d
```

### Backup workflows:

```bash
# Backup
tar -czf n8n-backup-$(date +%Y%m%d).tar.gz ~/.n8n

# Descargar a tu PC
gcloud compute scp n8n-vm:~/n8n-backup-*.tar.gz ~/Desktop/ --zone=us-central1-a
```

---

## 💡 Gestión de VM

### Detener VM cuando no uses:

```bash
# Desde local
gcloud compute instances stop n8n-vm --zone=us-central1-a

# Iniciar cuando necesites
gcloud compute instances start n8n-vm --zone=us-central1-a
```

### Snapshot + Delete (para experimentos):

1. Create snapshot (backup completo)
2. Delete VM
3. Restore cuando necesites

---

## 🐛 Troubleshooting

### No puedo acceder a n8n (timeout)

**Verificar:**

1. **Firewall GCP configurado:**
   ```bash
   gcloud compute firewall-rules list | grep n8n
   ```

2. **n8n corriendo:**
   ```bash
   docker ps | grep n8n
   ```

3. **Firewall local (UFW):**
   ```bash
   sudo ufw status | grep 5678
   ```

---

### VM muy lenta

**Causa:** Insuficiente RAM o CPU.

**Solución:** Upgrade a tipo de máquina más grande

1. Stop VM
2. Edit → Machine type → Selecciona mayor
3. Save → Start

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
docker compose down && docker compose up -d
```

**Nota:** Si ejecutaste el script actualizado, esto ya está configurado.

---

### Error: "EACCES: permission denied" en logs

**Síntomas:**
- Contenedor crasheando constantemente
- Logs muestran "permission denied" al escribir en `/home/node/.n8n/config`
- n8n no puede crear archivos de configuración

**Causa:** El directorio `.n8n` no tiene permisos correctos. El contenedor Docker corre internamente como UID 1000:1000 y necesita poder escribir en ese directorio.

**Solución:**

```bash
# Detener n8n
docker compose down

# Arreglar permisos (UID 1000:1000 para Docker)
sudo chown -R 1000:1000 ~/.n8n

# Verificar permisos
ls -la ~/.n8n

# Reiniciar n8n
docker compose up -d

# Ver logs (debe iniciar correctamente)
docker logs n8n -f
```

**Prevención:** El script actualizado ya configura estos permisos automáticamente en el PASO 4.

---


## 📚 Recursos

- GCP Docs: https://cloud.google.com/docs
- n8n Docs: https://docs.n8n.io
- Canal YouTube: https://youtube.com/@NicolasNeiraGarcia

---

**Autor:** Nicolás Neira
**Canal:** https://youtube.com/@NicolasNeiraGarcia
