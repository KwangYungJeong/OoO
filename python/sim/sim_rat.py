import sys
import os
import re

# Add the parent directory to the Python path to find the 'core' module
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from core.rat import RAT

def parse_register(reg_str):
    """Parses a register string like 'R10' into an integer."""
    match = re.match(r'R(\d+)', reg_str.strip())
    if not match:
        raise ValueError(f"Invalid register format: {reg_str}")
    return int(match.group(1))

def main():
    """Main simulation function."""
    if len(sys.argv) != 2:
        print("Usage: python sim_rat.py <instruction_file>")
        sys.exit(1)

    inst_file = sys.argv[1]

    if not os.path.exists(inst_file):
        print(f"Error: Instruction file not found at {inst_file}")
        sys.exit(1)

    # Initialize the RAT with 8 architectural registers and 16 physical registers
    num_arch_regs = 8
    num_phys_regs = 16
    # Explicitly use 'T' as the prefix to match the RAT class default
    rat = RAT(num_arch_regs, num_phys_regs, phys_reg_prefix='T')
    print(f"Initialized RAT with {num_arch_regs} architectural and {num_phys_regs} physical registers.")
    print(f"Initial State: {rat}\n")

    with open(inst_file, 'r') as f:
        for line_num, line in enumerate(f, 0):
            original_line = line.strip()
            if not original_line or original_line.startswith('#'):
                continue

            print(f"--- Processing Instruction {line_num}: \"{original_line}\" ---")

            line = original_line
            skip_rename = line.startswith('!')
            if skip_rename:
                line = line[1:].lstrip()

            parts = line.split(maxsplit=1)
            opcode = parts[0]
            operands_str = parts[1] if len(parts) > 1 else ''
            
            original_operands = [op.strip() for op in operands_str.split(',')] if operands_str else []

            dest_reg = None
            source_regs = []
            is_branch = opcode.upper().startswith('B')

            if not is_branch and original_operands:
                dest_reg = parse_register(original_operands[0])
                source_regs = [parse_register(op) for op in original_operands[1:] if op.startswith('R')]
            elif is_branch and original_operands:
                source_regs = [parse_register(op) for op in original_operands if op.startswith('R')]

            # 1. Look up source registers
            phys_sources_map = {}
            if source_regs:
                for src in source_regs:
                    phys_src = rat.get_mapping(src)
                    phys_sources_map[src] = phys_src
                    if phys_src == -1:
                        print(f"  Source Lookup: ArchReg R{src} -> (Not Mapped)")
                    else:
                        print(f"  Source Lookup: ArchReg R{src} -> PhysReg T{phys_src}")

            # 2. Rename destination register
            if dest_reg is not None and not skip_rename:
                try:
                    old_phys, new_phys = rat.rename(dest_reg)
                    print(f"  Destination Rename: ArchReg R{dest_reg} -> New PhysReg T{new_phys}")
                except RuntimeError as e:
                    print(f"  ERROR: Could not rename R{dest_reg}. {e}")
            elif dest_reg is not None and skip_rename:
                print(f"  Skipping rename for destination ArchReg R{dest_reg} as instructed by '!'.")

            # 3. Construct and print converted instruction
            final_ops = []
            if not is_branch and dest_reg is not None:
                phys_dest = rat.get_mapping(dest_reg) # Get the NEW mapping
                if phys_dest == -1:
                    final_ops.append(f"R{dest_reg}")
                else:
                    final_ops.append(f"T{phys_dest}")
                
                for op in original_operands[1:]:
                    if op.startswith('R'):
                        arch_reg = parse_register(op)
                        phys_src = phys_sources_map.get(arch_reg, -1)
                        if phys_src == -1:
                            final_ops.append(f"R{arch_reg}")
                        else:
                            final_ops.append(f"T{phys_src}")
                    else:
                        final_ops.append(op) # Keep immediate value
            else: # Branch or instruction with no operands
                 for op in original_operands:
                    if op.startswith('R'):
                        arch_reg = parse_register(op)
                        phys_src = phys_sources_map.get(arch_reg, -1)
                        if phys_src == -1:
                            final_ops.append(f"R{arch_reg}")
                        else:
                            final_ops.append(f"T{phys_src}")
                    else:
                        final_ops.append(op)
            
            converted_inst = f"{opcode} {', '.join(final_ops)}"
            print(f"  Converted: {converted_inst}")

            print(f"End of Inst {line_num} State: {rat}\n")

if __name__ == "__main__":
    main()