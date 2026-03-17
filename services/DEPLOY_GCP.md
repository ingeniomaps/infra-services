# Deploy en servidor (GCP)

Guia para instalar infra services en una VM de GCP.

## Recomendacion

Tener la carpeta (o el repo) en un servidor y levantar
solo los compose que necesites. Cada YML es independiente;
comparten la red via `${NETWORK_NAME}`.

## 1. Crear la VM

En Google Cloud Console → Compute Engine → Create instance:

- **Machine type**:
  - Dev/staging: `e2-medium` (2 vCPU, 4 GB)
  - Produccion: `e2-standard-4` (4 vCPU, 16 GB)
- **Boot disk**: Debian 12 o Ubuntu 22.04 LTS, >= 50 GB
- **Firewall**: Allow HTTP/HTTPS si expones servicios

## 2. Instalar Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") \
  stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli \
  containerd.io docker-compose-plugin
```

## 3. Preparar el proyecto

```bash
git clone TU_REPO_URL && cd proyecto
cp .env.example .env
nano .env   # configurar variables y passwords
```

## 4. Crear red y desplegar

```bash
# Crear red (nombre de NETWORK_NAME en .env)
docker network create nunzio-net

# Desplegar solo lo que necesites
docker compose --env-file .env \
  --env-file envs/.env.postgres \
  -f .infra/services/postgres.yml up -d

docker compose --env-file .env \
  --env-file envs/.env.redis \
  -f .infra/services/redis.yml up -d
```

O si usas el Makefile:

```bash
make infra-network
make infra-postgres
make infra-redis
```

## 5. Replicas

Replicas en el YML = varios contenedores en la misma VM.
Para replicas en maquinas distintas: usar orquestador
(Kubernetes, Docker Swarm) o servicios gestionados
(Cloud SQL, Memorystore).

## 6. CI/CD

El CI automatiza el mismo flujo manual:

1. Conectar por SSH al servidor
2. `git pull` o `rsync` para actualizar archivos
3. `docker compose ... pull && docker compose ... up -d`

El `.env` con secretos no debe estar en el repo.
Inyectar via variable del pipeline o Infisical.

## 7. Firewall

VPC network → Firewall → Create rule. Restringir
Source IP ranges y abrir solo los puertos necesarios
(5432, 6379, 9090, 3000, etc.).
