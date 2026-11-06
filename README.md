# Champions of Krynn v1.0 reconstruction

This tree targets the raw-MZ, TPOV release in `drive_c/KRYNN.V10`, the original
retail floppies; `START.EXE` names itself "Champions Of Krynn v1.0". It reproduces
both shipped files byte for byte: the gate reports 2 of 2.

It was derived from the byte-exact v1.1 tree. The two releases share one layout:
same segment map, same DGROUP `0xd3c`, same SS:SP `1606:4000`, and 35 overlay records
with matching trap counts. v1.0 differs from v1.1 at these points:

| Where | v1.0 | v1.1 |
|---|---|---|
| FixMain, both menu titles | `v1.0` | `v1.1` |
| GameInit, tile-set buffer 1 | 48 slots (`$30`) | 40 slots (`$28`) |
| MapTiles.load24x24Set range check | `slot > 48` | `slot > 39` |
| GameDat4.knownSpellTable byte 4 | `$00` | `$08` |
| EffHndlr.configureAttackDamage | no debug trace | `printDebug('bad news', ...)` |
| EffHndlr.consumeMirrorImage | single-target spells only | also weapon attacks |
| CbtActs, post-hit effect trigger | any hit on a defender in play | only when damage > 0 |
| CharGen.createCharacterMenu, abandon paths | bare `FreeMem(cr, 409)` (leaks) | `freeCreature(cr)` |
| CharGen.createCharacterMenu, age arm | class 12 omitted | class 12 included |
| FxEngine.considerTerrainEffects, cough | 1 round | `rollDice(1, 4) + 1` |
| FxEngine.attackRoll | light adjustment for both sides, `printDebug('thac0', ...)` | party only, no trace |
| sounddrv.asm | v1.0's build-time buffer residue | v1.1's |

The overlay-buffer word at DS:0x4372 and the MZ header's minimum allocation differ too,
but the linker derives both from the largest record (CHARGEN), so no source carries them.

The compiler, `tp55` in `goldbox.toml` `[v10].toolchain`, is pinned by the heap call
convention: every `GetMem` site returns in DX:AX and the callee pops one word, the
TP 5.5 shape, with no Borland stamp and a TPOV container to rule out 6.0.

Useful commands:

```
gametools/build.sh --game krynn --ver v10
gametools/gate.sh --game krynn --ver v10
.venv/bin/python gametools/status.py --game krynn --ver v10
gametools/verify_callees.py --game krynn --ver v10 --state EXE-UNC
.venv/bin/python gametools/ovr_v11.py census \
  drive_c/KRYNN.V10/EXE-UNC/START.EXE drive_c/KRYNN.V10/EXE-UNC/GAME.OVR \
  v10/obj/START.EXE v10/obj/GAME.OVR
```

`ovr_v11.py` reads v1.0's TPOV container unchanged, and `status.py` and
`mainseg_audit.py` route v1.0 through their v1.1 paths. `EXE-UNC` is byte-identical to
`EXE-UNP`: no patch is known on this disc, and no witness exists for v1.0.
