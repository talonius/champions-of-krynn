# Champions of Krynn v1.1 reconstruction

This tree targets the raw-MZ, TPOV release in `drive_c/KRYNN.V11`.

The compiler, `tp55` in `goldbox.toml` `[v11].toolchain`, is pinned by the Overlay API
discriminator: the shipped-shaped GameBoot uses `OvrReadBuf`, present in TP5.5 and
rejected by stock TP5.0. This tree reproduces the shipped bytes from source;
`.venv/bin/python -m goldbox.repo gate --repo .` is the gate that says so.

Useful commands:

```
gametools/build.sh --game krynn --ver v11
.venv/bin/python gametools/status.py --game krynn --ver v11
.venv/bin/python gametools/ovr_v11.py gate --pins --raw-exact 0 \
  drive_c/KRYNN.V11/EXE-UNC/START.EXE drive_c/KRYNN.V11/EXE-UNC/GAME.OVR \
  v11/obj/START.EXE v11/obj/GAME.OVR
.venv/bin/python gametools/ovr_v11.py records \
  drive_c/KRYNN.V11/EXE-UNC/START.EXE drive_c/KRYNN.V11/EXE-UNC/GAME.OVR
.venv/bin/python -m goldbox.twin_finder \
  --title-a krynn-v11:drive_c/KRYNN.V11/EXE-UNC/START.EXE,drive_c/KRYNN.V11/EXE-UNC/GAME.OVR \
  --title-b krynn-v12:drive_c/KRYNN.V12/EXE-UNC/START.EXE,drive_c/KRYNN.V12/EXE-UNC/GAME.OVR
```

`EXE-UNC` is the pristine derived state the record tools compare against; for v1.1 it
is byte-identical to `EXE-UNP`, since no patch is known on that disc (UNCHECKED: no
witness exists for v1.1).
