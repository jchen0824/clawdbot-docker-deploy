.PHONY: help deploy start stop restart logs status clean backup restore update

help: ## Show this help message
	@echo "Clawdbot Docker Deployment - Available Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

deploy: ## Deploy Clawdbot (first time setup)
	@./deploy.sh

start: ## Start Clawdbot
	@docker compose up -d
	@echo "✓ Clawdbot started"

stop: ## Stop Clawdbot
	@docker compose down
	@echo "✓ Clawdbot stopped"

restart: ## Restart Clawdbot
	@docker compose restart
	@echo "✓ Clawdbot restarted"

logs: ## Show logs (follow mode)
	@docker compose logs -f

status: ## Show container status
	@docker compose ps

shell: ## Access Clawdbot shell
	@docker exec -it clawdbot-gateway sh

config: ## Run Clawdbot configuration wizard
	@docker exec -it clawdbot-gateway clawdbot configure

clean: ## Stop and remove all containers and volumes
	@read -p "This will delete all data. Continue? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker compose down -v
	@echo "✓ All containers and volumes removed"

backup: ## Backup Clawdbot data
	@mkdir -p backups
	@docker run --rm \
		-v clawdbot-docker-deploy_clawdbot-data:/data \
		-v $(PWD)/backups:/backup \
		alpine tar czf /backup/clawdbot-backup-$$(date +%Y%m%d_%H%M%S).tar.gz /data
	@echo "✓ Backup created in ./backups/"

restore: ## Restore from latest backup
	@LATEST=$$(ls -t backups/clawdbot-backup-*.tar.gz 2>/dev/null | head -1); \
	if [ -z "$$LATEST" ]; then \
		echo "✗ No backups found"; \
		exit 1; \
	fi; \
	read -p "Restore from $$LATEST? (y/N) " confirm && [ "$$confirm" = "y" ] || exit 1; \
	docker run --rm \
		-v clawdbot-docker-deploy_clawdbot-data:/data \
		-v $(PWD)/backups:/backup \
		alpine sh -c "rm -rf /data/* && tar xzf /backup/$$(basename $$LATEST) -C /"; \
	echo "✓ Restored from $$LATEST"

update: ## Update Clawdbot to latest version
	@echo "Creating backup before update..."
	@$(MAKE) backup
	@echo "Pulling latest images..."
	@docker compose pull
	@echo "Restarting with new images..."
	@docker compose up -d
	@echo "✓ Update complete"

health: ## Check Clawdbot health
	@curl -sf http://localhost:18789/health && echo "✓ Healthy" || echo "✗ Unhealthy"

env: ## Create .env from template
	@if [ -f .env ]; then \
		echo "✗ .env already exists"; \
		exit 1; \
	fi
	@cp .env.example .env
	@echo "✓ Created .env - please edit and add your secrets"
