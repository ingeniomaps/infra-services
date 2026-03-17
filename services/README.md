# Infraestructura reutilizable para producción

Un docker-compose por herramienta. Cada una tiene **dos variantes**:

- **Producción bajo** (`tool.yml`): mínimo viable para producción, carga moderada, una instancia.
- **Producción fuerte** (`tool-scale.yml`): alta carga, millones de operaciones, más recursos y/o HA (réplicas, cluster).

**Secrets:** En producción no hay contraseñas por defecto. Definir variables en `.env` (copiar de `.env.example`).

## Red compartida

```bash
docker network create infra
```

Levantar desde la **raíz del repo**:

```bash
docker compose -f environments/infrastructure/postgres.yml --env-file .env up -d
docker compose -f environments/infrastructure/redis.yml --env-file .env up -d
```

Las apps que usen la red `infra` resuelven por nombre: `postgres`, `redis`, `pgbouncer`, `kafka`, etc.

## Archivos

| Archivo | Servicio | Bajo / Fuerte | Puerto(s) |
|---------|----------|---------------|-----------|
| `postgres.yml` / `postgres-scale.yml` | PostgreSQL 15 | 1 instancia / 1 instancia 8G | 5432 |
| `postgres-replica.yml` / `postgres-replica-scale.yml` | Réplica PostgreSQL | 1 réplica / 1 réplica 8G | - |
| `pgbouncer.yml` / `pgbouncer-scale.yml` | PgBouncer | pool moderado / 10k conexiones | 6432 |
| `redis.yml` / `redis-scale.yml` | Redis | 1G / 4G, password obligatorio | 6379 |
| `redis-cluster.yml` / `redis-cluster-scale.yml` | Redis Cluster | 3 nodos / 6 nodos | 6379 |
| `haproxy.yml` / `haproxy-scale.yml` | HAProxy | 512M / 2G | 80, 443, 8404 |
| `zookeeper.yml` / `zookeeper-scale.yml` | Zookeeper | 1 nodo / ensemble 3 nodos | 2181 |
| `kafka.yml` / `kafka-scale.yml` | Kafka | 1 broker / 3 brokers, replication 2 | 9092 |
| `kafka-ui.yml` / `kafka-ui-scale.yml` | Kafka UI | 512M / 1G | 8081 |
| `elasticsearch.yml` / `elasticsearch-scale.yml` | Elasticsearch | single-node 2G / 8G | 9200, 9300 |
| `kibana.yml` / `kibana-scale.yml` | Kibana | 2G / 4G | 5601 |
| `logstash.yml` / `logstash-scale.yml` | Logstash | 2G / 4G, más workers | - |
| `prometheus.yml` / `prometheus-scale.yml` | Prometheus | 15d retención / 90d, 8G | 9090 |
| `grafana.yml` / `grafana-scale.yml` | Grafana | 512M / 2G, admin password obligatorio | 3000 |

## Variables obligatorias (.env)

- **Postgres:** `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`
- **Postgres Réplica:** `POSTGRES_PRIMARY_HOST`, `POSTGRES_REPLICATION_USER`, `POSTGRES_REPLICATION_PASSWORD`
- **PgBouncer (Bitnami):** `POSTGRESQL_HOST`, `POSTGRESQL_USERNAME`, `POSTGRESQL_PASSWORD`, `POSTGRESQL_DATABASE`
- **Redis:** `REDIS_PASSWORD`
- **Redis Cluster:** `REDIS_CLUSTER_PASSWORD`
- **Grafana:** `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`

Ver `.env.example` para la lista completa y opcionales.

## Uso

```bash
# Producción bajo (mínimo)
docker compose -f environments/infrastructure/postgres.yml --env-file .env up -d

# Producción fuerte (escala)
docker compose -f environments/infrastructure/postgres-scale.yml --env-file .env up -d
```

Dependencias: Zookeeper antes que Kafka; Elasticsearch antes que Kibana; Postgres antes que PgBouncer.
