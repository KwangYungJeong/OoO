# Modern Out-of-Order Core Simulator

This project is a multi-language exploration of a modern out-of-order (OoO) processor core. The development is planned in three stages:

1.  **Python:** A high-level, functional simulation to define and test the behavior of core components.
2.  **C++:** A more performant version of the simulator.
3.  **Verilog:** A hardware description language implementation suitable for synthesis.

## Current Status

The project currently contains a functional simulator for the **Register Alias Table (RAT)**, a critical component for handling register renaming in an OoO pipeline.

### Project Structure

```
/
├── docs/           # Detailed documentation
├── inst/           # Instruction stream files for simulation
├── python/         # Python implementation
│   ├── core/       # Core processor components (e.g., RAT)
│   └── sim/        # Simulation scripts
├── cpp/            # C++ implementation
└── verilog/        # Verilog implementation
    ├── core/       # RTL modules (e.g., rat.sv)
    └── sim/        # Testbenches (e.g., sim_rat.sv)

## Running Simulations

### Python

Execute the Python RAT simulation with an instruction file:

```bash
python3 python/sim/sim_rat.py inst/inst1.txt
```

### C++

Build and run the C++ simulation:

```bash
make -C cpp -j
./cpp/sim_rat inst/inst1.txt
```

### Verilog (iVerilog)

The Verilog testbench reads instructions from a text file using `$fopen/$fgets/$sscanf`. You can override the instruction file via a plusarg `+inst=...`.

Build:

```bash
iverilog -g2012 -o verilog/sim_rat_vvp verilog/sim/sim_rat.sv verilog/core/rat.sv
```

Run (default file is `inst/inst1.txt`; plusarg shown here for explicitness):

```bash
verilog/sim_rat_vvp +inst=$(pwd)/inst/inst1.txt
```

Notes:
- The testbench avoids SystemVerilog methods not supported by iVerilog and uses a `reg [1023:0]` line buffer for `$fgets`.
- Instruction syntax examples:
  - `ADD R2, R1, R3`
  - `!SUB R4, R2, R6`  (prefix `!` skips destination rename)
  - `BEQ R2, #1`
  - `LD R6, R2`
```
