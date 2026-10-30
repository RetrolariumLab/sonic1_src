# Public preservation interface. Profile facts belong to config/revision_profiles.json.
.DEFAULT_GOAL := help
PYTHON ?= python
ROM_DIR ?= .
PROFILE ?=
SCENARIO ?=
RUN = $(PYTHON) scripts/run.py
BUILD = $(RUN) build.cli
SELECT = $(if $(PROFILE),--profile "$(PROFILE)")
INPUT = --rom-dir "$(ROM_DIR)"

.PHONY: help split check-assets check-inputs build verify verify-all verify-toolchain test audit-private clean lint format format-check build-relocated build-relocated-all audit-symbolic verify-layout runtime-golden runtime-check trace release-check release-audit
help:
	@echo Sonic 1 preservation source
	@echo "Inputs: split, check-assets, check-inputs"
	@echo "Build: build, verify, verify-all, verify-toolchain"
	@echo "Validation: lint, format, format-check, test, audit-private, audit-symbolic, verify-layout"
	@echo "Relocation: build-relocated, build-relocated-all"
	@echo "Runtime: runtime-golden, runtime-check, trace"
	@echo "Release: release-check, release-audit"
	@echo "Content: roundtrip-formats, check-content-zero-edit, source-layout-check"
	@echo "Source: scaffold-check, source-2-check, source-2-audit"
	@echo "Cleanup: clean"
	@echo "Selectors: ROM_DIR=folder, PROFILE=profile-id (default from JSON), SCENARIO=attract or ending"
split:
	$(BUILD) split $(INPUT)
check-assets:
	$(BUILD) check-assets --all
check-inputs:
	$(BUILD) inputs $(INPUT)
build:
	$(BUILD) build $(SELECT)
verify:
	$(BUILD) verify $(SELECT) $(INPUT)
verify-all:
	$(BUILD) verify-all $(INPUT)
verify-toolchain:
	$(BUILD) verify-toolchain
test:
	$(RUN) validation.test_runner
audit-private:
	$(RUN) validation.private_data
clean:
	$(BUILD) clean

lint:
	$(RUN) validation.lint_project
	$(RUN) validation.private_data
	$(RUN) validation.symbolic_pointers
format:
	$(RUN) validation.lint_project --fix
	$(MAKE) lint
format-check: lint

include mk/validation.mk
include mk/runtime.mk

include mk/release.mk

include mk/authoring.mk

.PHONY: scaffold-check source-2-check source-2-audit
scaffold-check:
	$(RUN) validation.source_2 --scaffold
source-2-audit:
	$(RUN) validation.source_2
source-2-check:
	$(RUN) validation.source_2_gate $(INPUT)
