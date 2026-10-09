# ============================================================================
# Surypus Event Sourcing - Makefile
# ============================================================================

.PHONY: help build test migrate seed clean docker-up docker-down

# Default values
ENV ?= development
DB_URL ?= postgresql://surypus:surypus_secret@localhost:5432/surypus
COMPOSE_FILE ?= docker/docker-compose.yml

# Colors for output
BLUE := \033[36m
GREEN := \033[32m
RED := \033[31m
YELLOW := \033[33m
NC := \033[0m

help: ## Show this help message
	@echo "$(BLUE)Surypus Event Sourcing - Available Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# ============================================================================
# DATABASE OPERATIONS
# ============================================================================

migrate: ## Run database migrations
	@echo "$(BLUE)Running migrations...$(NC)"
	psql $(DB_URL) -f sql/migrations/V100__event_sourcing_init.sql
	@echo "$(GREEN)Migrations complete!$(NC)"

migrate-test: ## Run test migrations
	@echo "$(BLUE)Running test migrations...$(NC)"
	psql $(DB_URL) -f sql/test/V001__test_event_store.sql
	psql $(DB_URL) -f sql/test/V002__test_inventory_aggregate.sql
	@echo "$(GREEN)Test migrations complete!$(NC)"

seed: ## Seed database with test data
	@echo "$(BLUE)Seeding database...$(NC)"
	psql $(DB_URL) -f sql/seeds/basic_seed.sql
	@echo "$(GREEN)Seeding complete!$(NC)"

# ============================================================================
# TESTING
# ============================================================================

test: test-unit test-integration ## Run all tests

test-unit: ## Run unit tests (Haskell)
	@echo "$(BLUE)Running unit tests...$(NC)"
	cabal test surypus-test --test-show-details=always

test-integration: ## Run integration tests (Haskell)
	@echo "$(BLUE)Running integration tests...$(NC)"
	cabal test surypus-test --test-show-details=always

test-sql: ## Run SQL tests
	@echo "$(BLUE)Running SQL tests...$(NC)"
	psql $(DB_URL) -f sql/test/V001__test_event_store.sql
	psql $(DB_URL) -f sql/test/V002__test_inventory_aggregate.sql

# ============================================================================
# BUILDING
# ============================================================================

build: ## Build Haskell application
	@echo "$(BLUE)Building application...$(NC)"
	stack build

build-docker: ## Build Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker build -t surypus:latest .

build-proto: ## Generate code from protobuf
	@echo "$(BLUE)Generating protobuf code...$(NC)"
	protoc --haskell_out=src/api/grpc api/grpc/surypus.proto

# ============================================================================
# DOCKER OPERATIONS
# ============================================================================

docker-up: ## Start all services with Docker Compose
	@echo "$(BLUE)Starting services...$(NC)"
	docker-compose -f $(COMPOSE_FILE) up -d
	@echo "$(GREEN)Services started!$(NC)"
	@echo "API: http://localhost:3000"
	@echo "Grafana: http://localhost:3001"
	@echo "Redpanda Console: http://localhost:8080"

docker-down: ## Stop all services
	@echo "$(RED)Stopping services...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down

docker-logs: ## Show service logs
	docker-compose -f $(COMPOSE_FILE) logs -f

docker-ps: ## Show running containers
	docker-compose -f $(COMPOSE_FILE) ps

docker-clean: ## Remove all containers and volumes
	@echo "$(RED)Cleaning up Docker resources...$(NC)"
	docker-compose -f $(COMPOSE_FILE) down -v --remove-orphans
	docker system prune -f

# ============================================================================
# EVENT STORE OPERATIONS
# ============================================================================

events-replay: ## Replay events to rebuild projections
	@echo "$(BLUE)Replaying events...$(NC)"
	psql $(DB_URL) -c "SELECT rebuild_all_projections();"

events-stats: ## Show event store statistics
	@echo "$(BLUE)Event Store Statistics:$(NC)"
	psql $(DB_URL) -c "SELECT aggregate_type, COUNT(*) as event_count FROM event_store GROUP BY aggregate_type;"

snapshot-create: ## Create snapshots for aggregates
	@echo "$(BLUE)Creating snapshots...$(NC)"
	psql $(DB_URL) -c "SELECT create_snapshots_for_active_aggregates();"

# ============================================================================
# MONITORING
# ============================================================================

metrics: ## Show current metrics
	@echo "$(BLUE)System Metrics:$(NC)"
	psql $(DB_URL) -c "SELECT * FROM metrics_get_system_health();"

logs-api: ## Show API logs
	docker-compose -f $(COMPOSE_FILE) logs -f surypus-api

logs-db: ## Show database logs
	docker-compose -f $(COMPOSE_FILE) logs -f postgres

# ============================================================================
# OPA POLICIES
# ============================================================================

opa-test: ## Test OPA policies
	@echo "$(BLUE)Testing OPA policies...$(NC)"
	docker run --rm -v $(PWD)/opa/policies:/policies openpolicyagent/opa test /policies

opa-check: ## Validate OPA policies
	@echo "$(BLUE)Validating OPA policies...$(NC)"
	docker run --rm -v $(PWD)/opa/policies:/policies openpolicyagent/opa check /policies

# ============================================================================
# DEVELOPMENT UTILITIES
# ============================================================================

repl: ## Start Haskell REPL
	stack repl

lint: ## Run linter
	@echo "$(BLUE)Running linter...$(NC)"
	hlint src/

format: ## Format code
	@echo "$(BLUE)Formatting code...$(NC)"
	find src -name "*.hs" -exec stylish-haskell -i {} \;

psql: ## Connect to database
	psql $(DB_URL)

# ============================================================================
# CLEANUP
# ============================================================================

clean: ## Clean build artifacts
	@echo "$(RED)Cleaning build artifacts...$(NC)"
	stack clean
	rm -rf .stack-work

distclean: clean docker-clean ## Clean everything
	@echo "$(RED)Deep cleaning...$(NC)"
	rm -rf docker/volumes

# ============================================================================
# DEMO/DEVELOPMENT ENVIRONMENT
# ============================================================================

demo: docker-up demo-seed demo-open ## Start demo environment (DB + API)
	@echo "$(GREEN)Demo environment ready!$(NC)"
	@echo "API: http://localhost:3000"
	@echo "Users: admin/admin123, accountant/accountant123, viewer/viewer123"

demo-seed: ## Seed database with demo data
	@echo "$(BLUE)Waiting for database...$(NC)"
	@sleep 5
	@for i in $$(seq 1 10); do \
		psql $(DB_URL) -c "SELECT 1" >/dev/null 2>&1 && break || sleep 2; \
	done
	@echo "$(BLUE)Seeding demo data...$(NC)"
	psql $(DB_URL) -f sql/seeds/basic_seed.sql
	psql $(DB_URL) -f sql/seeds/demo_seed.sql
	@echo "$(GREEN)Demo data seeded!$(NC)"

demo-open: ## Open API documentation
	@command -v xdg-open >/dev/null && xdg-open http://localhost:3000/graphiql || \
	 command -v open >/dev/null && open http://localhost:3000/graphiql || \
	 echo "Open http://localhost:3000/graphiql in your browser"
