AUDIT_MODE ?=
release-check:
	$(RUN) validation.release $(INPUT)
release-audit:
	$(RUN) validation.release_audit $(AUDIT_MODE)
