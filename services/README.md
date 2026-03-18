# Infra Services

Compose files reutilizables por servicio. Cada uno tiene dos variantes:

- **Base** (`service.yml`): recursos de desarrollo/produccion minima
- **Scale** (`service-scale.yml`): override con recursos de produccion

Excepciones: `kafka-scale.yml` y `kafka-ui-scale.yml` son compose
independientes (3 brokers KRaft y mas recursos), no overrides.

## Uso

Este repositorio se usa como submodulo. El proyecto define
`INFRA_ROOT`, `INFRA_ENVS` y hace `include` del Makefile:

```makefile
INFRA_ROOT := .infra
INFRA_ENVS := envs
-include $(INFRA_ROOT)/Makefile
```

Luego: `make infra-postgres`, `make infra-redis`, etc.

## Red

Los servicios usan `${NETWORK_NAME}` (external). El proyecto
la crea con `make infra-network` antes de levantar servicios.

## Nombres

Container names usan `${PROJECT_PREFIX}` condicional:

- Con `PROJECT_PREFIX=nz` → `nz-postgres`
- Sin prefix → `postgres`

## Puertos

Todos los servicios bindean a `127.0.0.1` (solo accesibles desde el host).
Solo HAProxy expone en `0.0.0.0:80/443` como punto de entrada externo.

## Seguridad

Todos los compose incluyen:

- `security_opt: no-new-privileges:true`
- Healthchecks
- Resource limits (`deploy.resources`)
- `restart: unless-stopped`
- Red externa (no default bridge)

Adicionalmente, exporters y HAProxy tienen `read_only: true` + `tmpfs`.

## Servicios

| Archivo | Servicio | Base | Scale |
|---------|----------|------|-------|
| `postgres.yml` | PostgreSQL | 2G, 2 CPU | 8G, 4 CPU |
| `postgres-replica.yml` | PostgreSQL replica | 2G, 2 CPU | 8G, 4 CPU |
| `pgbouncer.yml` | PgBouncer | 256M | 1G |
| `redis.yml` | Redis | 1G, 1 CPU | 4G, 2 CPU |
| `redis-cluster.yml` | Redis Cluster (3 nodos) | 2G | 8G |
| `kafka.yml` | Kafka (KRaft) | 4G, 2 CPU | 3 brokers (independiente) |
| `kafka-ui.yml` | Kafka UI | 512M | 1G (independiente) |
| `elasticsearch.yml` | Elasticsearch | 2G, 2 CPU | 8G, 4 CPU |
| `kibana.yml` | Kibana | 2G | 4G |
| `logstash.yml` | Logstash | 2G | 4G |
| `prometheus.yml` | Prometheus | 1G | 8G |
| `grafana.yml` | Grafana | 512M | 2G |
| `haproxy.yml` | HAProxy | 512M | 2G |

## Exporters

| Archivo | Target | Puerto |
|---------|--------|--------|
| `postgres-exporter.yml` | PostgreSQL | 9187 |
| `redis-exporter.yml` | Redis | 9121 |
| `pgbouncer-exporter.yml` | PgBouncer | 9127 |
| `kafka-exporter.yml` | Kafka | 9308 |
| `elasticsearch-exporter.yml` | Elasticsearch | 9114 |

Todos usan `read_only: true`, `tmpfs`, y `no-new-privileges`.

## Variables

Cada servicio lee variables desde su propio env file
(`.env.postgres`, `.env.redis`, etc.) pasado via
`--env-file` por el Makefile.

Variables compartidas (`NETWORK_NAME`, `NETWORK_SUBNET`,
`PROJECT_PREFIX`) vienen de `.env.network`.
