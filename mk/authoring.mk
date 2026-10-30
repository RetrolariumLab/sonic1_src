# Headless, profile-bound data formats; no editor or canonical recompression.
.PHONY: roundtrip-formats check-content-zero-edit source-layout-check
roundtrip-formats:
	$(RUN) authoring.cli roundtrip
check-content-zero-edit:
	$(RUN) validation.content
source-layout-check:
	$(RUN) validation.source_layout
