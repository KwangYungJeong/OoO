


module rat #(
    parameter NUM_ARCH_REGS = 8,
    parameter NUM_PHYS_REGS = 16,
    parameter INIT_MAP = 0 // 0 for all free, 1 for 1-to-1 mapped
) (
    // Common signals
    input logic clk,
    input logic rst,

    // Rename Port (for destination registers)
    input logic [ARCH_REG_WIDTH-1:0] arch_reg_dest_in,
    input logic                      rename_in_valid,
    output logic                     rename_out_valid,
    output logic [PHYS_REG_WIDTH-1:0] phys_reg_dest_out,

    // Read Port 1 (for source registers)
    input logic [ARCH_REG_WIDTH-1:0] arch_reg_src1_in,
    input logic                      read1_in_valid,
    output logic                     read1_out_valid,
    output logic [PHYS_REG_WIDTH-1:0] phys_reg_src1_out,
    output logic                     read1_found, // Indicates if a valid mapping exists

    // Read Port 2 (for source registers)
    input logic [ARCH_REG_WIDTH-1:0] arch_reg_src2_in,
    input logic                      read2_in_valid,
    output logic                     read2_out_valid,
    output logic [PHYS_REG_WIDTH-1:0] phys_reg_src2_out,
    output logic                     read2_found
);

    // --- Local Parameters ---
    localparam ARCH_REG_WIDTH = $clog2(NUM_ARCH_REGS);
    localparam PHYS_REG_WIDTH = $clog2(NUM_PHYS_REGS);

    // --- Data Structures ---
    logic [PHYS_REG_WIDTH:0] mapping_table [NUM_ARCH_REGS-1:0];
    logic [NUM_PHYS_REGS-1:0] free_list;

    // --- Combinational Logic ---
    logic [PHYS_REG_WIDTH-1:0] first_free_phys_reg;
    logic                      free_list_empty;

    // Function to find the first free physical register
    function automatic [PHYS_REG_WIDTH-1:0] find_first_free(logic [NUM_PHYS_REGS-1:0] list);
        for (int i = 0; i < NUM_PHYS_REGS; i++) begin
            if (list[i]) return i;
        end
        return '0; // Default case
    endfunction

    // Assign combinational outputs
    assign first_free_phys_reg = find_first_free(free_list);
    assign free_list_empty = (free_list == 0);

    // Read Port 1 Logic
    assign read1_out_valid = read1_in_valid;
    assign read1_found = mapping_table[arch_reg_src1_in][PHYS_REG_WIDTH];
    assign phys_reg_src1_out = mapping_table[arch_reg_src1_in][PHYS_REG_WIDTH-1:0];

    // Read Port 2 Logic
    assign read2_out_valid = read2_in_valid;
    assign read2_found = mapping_table[arch_reg_src2_in][PHYS_REG_WIDTH];
    assign phys_reg_src2_out = mapping_table[arch_reg_src2_in][PHYS_REG_WIDTH-1:0];

    // Rename Port Output Logic
    assign rename_out_valid = rename_in_valid && !free_list_empty;
    assign phys_reg_dest_out = first_free_phys_reg;

    // --- Sequential Logic ---
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset the mapping table and free list
            for (int i = 0; i < NUM_ARCH_REGS; i++) begin
                if (INIT_MAP == 1 && i < NUM_PHYS_REGS) begin
                    mapping_table[i] <= {1'b1, i[PHYS_REG_WIDTH-1:0]};
                end else begin
                    mapping_table[i] <= '0; // Invalid mapping
                end
            end

            if (INIT_MAP == 1) begin
                free_list <= (1'b1 << NUM_PHYS_REGS) - (1'b1 << NUM_ARCH_REGS);
            end else begin
                free_list <= '1; // All registers are free
            end
        end else begin
            // On a valid rename request, update the tables
            if (rename_in_valid && !free_list_empty) begin
                // Update mapping table with the new physical register
                mapping_table[arch_reg_dest_in] <= {1'b1, first_free_phys_reg};

                // Update free list (mark the register as not free)
                free_list[first_free_phys_reg] <= 1'b0;
            end
        end
    end

endmodule