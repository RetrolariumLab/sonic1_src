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

.PHONY: check-memory-contract check-memory-layout
check-memory-contract:
	$(RUN) validation.memory_contracts
check-memory-layout:
	$(RUN) validation.memory_contracts --built
