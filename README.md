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
make infra-full         # todo
make infra-status       # ver estado
make infra-down         # detener todo
```

## Estructura

```
.infra/
├── Makefile              # Includable por proyectos
├── services/             # Compose files por servicio
│   ├── postgres.yml      # Base (dev resources)
│   ├── postgres-scale.yml # Override (prod resources)
│   ├── redis.yml
│   ├── kafka.yml
│   ├── elasticsearch.yml
│   ├── prometheus.yml
│   ├── grafana.yml        # + dashboards/ + provisioning/
│   ├── logstash.yml       # + pipeline configs
│   ├── haproxy.yml        # + haproxy.cfg
│   ├── *-exporter.yml     # Prometheus exporters
│   └── README.md
├── envs/                  # Env templates (.example)
└── DEPLOY_GCP.md          # Guia deploy en GCP
```

## Env files

El proyecto crea sus env files copiando los templates:

```bash
cp .infra/envs/.env.postgres.example envs/.env.postgres
# editar con valores reales
```

El Makefile pasa los env files via `--env-file`:

```
docker compose --env-file .env --env-file envs/.env.postgres \
  -f .infra/services/postgres.yml up -d
```

## Naming

Container names usan `${PROJECT_PREFIX}` condicional:

- Con `PROJECT_PREFIX=nz` → `nz-postgres`, `nz-redis`
- Sin prefix → `postgres`, `redis`

Red Docker via `${NETWORK_NAME}` (external).
