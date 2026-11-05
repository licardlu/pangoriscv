# Pre-P&R Source Package

This package contains the frozen source snapshot used to start the
`vexii_camera_20261103_000352` seed-1 build.

## Contents

- `sources/`: captured RTL, include files, FDC, firmware and generated CPU ROM
  images. These files match `source_manifest.json`.
- `portable/009_Ram.v`: same captured RAM RTL with only the eight ROM image
  paths changed from machine-specific absolute paths to package-local filenames.
- `portable/052_yolo_camera_top.v`: captured top-level RTL with the firmware
  parameter changed to the packaged `program.hex` filename.
- `build_pre_pnr.tcl`: relocatable PDS flow ending at `dev_map`. It does not run
  placement, routing, timing reports, or bitstream generation.
- `ipcore/`: IDFs and source files referenced by the DDR3, PLL, read-frame-buffer,
  and write-frame-buffer IPs.
- `software/`: firmware and YOLO runtime source files.
- `model/`: the packed model and its graph/memory metadata.
- `source_manifest.json`: original source paths and SHA-256 values from the
  captured build snapshot.

## Build Boundary

This is a source package for the pre-placement-and-routing stage. It does not
contain P&R databases or a bitstream, and it has not been verified on the board.
The seed-1 build was in progress when the package was assembled; packaging read
only its captured source directory and did not alter or stop that build.

The portable Tcl uses the packaged source tree and changes directory to
`sources/` so the ROM image filenames resolve locally. It requires the Pango
PDS 2022.2 toolchain and the target device settings embedded in the flow.

The exact captured `sources/009_Ram.v` is retained for auditability. The build
script uses `portable/009_Ram.v` to avoid hard-coded paths to the original
machine.

`software/` and the model metadata are copies of the working files at packaging
time; they are not claimed to be frozen source inputs to the captured firmware.
The exact firmware used by the build is retained under `sources/`.
