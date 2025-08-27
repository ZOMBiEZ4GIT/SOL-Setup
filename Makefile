.PHONY: validate deploy logs backup rollback

validate:
	bash scripts/validate.sh

deploy:
	bash scripts/deploy.sh

logs:
	cd docker && docker compose logs -f --tail=200

backup:
	bash scripts/backup.sh

rollback:
	bash scripts/rollback.sh
