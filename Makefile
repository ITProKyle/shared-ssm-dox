.PHONY: test

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

lint: lint-isort lint-black lint-flake8 lint-pyright lint-pylint  ## run all linters

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
	@poetry run flake8
	@echo ""

lint-isort: ## run isort
	@echo "Running isort... If this fails, run 'make fix-isort' to resolve."
	@poetry run isort . --check-only
	@echo ""

# This command requires PowerShell and the PSScriptAnalyzer PowerShell module.
# If Invoke-ScriptAnalyzer is not found, PSScriptAnalyzer needs to be installed.
#   pwsh Install-Module PSScriptAnalyzer
#
# https://github.com/PowerShell/PSScriptAnalyzer
lint-powershell: ## run PowerShell PSScriptAnalyzer
	@echo "Running PSScriptAnalyzer..."
	@pwsh -Command "& {Invoke-ScriptAnalyzer -Path ./dox/ -Recurse -Settings ./ScriptAnalyzerSettings.psd1}"
	@echo ""

lint-pylint: ## run pylint
	@echo "Running pylint..."
	@poetry run pylint --rcfile=pyproject.toml ssm_dox_builder tests --reports=${REPORTS}
	@echo ""

lint-pyright: ## run pyright
	@echo "Running pyright..."
	@npx pyright --venv-path ./
	@echo ""

# If shellcheck is not found, it needs to be installed.
#   Debian: apt install shellcheck
#   EPEL: yum -y install epel-release && yum install ShellCheck
#   macOs: brew install shellcheck
#
lint-shell: ## lint shell scripts using shellcheck
	@echo "Running shellcheck..."
	@find . -name "*.sh" -not -path "./.venv/*" | xargs shellcheck
	@echo ""

plan: ## plan infrastructure changes
	@pushd infrastructure && \
	runway plan --deploy-environment ${DEPLOY_ENVIRONMENT} && \
	popd

run-pre-commit:
	@poetry run pre-commit run -a

setup: setup-poetry setup-pre-commit  ## setup development environment

setup-poetry: ## setup poetry environment
	@poetry install

setup-pre-commit: ## setup pre-commit
	@poetry run pre-commit install

test: ## run tests
	@poetry run pytest --cov=ssm_dox_builder --cov-report term-missing:skip-covered
