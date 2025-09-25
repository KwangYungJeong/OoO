# Register Alias Table (RAT) Implementation Details

## Purpose

The Register Alias Table (RAT) is a key component in an out-of-order processor that enables register renaming. Its primary purpose is to eliminate false data dependencies (Write-After-Write and Write-After-Read hazards) by mapping architectural registers (e.g., `R0`, `R1`) to a larger set of physical registers (e.g., `T0`, `T1`).

This allows the processor to execute instructions that use the same architectural register in parallel, as long as they are assigned different physical registers.

## Core Components

Our core implementations (Python `python/core/rat.py` and Verilog `verilog/core/rat.sv`) maintain two main data structures:

1.  **Mapping Table:** A list or array that stores the current mapping from an architectural register index to a physical register index. An entry of `-1` signifies that the architectural register is not currently mapped.

2.  **Free List:** A list that contains all the physical registers that are currently not in use and are available for new mappings.

## Key Functions

- `__init__(num_arch_regs, num_phys_regs, init_map, ...)`: Initializes the RAT. The `init_map` flag is crucial:
    - `True`: Creates an initial 1-to-1 mapping (`R0`->`T0`, `R1`->`T1`, etc.) for all architectural registers. The remaining physical registers are placed on the free list.
    - `False`: All physical registers are initially placed on the free list, and no architectural registers are mapped.

- `get_mapping(arch_reg)`: Returns the physical register currently mapped to the given architectural register.

- `rename(arch_reg_dest, new_phys_reg)`: This is the core renaming function.
    - It finds a new physical register for the destination architectural register (`arch_reg_dest`).
    - By default (`new_phys_reg=None`), it takes the next available register from the free list.
    - It updates the mapping table to point the architectural register to the new physical register.
    - It returns the *old* physical register that was previously mapped to `arch_reg_dest`. This is critical information for the Re-Order Buffer (ROB), which will be responsible for freeing that old register once the instruction commits.

- `free_physical_register(phys_reg)`: Adds a physical register back to the free list, making it available for future renames.

## Simulation Usage

In the simulations (Python `python/sim/sim_rat.py`, C++ `cpp/sim/sim_rat.cpp`, and Verilog testbench `verilog/sim/sim_rat.sv`), the RAT processes a stream of instructions. For each instruction:

1.  **Source registers** are looked up in the RAT to find which physical registers hold their values.
2.  The **destination register** is renamed to a new physical register, and the RAT's mapping is updated.
3.  The simulation displays the "converted" instruction, showing how the architectural registers have been translated into physical registers for execution.

### Verilog Testbench I/O (iVerilog compatible)

The Verilog testbench reads instructions from a text file using `$fopen`, `$fgets`, and `$sscanf`:

- A `reg [1023:0]` line buffer is used for `$fgets`, then converted to a `string` for parsing.
- The instruction file can be specified via plusarg `+inst=<abs_or_rel_path>`. If omitted, it defaults to `inst/inst1.txt`.
- Supported formats (whitespace tolerant around commas):
  - `ADD R2, R1, R3`
  - `!SUB R4, R2, R6` (leading `!` means skip rename of destination)
  - `DIV R2, R7, R5`
  - `MUL R2, R4, R1`
  - `BEQ R2, #1`
  - `LD R6, R2`

Example build/run:

```bash
iverilog -g2012 -o verilog/sim_rat_vvp verilog/sim/sim_rat.sv verilog/core/rat.sv
verilog/sim_rat_vvp +inst=$(pwd)/inst/inst1.txt
```
