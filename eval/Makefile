# connect-migrate evaluation harness.
# See README.md. All targets are runner-agnostic; nothing here knows how agents
# are spawned or driven.

EVAL_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

.DEFAULT_GOAL := help

.PHONY: help workdir grade test

help: ## Show this help
	@echo "connect-migrate eval harness"
	@echo
	@echo "Targets:"
	@echo "  make workdir DIR=<path>                 Build an isolated single-commit work dir"
	@echo "                                          from fixtures/ (hand it to one agent)."
	@echo "  make grade DIR=<path> EXPECTED=<path>   Grade a candidate: analyze + diff vs the"
	@echo "                                          (private) reference migration."
	@echo "  make test                               Run analyzer golden/snapshot tests"
	@echo "                                          (tests/run.sh; UPDATE=1 to refresh)."
	@echo
	@echo "Deliver eval/prompt.txt to the agent verbatim. See README.md for scoring + integrity."

workdir: ## Build an isolated work dir: make workdir DIR=/tmp/agent-x
	@test -n "$(DIR)" || { echo "set DIR=<path>"; exit 1; }
	@"$(EVAL_DIR)scripts/make-workdir.sh" "$(DIR)"

grade: ## Grade a candidate: make grade DIR=/tmp/agent-x EXPECTED=/path/to/golden
	@test -n "$(DIR)" || { echo "set DIR=<candidate path>"; exit 1; }
	@test -n "$(EXPECTED)" || { echo "set EXPECTED=<reference migration path>"; exit 1; }
	@"$(EVAL_DIR)scripts/grade.sh" "$(DIR)" "$(EXPECTED)"

test: ## Run analyzer golden/snapshot tests (UPDATE=1 to refresh snapshots)
	@"$(EVAL_DIR)tests/run.sh"
