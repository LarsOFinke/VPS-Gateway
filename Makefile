.PHONY: test check-tree validate

test:
	PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -p 'test_*.py' -v
	bash tests/test_version_script.sh

check-tree:
	python3 infrastructure/scripts/quality/check_repository.py

validate:
	bash infrastructure/scripts/quality/validate.sh
