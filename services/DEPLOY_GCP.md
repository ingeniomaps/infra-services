# Desplegar infraestructura en un servidor (GCP)

Guía para instalar y usar las imágenes Docker y los YML de esta carpeta en una VM de Google Cloud Platform.

---

## Recomendación de uso

**Sí:** la idea es tener la carpeta (o el repo) en un servidor y levantar **solo los YML que necesites** en esa máquina.

- No hace falta desplegar todo: si solo quieres Postgres y Redis, ejecutas solo `postgres.yml` y `redis.yml`.
- Cada YML es independiente; comparten la red `infra` para hablarse por nombre de contenedor.
- Puedes tener un servidor “limpio” (solo Docker + esta carpeta), crear la red, configurar `.env` y hacer `docker compose -f ... up -d` de los que vayas a usar.

---

## 1. Crear la VM en GCP

1. En [Google Cloud Console](https://console.cloud.google.com/) → **Compute Engine** → **VM instances** → **Create instance**.

2. Configuración recomendada:
   - **Name:** `infra-server` (o el que prefieras).
   - **Region / Zone:** la más cercana a tus usuarios.
   - **Machine type:** según carga:
     - **Producción bajo:** `e2-medium` (2 vCPU, 4 GB) o `e2-standard-2` (2 vCPU, 8 GB).
     - **Producción fuerte:** `e2-standard-4` (4 vCPU, 16 GB) o superior.
   - **Boot disk:** Debian 12 o Ubuntu 22.04 LTS, tamaño ≥ 50 GB (para datos de Postgres/Redis/etc.).
   - **Firewall:** marcar **Allow HTTP traffic** y **Allow HTTPS traffic** si expones HAProxy/Grafana; o crear reglas después.

3. Crear la instancia y anotar la **IP externa**.

---

## 2. Conectar por SSH

```bash
gcloud compute ssh infra-server --zone=TU_ZONA
# o
ssh TU_USUARIO@IP_EXTERNA
```

---

## 3. Instalar Docker y Docker Compose

En la VM (Debian/Ubuntu):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
docker compose version
```

---

## 4. Llevar el proyecto al servidor

**Opción A – Clonar el repo**

```bash
cd ~
git clone https://github.com/TU_ORG/keycloak.git
cd keycloak
```

**Opción B – Copiar solo la carpeta de infraestructura**

En tu máquina:

```bash
tar czvf infra.tar.gz infra/services
scp infra.tar.gz TU_USUARIO@IP_EXTERNA:~/
```

En el servidor (para que los paths de los YML sigan siendo correctos):

```bash
mkdir -p ~/keycloak && cd ~/keycloak
tar xzvf ~/infra.tar.gz
# Queda ~/keycloak/infra/services/
```

---

## 5. Configurar y desplegar solo lo que quieras

```bash
cd ~/keycloak   # o la ruta donde esté el repo/carpeta
docker network create infra
cp infra/services/.env.example .env
nano .env       # rellenar contraseñas
```

Desplegar solo los servicios que necesites, por ejemplo:

```bash
docker compose -f infra/services/postgres.yml --env-file .env up -d
docker compose -f infra/services/redis.yml --env-file .env up -d
# Añadir más si hace falta: grafana, prometheus, etc.
```

---

## 6. Cómo funcionan las réplicas (varios contenedores de la misma herramienta)

Cuando un YML usa **réplicas** (p. ej. `redis-cluster.yml` con 3 nodos o `kafka-scale.yml` con 3 brokers), Docker Compose crea **varios contenedores en la misma VM**.

| Situación | Qué pasa |
|-----------|----------|
| **Un solo servidor** | Todos los nodos/replicas corren en esa máquina. Sirve para desarrollo, staging o carga moderada. Si la VM cae, se cae todo. |
| **Varios servidores (HA real)** | Cada nodo en una VM distinta: tendrías que desplegar “a mano” (por ejemplo, en servidor A solo `redis-cluster` con un rol, en B otro, etc.) o usar un orquestador (Kubernetes, Docker Swarm) o servicios gestionados (Cloud SQL, Memorystore, etc.). Los YML de esta carpeta no automatizan el reparto entre VMs. |

Resumen: **réplicas en el YML = varios contenedores en la misma máquina**. Para réplicas en máquinas distintas hace falta otro esquema (varias VMs + orquestador o servicios gestionados).

---

## 7. Cómo integrar con CI (despliegue automático)

El flujo que el CI suele automatizar es el mismo que harías a mano:

1. **Llevar el código/YML al servidor** (o que el servidor ya tenga el repo y haga `git pull`).
2. **Ejecutar Docker Compose** en ese servidor.

Ejemplo típico en un pipeline (GitHub Actions, GitLab CI, etc.):

- **Paso 1:** Conectar por SSH al servidor (clave o servicio gestionado).
- **Paso 2:** En el servidor, ir al directorio del proyecto y actualizar:
  - `cd /ruta/al/proyecto && git pull` (si usas repo), o
  - `rsync` / `scp` desde el runner para copiar solo `infra/services` y `.env`.
- **Paso 3:** En el servidor, levantar (o actualizar) solo los stacks que toquen:
  - `docker compose -f infra/services/postgres.yml --env-file .env pull`
  - `docker compose -f infra/services/postgres.yml --env-file .env up -d`
  - Y lo mismo para `redis.yml`, `grafana.yml`, etc., según lo que ese servidor deba ejecutar.

El `.env` con secretos no debe estar en el repo; el CI puede inyectarlo (variable de entorno del pipeline que escribe un `.env` en el servidor) o el servidor puede tener ya un `.env` fijo y el CI solo ejecuta los `docker compose`.

Resumen: **CI = automatizar “copiar/actualizar archivos en el servidor + ejecutar los mismos comandos docker compose”** que usarías en un despliegue manual.

---

## 8. Firewall GCP

Si necesitas acceder desde internet a los servicios:

- **VPC network** → **Firewall** → **Create firewall rule**.
- Indicar los puertos (TCP) que expongas: 80, 443, 5432, 6379, 3000, 9090, etc., y restringir **Source IP ranges** si es posible.

---

## 9. Resumen rápido

```bash
# En la VM
sudo apt-get update && sudo apt-get install -y ca-certificates curl gnupg
# ... (instalar Docker como en sección 3) ...

git clone TU_REPO_URL keycloak && cd keycloak
# o: descomprimir infra.tar.gz en ~/keycloak como en sección 4

docker network create infra
cp infra/services/.env.example .env
nano .env

# Desplegar solo lo que quieras
docker compose -f infra/services/postgres.yml --env-file .env up -d
docker compose -f infra/services/redis.yml --env-file .env up -d
```

- **Replicas en el YML** = varios contenedores en la misma máquina.
- **CI** = automatizar ese mismo flujo (actualizar código/YML en el servidor y ejecutar `docker compose` allí).
