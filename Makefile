.PHONY: test infrastructure-test check-tree validate compose-config package-release

PYTHON ?= python3

test:
	PYTHONDONTWRITEBYTECODE=1 $(PYTHON) -m unittest discover -s tests -p 'test_*.py' -v

infrastructure-test:
	bash tests/test_target_selection.sh
	bash tests/test_setup_network.sh
	bash tests/test_routes.sh
	bash tests/test_release_artifact.sh
	bash tests/test_version_script.sh

check-tree:
	$(PYTHON) infrastructure/scripts/quality/check_repository.py

compose-config:
	docker compose --env-file infrastructure/.env.test.example config --quiet
	docker compose --env-file infrastructure/.env.production.example config --quiet

validate:
	bash infrastructure/scripts/quality/validate.sh

package-release:
	bash infrastructure/scripts/release/build-artifact.sh
