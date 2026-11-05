# Headless, profile-bound data formats; no editor or canonical recompression.
.PHONY: roundtrip-formats check-content-zero-edit source-layout-check
roundtrip-formats:
	$(RUN) authoring.cli roundtrip
check-content-zero-edit:
	$(RUN) validation.content
source-layout-check:
	$(RUN) validation.source_layout

.PHONY: prepare-core check-core check-content-edits
prepare-core:
	$(RUN) authoring.prepare_core prepare
check-core:
	$(RUN) authoring.prepare_core check
check-content-edits: verify-all
	$(RUN) authoring.edited_containers
