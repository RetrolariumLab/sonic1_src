# Remaining uncertainty

Preservation identity and the documented runtime scope are separate from a
complete semantic reconstruction. These records describe the current boundary.

| ID       | Owner/range                                         | Status and reason                                                                                                                                                                     | Next useful evidence                                                           |
| -------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| SEM-001  | Imported engine routines and object state machines  | Community names and comments are retained; this project has not independently proved every interpretation.                                                                            | Compare source ownership, state transitions and targeted original-ROM traces.  |
| RUN-001  | Gameplay outside the attract and ending movie paths | The current runtime matrix covers the recorded paths, not every act, boss or player choice.                                                                                           | Add focused scenarios with explicit observations and predicates.               |
| DATA-002 | Historical compressed token choices                 | Nemesis and Kosinski encoders prove decoded equivalence but do not reproduce every original token choice.                                                                             | Keep original streams for zero edits and validate genuine re-encodings.        |
| DATA-003 | General content insertion and shared compiled views | Checked encoders produce bounded payloads; only bounded private palette probes rebuild edited ROMs; general composition and automatic shared-view merge remain outside this baseline. | Add a separately reviewed composer with explicit ownership conflict handling.  |
| LEG-001  | Imported code and annotations                       | No upstream licence grant accompanies the disclaimer.                                                                                                                                 | A rights-holder or upstream licence grant; technical checks cannot supply one. |

Resolved toolchain and source-layout issues are described with their concrete
controls in [build](build.md), [relocation](relocation.md) and
[provenance](provenance.md). A passing identity check does not close SEM-001 or
RUN-001. Format-level models and limitations are documented in
[data formats](data_formats.md); the draft remains subject to its complete
acceptance gates.
