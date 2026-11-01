# YOLO Camera Board Bring-up

This package is a **programming candidate**, not a board acceptance certificate.
`board_verified` remains `false` until the real MES2L676-100HP board is tested.

## Files

- `bitstream.sbit`: PDS bitstream for `PG2L100H-6IFBG676`
- `firmware.bin` / `firmware.hex`: matching 27 MHz RV32IM firmware
- `model.bin`: matching six-class YOLO deployment blob
- `memory_map.json`: DDR addresses and CRC
- `camera.fdc`: exact constraints snapshot used by PDS

## Required order

1. Run the vendor DDR BIST and confirm `ddr_init_done`.
2. Program `bitstream.sbit` with the vendor JTAG tool.
3. Open the board UART at `115200 8N1` (the current firmware uses the Vexii
   UART protocol; this is not a Linux image).
4. From this package folder, load the model and verify its CRC:

   ```powershell
   & 'C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe' `
     -m pip install -r loader_requirements.txt
   & 'C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe' `
     board_loader.py --package-dir . --port COM13
   ```

   The model must be transferred after every FPGA/DDR reset because it is not
   stored in nonvolatile memory.
5. Test a known static image before enabling the camera:

   ```powershell
   # Run from this package folder. No source repository or PyTorch is required.
   & 'C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe' `
     board_loader.py --package-dir . --port COM13 --skip-model `
     --image path/to/image.jpg
   ```
6. Test one camera snapshot:

   ```powershell
   & 'C:/Users/lenovo/AppData/Local/Programs/Python/Python311/python.exe' `
     board_loader.py --package-dir . --port COM13 --skip-model --camera --frames 1
   ```

7. Record UART result, DDR status, camera init status and HDMI output. Only
   after these four observations pass may `board_verified` be changed.

The loader prints category, confidence and bounding box as JSON for both image
and camera commands. An empty detections list is a valid no-object result.
Malformed replies, bad CRCs and invalid category IDs are errors, not results.
After an interrupted transfer or firmware error, reset/reconnect and reload;
do not blindly replay a command that may already have changed DDR contents.

## Known boundaries

- The current video timing is 1280x720@60, not 1920x1080@60.
- PDS reports all modeled timing constraints met, but external camera/HDMI
  input/output delays are not independently measured on the board.
- The exact monitor compatibility is not verified. A monitor requiring
  1920x1080@60 may reject this 1280x720@60 output.
- The model classes are biodegradable, cardboard, glass, metal, paper and
  plastic; there is no hazardous-waste class.
- Mechanical sorting is not part of this candidate.
