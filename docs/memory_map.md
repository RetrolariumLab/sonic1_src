# Memory and register map

`config/reconstruction/memory_map.json` owns the numeric landmarks below.
`make release-audit` checks them against every current canonical AS listing.
Addresses use the 24-bit 68000 bus; RAM symbols may be sign-extended in AS.

| Symbol             | Space      | REV00     | REV01     | REVXB     |
| ------------------ | ---------- | --------- | --------- | --------- |
| `v_ram_start`      | m68000_ram | `$FF0000` | `$FF0000` | `$FF0000` |
| `v_256x256`        | m68000_ram | `$FF0000` | `$FF0000` | `$FF0000` |
| `v_256x256_end`    | m68000_ram | `$FFA400` | `$FFA400` | `$FFA400` |
| `v_lvllayout`      | m68000_ram | `$FFA400` | `$FFA400` | `$FFA400` |
| `v_lvllayout_end`  | m68000_ram | `$FFA800` | `$FFA800` | `$FFA800` |
| `v_objspace`       | m68000_ram | `$FFD000` | `$FFD000` | `$FFD000` |
| `v_objspace_end`   | m68000_ram | `$FFF000` | `$FFF000` | `$FFF000` |
| `v_gamemode`       | m68000_ram | `$FFF600` | `$FFF600` | `$FFF600` |
| `v_screenposx`     | m68000_ram | `$FFF700` | `$FFF700` | `$FFF700` |
| `v_screenposy`     | m68000_ram | `$FFF704` | `$FFF704` | `$FFF704` |
| `v_rings`          | m68000_ram | `$FFFE20` | `$FFFE20` | `$FFFE20` |
| `v_score`          | m68000_ram | `$FFFE26` | `$FFFE26` | `$FFFE26` |
| `v_lives`          | m68000_ram | `$FFFE12` | `$FFFE12` | `$FFFE12` |
| `vdp_data_port`    | hardware   | `$C00000` | `$C00000` | `$C00000` |
| `vdp_control_port` | hardware   | `$C00004` | `$C00004` | `$C00004` |
| `vdp_counter`      | hardware   | `$C00008` | `$C00008` | `$C00008` |
| `psg_input`        | hardware   | `$C00011` | `$C00011` | `$C00011` |
| `z80_ram`          | hardware   | `$A00000` | `$A00000` | `$A00000` |
| `z80_bus_request`  | hardware   | `$A11100` | `$A11100` | `$A11100` |
| `z80_reset`        | hardware   | `$A11200` | `$A11200` | `$A11200` |
| `Vectors`          | m68000_rom | `$000000` | `$000000` | `$000000` |
| `CartridgeHeader`  | m68000_rom | `$000100` | `$000100` | `$000100` |
| `EndOfHeader`      | m68000_rom | `$000200` | `$000200` | `$000200` |
| `EntryPoint`       | m68000_rom | `$000206` | `$000206` | `$000206` |
| `GameProgram`      | m68000_rom | `$000300` | `$000300` | `$000300` |
| `GM_Sega`          | m68000_rom | `$002E10` | `$002DD2` | `$002DD2` |
| `GM_Title`         | m68000_rom | `$002F18` | `$002EF4` | `$002EF4` |
| `GM_Level`         | m68000_rom | `$0037A2` | `$00379E` | `$00379E` |
| `AngleMap`         | m68000_rom | `$062900` | `$062900` | `$062900` |
| `SoundDriver`      | m68000_rom | `$071990` | `$071990` | `$071990` |
| `EndOfRom`         | m68000_rom | `$080000` | `$080000` | `$080000` |

The cartridge occupies `$000000..$07FFFF`; vectors are the first `$100` bytes
and the header is `$100..$1FF`. Executable code begins after the header. ROM
content and engine tables are interleaved by the declared include order;
individual private slices have exact offsets and lengths in the asset manifest.
The REVXB spike patch intentionally occupies reserved vector bytes, declared in
`config/reconstruction/address_policy.json`.

Work RAM is `$FF0000..$FFFFFF` (64 KiB). The 256x256 chunk buffer is followed by
the interlaced foreground/background level layout and rendering buffers. The
object pool contains 128 records of `$40` bytes, including Sonic at its first
slot. Later RAM holds mode, camera, palette, level and audio state.
`src/memory/ram.asm` owns the complete allocation and alias relationships.

The 68000 maps Z80 RAM at `$A00000..$A01FFF`, YM2612 at `$A04000..$A04003`, bank
select at `$A06000`, bus request at `$A11100` and reset at `$A11200`.
Controller/version ports start at `$A10000`; TMSS is at `$A14000`. The VDP
data/control/counter ports and PSG write port are named above.

The Z80 address space differs: DAC code starts at zero, the decoded driver and
its samples occupy 7110 bytes, stack is `$1FFC`, DAC status `$1FFD` and sample
request `$1FFF`. Its banked cartridge window is `$8000..$FFFF`. These
constraints are verified by `make verify-layout`; cartridge offsets must never
be confused with decoded Z80 addresses.

Generated AS listings live at `build/artifacts/<profile>/entry.lst`; the shared
listing parser resolves numeric symbols, including equates and phased Z80
declarations. Listings are analysis artifacts, never tracked or required as old
build inputs. No standalone debugger-symbol export is claimed.
