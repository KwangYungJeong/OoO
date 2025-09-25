`timescale 1ns / 1ps

module sim_rat;

    // --- Parameters ---
    localparam NUM_ARCH_REGS = 8;
    localparam NUM_PHYS_REGS = 16;
    localparam CLK_PERIOD = 10;

    // --- Testbench Signals ---
    logic clk;
    logic rst;
    logic [ARCH_REG_WIDTH-1:0] arch_reg_dest_in;
    logic                      rename_in_valid;
    logic                      rename_out_valid;
    logic [PHYS_REG_WIDTH-1:0] phys_reg_dest_out;
    logic [ARCH_REG_WIDTH-1:0] arch_reg_src1_in;
    logic                      read1_in_valid;
    logic                      read1_out_valid;
    logic [PHYS_REG_WIDTH-1:0] phys_reg_src1_out;
    logic                      read1_found;
    logic [ARCH_REG_WIDTH-1:0] arch_reg_src2_in;
    logic                      read2_in_valid;
    logic                      read2_out_valid;
    logic [PHYS_REG_WIDTH-1:0] phys_reg_src2_out;
    logic                      read2_found;

    localparam ARCH_REG_WIDTH = $clog2(NUM_ARCH_REGS);
    localparam PHYS_REG_WIDTH = $clog2(NUM_PHYS_REGS);

    // --- Instantiate the DUT ---
    rat #(
        .NUM_ARCH_REGS(NUM_ARCH_REGS),
        .NUM_PHYS_REGS(NUM_PHYS_REGS)
    ) dut (.*);

    // --- Clock Generation ---
    always #(CLK_PERIOD / 2) clk = ~clk;

    // --- Main Simulation Logic ---
    initial begin
        integer file_handle;
        reg [1023:0] line_buf;
        string line;
        string instruction_file_name;
        string tmp;

        $display("--- Starting Verilog RAT Simulation ---");
        clk = 0;
        rst = 1;
        rename_in_valid <= 0;
        read1_in_valid <= 0;
        read2_in_valid <= 0;
        @(posedge clk);
        rst <= 0;

        // Allow override via +inst=<path>; default to inst/inst1.txt
        if (!$value$plusargs("inst=%s", instruction_file_name)) begin
            instruction_file_name = "inst/inst1.txt";
        end

        file_handle = $fopen(instruction_file_name, "r");
        if (file_handle == 0) begin
            $error("Error: Could not open instruction file %s", instruction_file_name);
            $finish;
        end

        $display("\n--- Processing Instructions from %s ---", instruction_file_name);
        begin
            integer is_comment;
            integer has_token;
            while (!$feof(file_handle)) begin
                void'($fgets(line_buf, file_handle));
                line = line_buf;

                is_comment = ($sscanf(line, " #%s", tmp) == 1);
                has_token = ($sscanf(line, " %s", tmp) == 1);

                if (!(is_comment || !has_token)) begin
                    process_instruction(line);
                end
            end
        end

        $fclose(file_handle);

        // De-assert all inputs
        read1_in_valid <= 0;
        read2_in_valid <= 0;
        rename_in_valid <= 0;

        #50;
        $display("--- Simulation Finished ---");
        $finish;
    end

    task process_instruction(input string instruction_line);
        string opcode_str;
        string converted_inst;
        string tmp;

        logic skip_rename = 1'b0;
        int dest_reg = -1;
        int src1_reg = -1;
        int src2_reg = -1;
        int imm_val = 0;

        $display("--- Processing Instruction: \"%s\" ---", instruction_line);

        // Parse optional '!' prefix and opcode only
        if ($sscanf(instruction_line, " !%s", opcode_str) == 1) begin
            skip_rename = 1'b1;
        end else begin
            void'($sscanf(instruction_line, " %s", opcode_str));
        end

        // Operand parsing based on opcode with explicit patterns (avoid scansets)
        if (opcode_str == "BEQ") begin
            if ($sscanf(instruction_line, " !BEQ R%d, #%d", src1_reg, imm_val) < 2)
                void'($sscanf(instruction_line, " BEQ R%d, #%d", src1_reg, imm_val));
        end else if (opcode_str == "LD") begin
            if ($sscanf(instruction_line, " !LD R%d, R%d", dest_reg, src1_reg) < 2)
                void'($sscanf(instruction_line, " LD R%d, R%d", dest_reg, src1_reg));
        end else begin
            // 3-operand format (ADD/SUB/MUL/DIV ...)
            if ($sscanf(instruction_line, " !%s R%d, R%d, R%d", tmp, dest_reg, src1_reg, src2_reg) < 4)
                void'($sscanf(instruction_line, " %s R%d, R%d, R%d", tmp, dest_reg, src1_reg, src2_reg));
        end

        // Reset inputs
        rename_in_valid <= 0;
        read1_in_valid <= 0;
        read2_in_valid <= 0;

        // Apply inputs based on parsed instruction
        if (dest_reg != -1 && !skip_rename && opcode_str != "BEQ") begin
            rename_in_valid <= 1;
            arch_reg_dest_in <= dest_reg;
        end

        if (src1_reg != -1) begin
            read1_in_valid <= 1;
            arch_reg_src1_in <= src1_reg;
        end

        if (src2_reg != -1) begin
            read2_in_valid <= 1;
            arch_reg_src2_in <= src2_reg;
        end

        #1; // Wait for DUT to settle

        // Display outputs
        if (src1_reg != -1) begin
            if (read1_found) $display("  Source Lookup: ArchReg R%0d -> PhysReg T%0d", src1_reg, phys_reg_src1_out);
            else $display("  Source Lookup: ArchReg R%0d -> (Not Mapped)", src1_reg);
        end
        if (src2_reg != -1) begin
            if (read2_found) $display("  Source Lookup: ArchReg R%0d -> PhysReg T%0d", src2_reg, phys_reg_src2_out);
            else $display("  Source Lookup: ArchReg R%0d -> (Not Mapped)", src2_reg);
        end

        if (dest_reg != -1 && opcode_str != "BEQ") begin
            if (skip_rename) begin
                $display("  Skipping rename for destination ArchReg R%0d as instructed by '!'.", dest_reg);
            end else if (rename_out_valid) begin
                $display("  Destination Rename: ArchReg R%0d -> New PhysReg T%0d", dest_reg, phys_reg_dest_out);
            end else begin
                $display("  ERROR: Could not rename R%0d. No free physical registers.", dest_reg);
            end
        end

        // Construct and display converted instruction (avoid nested $sformatf for iVerilog)
        begin
            string dest_str;
            string src1_str;
            string src2_str;
            dest_str = "";
            src1_str = "";
            src2_str = "";

            if (opcode_str == "BEQ") begin
                if (src1_reg != -1) begin
                    if (read1_found) src1_str = $sformatf("T%0d", phys_reg_src1_out);
                    else src1_str = $sformatf("R%0d", src1_reg);
                end
                converted_inst = $sformatf("  Converted: %s %s, #%0d", opcode_str, src1_str, imm_val);
            end else begin
                if (dest_reg != -1) begin
                    if (rename_out_valid && !skip_rename) dest_str = $sformatf("T%0d", phys_reg_dest_out);
                    else dest_str = $sformatf("R%0d", dest_reg);
                end
                if (src1_reg != -1) begin
                    if (read1_found) src1_str = $sformatf("T%0d", phys_reg_src1_out);
                    else src1_str = $sformatf("R%0d", src1_reg);
                end
                if (src2_reg != -1) begin
                    if (read2_found) src2_str = $sformatf("T%0d", phys_reg_src2_out);
                    else src2_str = $sformatf("R%0d", src2_reg);
                end

                // Assemble based on which operands are present
                converted_inst = $sformatf("  Converted: %s", opcode_str);
                if (dest_str.len() > 0) converted_inst = $sformatf("%s %s", converted_inst, dest_str);
                if (src1_str.len() > 0) converted_inst = $sformatf("%s, %s", converted_inst, src1_str);
                if (src2_str.len() > 0) converted_inst = $sformatf("%s, %s", converted_inst, src2_str);
            end
        end
        $display(converted_inst);

        $display("End of Instruction State\n");
        @(posedge clk);
    endtask

endmodule
