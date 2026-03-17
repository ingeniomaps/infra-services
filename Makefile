# ============================================================================
# Infra Services - Makefile includable
# ============================================================================
# Toolkit de infraestructura reutilizable. Cada servicio tiene un compose
# individual con recursos base y un override -scale.yml para produccion.
#
# Uso desde un proyecto:
#   INFRA_ROOT := .infra
#   INFRA_ENVS := infra/envs     # donde el proyecto guarda sus env values
#   include $(INFRA_ROOT)/Makefile
# ============================================================================

# Rutas configurables (el proyecto las define antes del include)
INFRA_ROOT     ?= .infra
INFRA_ENVS     ?= infra/envs
INFRA_SERVICES  = $(INFRA_ROOT)/services
INFRA_BASE      = docker compose --env-file .env --env-file $(INFRA_ENVS)/.env.network

# Compose con .env especifico por servicio
define infra
$(INFRA_BASE) --env-file $(INFRA_ENVS)/.env.$(1)
endef

# ============================================================================
# Red
# ============================================================================

.PHONY: infra-network

infra-network: ## (Infra) Crear red Docker (requerida por los servicios)
	@NET=$$(grep '^NETWORK_NAME=' $(INFRA_ENVS)/.env.network 2>/dev/null | cut -d= -f2); \
	if [ -z "$$NET" ]; then echo "Error: NETWORK_NAME no definido en $(INFRA_ENVS)/.env.network"; exit 1; fi; \
	docker network create $$NET 2>/dev/null || true

# ============================================================================
# Servicios individuales
# ============================================================================

.PHONY: infra-postgres infra-postgres-replica infra-pgbouncer
.PHONY: infra-redis infra-redis-cluster
.PHONY: infra-kafka infra-kafka-ui
.PHONY: infra-elasticsearch infra-monitoring infra-logstash infra-haproxy
.PHONY: infra-essential infra-ha infra-full infra-full-scale
.PHONY: infra-down infra-status

infra-postgres: infra-network ## (Infra) Iniciar PostgreSQL
	@$(call infra,postgres) -f $(INFRA_SERVICES)/postgres.yml up -d

infra-postgres-replica: infra-network ## (Infra) Iniciar PostgreSQL replica de lectura
	@$(call infra,postgres) -f $(INFRA_SERVICES)/postgres-replica.yml up -d

infra-pgbouncer: infra-network ## (Infra) Iniciar PgBouncer (connection pooling)
	@$(call infra,postgres) -f $(INFRA_SERVICES)/pgbouncer.yml up -d

infra-redis: infra-network ## (Infra) Iniciar Redis
	@$(call infra,redis) -f $(INFRA_SERVICES)/redis.yml up -d

infra-redis-cluster: infra-network ## (Infra) Iniciar Redis Cluster
	@$(call infra,redis) -f $(INFRA_SERVICES)/redis-cluster.yml up -d

infra-kafka: infra-network ## (Infra) Iniciar Kafka (KRaft, sin Zookeeper)
	@$(call infra,kafka) -f $(INFRA_SERVICES)/kafka.yml up -d

infra-kafka-ui: infra-network ## (Infra) Iniciar Kafka UI
	@$(call infra,kafka) -f $(INFRA_SERVICES)/kafka-ui.yml up -d

infra-elasticsearch: infra-network ## (Infra) Iniciar Elasticsearch + Kibana
	@$(call infra,elasticsearch) -f $(INFRA_SERVICES)/elasticsearch.yml -f $(INFRA_SERVICES)/kibana.yml up -d

infra-monitoring: infra-network ## (Infra) Iniciar Prometheus + Grafana
	@$(call infra,monitoring) -f $(INFRA_SERVICES)/prometheus.yml -f $(INFRA_SERVICES)/grafana.yml up -d

infra-logstash: infra-network ## (Infra) Iniciar Logstash
	@$(call infra,logstash) -f $(INFRA_SERVICES)/logstash.yml up -d

infra-haproxy: infra-network ## (Infra) Iniciar HAProxy
	@$(call infra,haproxy) -f $(INFRA_SERVICES)/haproxy.yml up -d

# ============================================================================
# Composites
# ============================================================================

infra-essential: infra-network ## (Infra) Iniciar servicios esenciales (postgres + redis)
	@$(INFRA_BASE) --env-file $(INFRA_ENVS)/.env.postgres --env-file $(INFRA_ENVS)/.env.redis \
		-f $(INFRA_SERVICES)/postgres.yml -f $(INFRA_SERVICES)/redis.yml up -d

