# Register Alias Table (RAT)

class RAT:
    """
    Register Alias Table
    """
    def __init__(self, num_arch_regs, num_phys_regs, init_map=False, arch_reg_prefix='R', phys_reg_prefix='T'):
        """
        Initializes the Register Alias Table.

        Args:
            num_arch_regs (int): The number of architectural registers.
            num_phys_regs (int): The number of physical registers.
            init_map (bool): If True, initializes a 1-to-1 mapping for architectural registers.
                             If False, all physical registers are initially free.
            arch_reg_prefix (str): The prefix for architectural register names.
            phys_reg_prefix (str): The prefix for physical register names.
        """
        if num_phys_regs < num_arch_regs:
            raise ValueError("Number of physical registers must be greater than or equal to the number of architectural registers.")

        self.num_arch_regs = num_arch_regs
        self.num_phys_regs = num_phys_regs
        self.arch_reg_prefix = arch_reg_prefix
        self.phys_reg_prefix = phys_reg_prefix

        if init_map:
            # Initialize so that arch_reg 'i' maps to phys_reg 'i'.
            self.mapping = list(range(num_arch_regs))
            # The remaining physical registers are free.
            self.free_list = list(range(num_arch_regs, num_phys_regs))
        else:
            # All physical registers are free, no initial mapping.
            self.mapping = [-1] * num_arch_regs  # -1 indicates no mapping
            self.free_list = list(range(num_phys_regs))

    def get_mapping(self, arch_reg):
        """
        Gets the physical register currently mapped to an architectural register.

        Args:
            arch_reg (int): The architectural register.

        Returns:
            int: The physical register, or -1 if not mapped.
        """
        if not 0 <= arch_reg < self.num_arch_regs:
            raise ValueError(f"Invalid architectural register: {arch_reg}")
        return self.mapping[arch_reg]

    def rename(self, arch_reg_dest, new_phys_reg=None):
        """
        Renames a destination architectural register to a new physical register.

        Args:
            arch_reg_dest (int): The destination architectural register to rename.
            new_phys_reg (int, optional): Specific physical register to allocate. 
                                      If None, allocates automatically from the free list. 
                                      Defaults to None.

        Returns:
            tuple[int, int]: The old physical register and the new physical register.
        """
        if not 0 <= arch_reg_dest < self.num_arch_regs:
            raise ValueError(f"Invalid architectural register: {arch_reg_dest}")

        old_phys_reg = self.mapping[arch_reg_dest]

        if new_phys_reg is None:
            # Automatic allocation
            if not self.free_list:
                raise RuntimeError("No free physical registers available for automatic allocation.")
            new_phys_reg = self.free_list.pop(0)
        else:
            # Specific allocation
            if not 0 <= new_phys_reg < self.num_phys_regs:
                raise ValueError(f"Invalid physical register: {new_phys_reg}")
            if new_phys_reg not in self.free_list:
                raise ValueError(f"Requested physical register {new_phys_reg} is not available in the free list.")
            self.free_list.remove(new_phys_reg)

        self.mapping[arch_reg_dest] = new_phys_reg

        return old_phys_reg, new_phys_reg

    def free_physical_register(self, phys_reg):
        """
        Adds a physical register back to the free list.

        Args:
            phys_reg (int): The physical register to free.
        """
        if not 0 <= phys_reg < self.num_phys_regs:
            raise ValueError(f"Invalid physical register: {phys_reg}")
        if phys_reg in self.free_list:
            raise ValueError(f"Physical register {phys_reg} is already in the free list.")
        
        self.free_list.append(phys_reg)
        self.free_list.sort()  # Keep the list sorted for deterministic behavior

    def __str__(self):
        map_str = ", ".join([f"{self.arch_reg_prefix}{i}->{self.phys_reg_prefix}{p}" if p != -1 else f"{self.arch_reg_prefix}{i}->N/A" for i, p in enumerate(self.mapping)])
        free_str = ", ".join([f"{self.phys_reg_prefix}{i}" for i in self.free_list])
        return f"RAT(mapping=[{map_str}], free_list=[{free_str}])"