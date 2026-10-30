RUNTIME_SELECT = $(SELECT) $(if $(SCENARIO),--scenario "$(SCENARIO)")
runtime-golden:
	$(RUN) runtime.movies golden $(RUNTIME_SELECT) $(INPUT)
runtime-check:
	$(RUN) runtime.movies check $(RUNTIME_SELECT)
trace: runtime-check
