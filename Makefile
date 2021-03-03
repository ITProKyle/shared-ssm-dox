REPORTS := $(if $(REPORTS),yes,$(if $(CI),yes,no))
SHELL := /bin/bash

ifeq ($(strip $(shell git branch --show-current)),master)
	DEPLOY_ENVIRONMENT=common
else
	DEPLOY_ENVIRONMENT=dev
endif

help: ## show this message
	@IFS=$$'\n' ; \
	help_lines=(`fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##/:/'`); \
	printf "%-30s %s\n" "target" "help" ; \
	printf "%-30s %s\n" "------" "----" ; \
	for help_line in $${help_lines[@]}; do \
		IFS=$$':' ; \
		help_split=($$help_line) ; \
		help_command=`echo $${help_split[0]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		help_info=`echo $${help_split[2]} | sed -e 's/^ *//' -e 's/ *$$//'` ; \
		printf '\033[36m'; \
		printf "%-30s %s" $$help_command ; \
		printf '\033[0m'; \
		printf "%s\n" $$help_info; \
	done

deploy: ## deploy infrastructure
	@pushd infrastructure && \
	runway deploy --deploy-environment ${DEPLOY_ENVIRONMENT} && \
	popd

destroy: ## destroy infrastructure
	@pushd infrastructure && \
	runway destroy --deploy-environment ${DEPLOY_ENVIRONMENT} && \
	popd

dox-build: ## build SSM Documents
	@poetry run ssm-dox build

dox-check: ## check SSM Documents for drift
	@poetry run ssm-dox check

fix-black: ## automatically fix all black errors
	@poetry run black .

fix-isort: ## automatically fix all isort errors
	@poetry run isort .

lint: lint-isort lint-black lint-flake8  ## run all linters

lint-black: ## run black
	@echo "Running black... If this fails, run 'make fix-black' to resolve."
	@poetry run black . --check
	@echo ""

lint-cfn:  ## run cfn-lint
	@echo "Running cfn-lint..."
	@poetry run cfn-lint
	@echo ""

lint-flake8: ## run flake8
	@echo "Running flake8..."
	@poetry run flake8 --disable-noqa
	@echo ""

lint-isort: ## run isort
	@echo "Running isort... If this fails, run 'make fix-isort' to resolve."
	@poetry run isort . --check-only
	@echo ""

plan: ## plan infrastructure changes
	@pushd infrastructure && \
	runway plan --deploy-environment ${DEPLOY_ENVIRONMENT} && \
	popd

run-pre-commit:
	@poetry run pre-commit run -a

setup: setup-poetry setup-pre-commit  ## setup development environment

setup-poetry:  ## setup poetry environment
	@poetry install

setup-pre-commit:  ## setup pre-commit
	@poetry run pre-commit install
