build-relocated:
	$(RUN) validation.relocation $(SELECT)
build-relocated-all:
	$(RUN) validation.relocation --all
audit-symbolic:
	$(RUN) validation.symbolic_pointers
verify-layout:
	$(RUN) validation.layout

.PHONY: source-layout-check
source-layout-check:
	$(RUN) validation.source_layout