infra-ha: infra-essential infra-pgbouncer infra-postgres-replica ## (Infra) Iniciar High Availability

infra-full: infra-network ## (Infra) Iniciar TODA la infraestructura
	@echo "Iniciando toda la infraestructura..."
	@$(INFRA_BASE) \
		--env-file $(INFRA_ENVS)/.env.postgres \
		--env-file $(INFRA_ENVS)/.env.redis \
		--env-file $(INFRA_ENVS)/.env.kafka \
		--env-file $(INFRA_ENVS)/.env.elasticsearch \
		--env-file $(INFRA_ENVS)/.env.monitoring \
		--env-file $(INFRA_ENVS)/.env.logstash \
		-f $(INFRA_SERVICES)/postgres.yml \
		-f $(INFRA_SERVICES)/postgres-replica.yml \
		-f $(INFRA_SERVICES)/pgbouncer.yml \
		-f $(INFRA_SERVICES)/redis.yml \
		-f $(INFRA_SERVICES)/redis-cluster.yml \
		-f $(INFRA_SERVICES)/kafka.yml \
		-f $(INFRA_SERVICES)/kafka-ui.yml \
		-f $(INFRA_SERVICES)/elasticsearch.yml \
		-f $(INFRA_SERVICES)/kibana.yml \
		-f $(INFRA_SERVICES)/prometheus.yml \
		-f $(INFRA_SERVICES)/grafana.yml \
		-f $(INFRA_SERVICES)/logstash.yml \
		up -d
	@echo "Infraestructura completa iniciada"

infra-full-scale: infra-network ## (Infra) Iniciar infra con recursos de produccion
	@echo "Iniciando infraestructura con recursos de produccion..."
	@$(INFRA_BASE) \
		--env-file $(INFRA_ENVS)/.env.postgres \
		--env-file $(INFRA_ENVS)/.env.redis \
		--env-file $(INFRA_ENVS)/.env.kafka \
		--env-file $(INFRA_ENVS)/.env.elasticsearch \
		--env-file $(INFRA_ENVS)/.env.monitoring \
		-f $(INFRA_SERVICES)/postgres.yml -f $(INFRA_SERVICES)/postgres-scale.yml \
		-f $(INFRA_SERVICES)/postgres-replica.yml -f $(INFRA_SERVICES)/postgres-replica-scale.yml \
		-f $(INFRA_SERVICES)/pgbouncer.yml -f $(INFRA_SERVICES)/pgbouncer-scale.yml \
		-f $(INFRA_SERVICES)/redis.yml -f $(INFRA_SERVICES)/redis-scale.yml \
		-f $(INFRA_SERVICES)/redis-cluster.yml -f $(INFRA_SERVICES)/redis-cluster-scale.yml \
		-f $(INFRA_SERVICES)/kafka.yml -f $(INFRA_SERVICES)/kafka-scale.yml \
		-f $(INFRA_SERVICES)/elasticsearch.yml -f $(INFRA_SERVICES)/elasticsearch-scale.yml \
		-f $(INFRA_SERVICES)/prometheus.yml -f $(INFRA_SERVICES)/prometheus-scale.yml \
		-f $(INFRA_SERVICES)/grafana.yml -f $(INFRA_SERVICES)/grafana-scale.yml \
		up -d
	@echo "Infraestructura con escala de produccion iniciada"

# ============================================================================
# Utilidades
# ============================================================================

infra-down: ## (Infra) Detener TODA la infraestructura
	@echo "Deteniendo infraestructura..."
	@for f in $(INFRA_SERVICES)/*.yml; do \
		$(INFRA_BASE) -f "$$f" down 2>/dev/null || true; \
	done
	@echo "Infraestructura detenida"

infra-status: ## (Infra) Estado de servicios de infraestructura
	@echo "=== Servicios de Infraestructura ==="
	@docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" \
		--filter "name=postgres" \
		--filter "name=pgbouncer" \
		--filter "name=redis" \
		--filter "name=kafka" \
		--filter "name=elasticsearch" \
		--filter "name=kibana" \
		--filter "name=prometheus" \
		--filter "name=grafana" \
		--filter "name=logstash" \
		--filter "name=haproxy" \
		2>/dev/null || echo "No hay servicios de infraestructura corriendo"
