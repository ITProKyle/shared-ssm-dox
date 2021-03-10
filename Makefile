.PHONY: dox tests

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
	@poetry run ssm-dox build ./dox --output ./shared_ssm_docs

dox-check: ## check SSM Documents for drift
	@poetry run ssm-dox check ./dox ./shared_ssm_docs

dox-publish: dox-check ## publish dev SSM documents
	@poetry run ssm-dox publish shared-ssm-dox-dev shared_ssm_docs

dox-publish-latest: dox-check dox-publish ## publish latest SSM documents
	@poetry run ssm-dox publish shared-ssm-dox-dev shared_ssm_docs \
		--prefix latest

lint-cfn:  ## run cfn-lint
	@echo "Running cfn-lint..."
	@poetry run cfn-lint
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
