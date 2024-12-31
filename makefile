# Variables
PYTHON := python3
VENV := venv
TEST_DIR := src/tests
BACKEND_DIR := backend
FRONTEND_DIR := frontend
URL := http://127.0.0.1:5000
DB_CONTAINER := db

# Colors
GREEN := \033[0;32m
RED := \033[0;31m
YELLOW := \033[1;33m
NC := \033[0m

# Ensure commands run in correct directory
.ONESHELL:

.PHONY: help setup install run-web run-api test-flask test-react coverage clean

help:
	@echo "${YELLOW}Available commands:${NC}"
	@echo "  ${GREEN}setup${NC}     - Create Python virtual environment"
	@echo "  ${GREEN}install${NC}   - Install all dependencies"
	@echo "  ${GREEN}run-web${NC}   - Start React frontend"
	@echo "  ${GREEN}run-api${NC}   - Start Flask backend with database"
	@echo "  ${GREEN}test${NC}      - Run all tests"
	@echo "  ${GREEN}test-react${NC} - Run React tests"
	@echo "  ${GREEN}coverage${NC}  - Generate test coverage report"
	@echo "  ${GREEN}clean${NC}     - Remove temporary files"

setup:
	cd $(BACKEND_DIR)
	$(PYTHON) -m venv $(VENV)
	. $(VENV)/bin/activate

install: setup
	cd $(BACKEND_DIR)
	. $(VENV)/bin/activate
	pip install -r requirements.txt
	cd ../$(FRONTEND_DIR)
	npm install

run-web:
	cd $(FRONTEND_DIR)
	npm start

run-api:
	cd $(BACKEND_DIR)
	. $(VENV)/bin/activate
	docker stop $(DB_CONTAINER) || true
	docker rm $(DB_CONTAINER) || true
	docker run -d --name $(DB_CONTAINER) \
		-p 3306:3306 \
		-e MARIADB_ROOT_PASSWORD=root \
		-e MYSQL_PASSWORD=1234 \
		-e MYSQL_USER=admin \
		-e MYSQL_DATABASE=task_app \
		mariadb:10.6
	sleep 5
	python wsgi.py

test-react:
	cd $(FRONTEND_DIR)
	npm run test

test-flask: 
	cd $(BACKEND_DIR)
	. $(VENV)/bin/activate
	for test in unit functional integration security; do \
		echo "Running $$test tests..."; \
		$(PYTHON) -m unittest discover -s $(TEST_DIR) -p "$$test.py"; \
		sleep 2; \
	done
	echo "Running performance tests..."
	locust -f $(TEST_DIR)/perfomance.py --host=$(URL)

coverage:
	cd $(BACKEND_DIR)
	. $(VENV)/bin/activate
	$(PYTHON) -m coverage run --source=. -m unittest discover -s $(TEST_DIR)
	$(PYTHON) -m coverage report -m

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type d -name "*.pyc" -delete
	find . -type d -name ".coverage" -delete
	rm -rf $(BACKEND_DIR)/$(VENV)
	docker stop $(DB_CONTAINER) || true
	docker rm $(DB_CONTAINER) || true