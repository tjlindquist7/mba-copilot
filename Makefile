# MBA Copilot - Development Makefile
# Uses pyenv + poetry for Python environment management

SHELL = /bin/bash

CYAN=\033[0;36m
RED=\033[0;31m
ORANGE=\033[38;5;208m
WHITE=\033[1;37m
RST=\033[0m

# Python Environment Setup
NAME := mba-copilot
PYMAJOR := 3
PYREV := 12
PYPATCH := 2
PYVERSION := ${PYMAJOR}.${PYREV}.${PYPATCH}
POETRY_VERSION := 1.8.3
PYENV := ~/.pyenv/versions/${PYVERSION}
VENV_NAME := ${NAME}-${PYVERSION}
VENV_DIR := ${PYENV}/envs/${VENV_NAME}
VENV := ${PYENV}/envs/${VENV_NAME}
EGGLINK := ${VENV}/lib/python${PYMAJOR}.${PYREV}/site-packages/${NAME}.egg-link
PY_BIN := ${VENV}/bin/python
PYENV_BIN := /usr/local/bin/pyenv
POETRY_BIN := PYENV_VERSION=${VENV_NAME} VIRTUAL_ENV=${VENV} ${VENV}/bin/poetry

# export PATH := ${VENV}/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin
export PATH := ${VENV}/bin:${PATH}

export PYENV_VERSION := ${VENV_NAME}
export VIRTUAL_ENV := ${VENV}

# =============================================================================
# Python Environment
# =============================================================================

${PYENV}:
	@echo -e "${CYAN}*** Installing python runtime ${WHITE}${PYVERSION}${RST}"
	${PYENV_BIN} install -s ${PYVERSION}

${VENV}: ${PYENV}
	@echo -e "${CYAN}*** Creating virtualenv ${WHITE}${VENV_NAME}${RST}"
	${PYENV_BIN} virtualenv ${PYVERSION} ${VENV_NAME}
	${PY_BIN} -m pip install -U pip setuptools wheel
	${PY_BIN} -m pip install -U poetry==${POETRY_VERSION}

.python-version: ${VENV}
	@echo -e "${CYAN}*** Setting default virtualenv to ${WHITE}${VENV_NAME}${RST}"
	echo ${VENV_NAME} > .python-version

${EGGLINK}: pyproject.toml
	@echo -e "${CYAN}*** Installing project into virtualenv${RST}"
	${POETRY_BIN} install
	touch ${EGGLINK}

# =============================================================================
# Main Targets
# =============================================================================

.PHONY: setup install clean nuke dev dev-api dev-all build format lint help

setup: .python-version ${EGGLINK} node_modules
	@echo -e "${CYAN}*** Setup complete!${RST}"
	@echo -e "${WHITE}Run 'make dev-all' to start development servers${RST}"

node_modules: package.json
	@echo -e "${CYAN}*** Installing Node.js dependencies${RST}"
	npm install
	touch node_modules

install: setup

# =============================================================================
# Development Servers
# =============================================================================

dev:
	@echo -e "${CYAN}*** Starting Next.js frontend on http://localhost:3000${RST}"
	npm run dev

dev-api:
	@echo -e "${CYAN}*** Starting FastAPI backend on http://localhost:8000${RST}"
	${POETRY_BIN} run uvicorn serverless.backend.index:app --reload --port 8000

dev-all:
	@echo -e "${CYAN}*** Starting both frontend and backend${RST}"
	@echo -e "${WHITE}Frontend: http://localhost:3000${RST}"
	@echo -e "${WHITE}Backend:  http://localhost:8000${RST}"
	@echo -e "${ORANGE}(Press Ctrl+C to stop both)${RST}"
	@trap 'kill 0' EXIT; \
		${POETRY_BIN} run uvicorn serverless.backend.index:app --reload --port 8000 & \
		npm run dev & \
		wait

# =============================================================================
# Build & Deploy
# =============================================================================

build:
	@echo -e "${CYAN}*** Building Next.js for production${RST}"
	npm run build

# =============================================================================
# Code Quality
# =============================================================================

format:
	@echo -e "${CYAN}*** Formatting Python with ruff${RST}"
	${POETRY_BIN} run ruff format serverless/
	@echo -e "${CYAN}*** Sorting imports${RST}"
	${POETRY_BIN} run ruff check --select I --fix serverless/

lint:
	@echo -e "${CYAN}*** Linting Python with ruff${RST}"
	${POETRY_BIN} run ruff check serverless/
	@echo -e "${CYAN}*** Linting TypeScript with ESLint${RST}"
	npm run lint

lint-fix:
	@echo -e "${CYAN}*** Fixing Python lint issues${RST}"
	${POETRY_BIN} run ruff check --fix serverless/

mypy:
	@echo -e "${CYAN}*** Running mypy type checks${RST}"
	${POETRY_BIN} run mypy serverless/

# =============================================================================
# Poetry Management
# =============================================================================

lock:
	${POETRY_BIN} lock

lock-check:
	@echo -e "${CYAN}*** Checking poetry.lock is up to date${RST}"
	${POETRY_BIN} lock --check

update:
	@echo -e "${ORANGE}*** Updating poetry lockfile${RST}"
	${POETRY_BIN} update

requirements:
	@echo -e "${CYAN}*** Exporting requirements.txt for Vercel${RST}"
	${POETRY_BIN} export --without-hashes --without-urls -f requirements.txt -o requirements.txt
	@echo -e "${CYAN}*** Removing Python version markers for Vercel compatibility${RST}"
	sed -E 's/ ; .*//' requirements.txt > requirements.tmp && mv requirements.tmp requirements.txt

# =============================================================================
# Cleanup
# =============================================================================

clean:
	@echo -e "${ORANGE}*** Cleaning build artifacts${RST}"
	rm -rf .next/
	rm -rf node_modules/.cache/
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

nuke: clean
	@echo -e "${RED}*** Nuking virtualenv: ${WHITE}${VENV_NAME}${RST}"
	rm -f .python-version
	${PYENV_BIN} uninstall -f ${VENV_NAME} 2>/dev/null || true
	rm -rf ${VENV_DIR}
	rm -rf node_modules/
	@echo -e "${ORANGE}*** Run 'make setup' to rebuild${RST}"

# =============================================================================
# Help
# =============================================================================

help:
	@echo -e "${WHITE}MBA Copilot - Available Commands${RST}"
	@echo ""
	@echo -e "${CYAN}Setup:${RST}"
	@echo "  make setup      - Install all dependencies (Python + Node)"
	@echo "  make install    - Alias for setup"
	@echo ""
	@echo -e "${CYAN}Development:${RST}"
	@echo "  make dev        - Start Next.js frontend only"
	@echo "  make dev-api    - Start FastAPI backend only"
	@echo "  make dev-all    - Start both frontend and backend"
	@echo ""
	@echo -e "${CYAN}Code Quality:${RST}"
	@echo "  make format     - Format Python code with ruff"
	@echo "  make lint       - Lint Python and TypeScript"
	@echo "  make lint-fix   - Auto-fix lint issues"
	@echo "  make mypy       - Run type checks"
	@echo ""
	@echo -e "${CYAN}Build:${RST}"
	@echo "  make build      - Build for production"
	@echo ""
	@echo -e "${CYAN}Cleanup:${RST}"
	@echo "  make clean      - Remove build artifacts"
	@echo "  make nuke       - Remove everything (venv + node_modules)"
	@echo ""
	@echo -e "${CYAN}Poetry:${RST}"
	@echo "  make lock       - Update poetry.lock"
	@echo "  make update     - Update dependencies"
	@echo "  make requirements - Export requirements.txt"

.DEFAULT_GOAL := help
