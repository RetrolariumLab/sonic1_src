# Public preservation interface. Profile facts belong to config/revision_profiles.json.
.DEFAULT_GOAL := help
PYTHON ?= python
ROM_DIR ?= .
PROFILE ?=
RUN = $(PYTHON) scripts/run.py
BUILD = $(RUN) build.cli
SELECT = $(if $(PROFILE),--profile "$(PROFILE)")
INPUT = --rom-dir "$(ROM_DIR)"

.PHONY: help split check-assets check-inputs build verify verify-all verify-toolchain test audit-private clean
help:
	@echo Sonic 1 preservation source
	@echo "Inputs: split, check-assets, check-inputs"
	@echo "Build: build, verify, verify-all, verify-toolchain"
	@echo "Validation: test, audit-private"
	@echo "Cleanup: clean"
	@echo "Selectors: ROM_DIR=folder, PROFILE=profile-id (default from JSON)"
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
	$(PYTHON) -B -m unittest discover -s tests -v
audit-private:
	$(RUN) validation.private_data
clean:
	$(BUILD) clean
