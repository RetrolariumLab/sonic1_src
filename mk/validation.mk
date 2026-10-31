build-relocated:
	$(RUN) validation.relocation $(SELECT)
build-relocated-all:
	$(RUN) validation.relocation --all
audit-symbol-names:
	$(RUN) validation.symbol_names
audit-symbolic:
	$(RUN) validation.symbolic_pointers
verify-layout:
	$(RUN) validation.layout
