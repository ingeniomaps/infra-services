# Infra Services

Toolkit de infraestructura reutilizable. Un compose por
servicio, parametrizado con `${PROJECT_PREFIX}` y
`${NETWORK_NAME}` para usar en cualquier proyecto.

## Uso como submodulo

```bash
git submodule add <repo-url> .infra
```

En el Makefile del proyecto:

```makefile
INFRA_ROOT := .infra
INFRA_ENVS := envs
-include $(INFRA_ROOT)/Makefile
```

Luego:

```bash
make infra-network      # crear red Docker
make infra-postgres     # levantar PostgreSQL
make infra-redis        # levantar Redis
make infra-essential    # postgres + redis
make infra-ha           # + pgbouncer + replica
make infra-full         # todo (servicios + exporters)
make infra-full-scale   # todo con recursos de produccion
make infra-exporters    # todos los exporters
make infra-status       # ver estado
make infra-down         # detener todo
```

## Estructura

```
.infra/
├── Makefile              # Includable por proyectos
├── services/             # Compose files por servicio
│   ├── postgres.yml      # Base
│   ├── postgres-scale.yml # Override (prod resources)
│   ├── redis.yml
│   ├── kafka.yml
│   ├── kafka-scale.yml    # Independiente (3 brokers KRaft)
│   ├── kafka-ui-scale.yml # Independiente (mas recursos)
│   ├── elasticsearch.yml
│   ├── prometheus.yml
│   ├── grafana.yml        # + dashboards/ + provisioning/
│   ├── logstash.yml       # + pipeline configs
│   ├── haproxy.yml        # + haproxy.cfg
│   ├── *-exporter.yml     # Prometheus exporters (5)
│   └── README.md
├── envs/                  # Env templates (.example)
└── DEPLOY_GCP.md          # Guia deploy en GCP
```

## Seguridad

- Todos los servicios bindean puertos a `127.0.0.1` (solo accesibles desde el host)
- Solo HAProxy expone en `0.0.0.0` (punto de entrada externo)
- HAProxy stats en `127.0.0.1` (no accesible externamente)
- `security_opt: no-new-privileges` en todos los contenedores
- Exporters y HAProxy con `read_only: true` + `tmpfs`
- Exporters de DB con `sslmode=prefer`
- Prometheus lifecycle API deshabilitada

## Env files

El proyecto crea sus env files copiando los templates:

```bash
cp .infra/envs/.env.network.example envs/.env.network
cp .infra/envs/.env.postgres.example envs/.env.postgres
# editar con valores reales (passwords obligatorios)
```

El Makefile pasa los env files via `--env-file`:

```
docker compose --env-file .env --env-file envs/.env.network \
  --env-file envs/.env.postgres -f .infra/services/postgres.yml up -d
```

## Naming

Container names usan `${PROJECT_PREFIX}` condicional:

- Con `PROJECT_PREFIX=nz` → `nz-postgres`, `nz-redis`
- Sin prefix → `postgres`, `redis`

Red Docker via `${NETWORK_NAME}` (external).
