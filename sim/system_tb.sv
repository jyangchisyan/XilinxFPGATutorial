`timescale 1ns/1ps
module system_tb;
    reg clk = 0;
    reg resetn = 0;
    always #5 clk = ~clk;
    wire [0:0] led;
    wire [12:0] addr;
    wire [2:0] ba;
    wire cas_n, ras_n, we_n;
    wire [0:0] ck_p, ck_n, cke, cs_n, odt;
    wire [1:0] dm;
    wire [15:0] dq;
    wire [1:0] dqs_p, dqs_n;
    system_wrapper dut (
        .CLK100MHZ(clk), .CPU_RESETN(resetn), .LED(led),
        .ddr2_sdram_addr(addr), .ddr2_sdram_ba(ba),
        .ddr2_sdram_cas_n(cas_n), .ddr2_sdram_ras_n(ras_n), .ddr2_sdram_we_n(we_n),
        .ddr2_sdram_ck_p(ck_p), .ddr2_sdram_ck_n(ck_n),
        .ddr2_sdram_cke(cke), .ddr2_sdram_cs_n(cs_n), .ddr2_sdram_odt(odt),
        .ddr2_sdram_dm(dm), .ddr2_sdram_dq(dq),
        .ddr2_sdram_dqs_p(dqs_p), .ddr2_sdram_dqs_n(dqs_n)
    );
    ddr2_model memory (
        .ck(ck_p[0]), .ck_n(ck_n[0]), .cke(cke[0]), .cs_n(cs_n[0]),
        .ras_n(ras_n), .cas_n(cas_n), .we_n(we_n), .dm_rdqs(dm),
        .ba(ba), .addr(addr), .dq(dq), .dqs(dqs_p), .dqs_n(dqs_n),
        .rdqs_n(), .odt(odt[0])
    );
    `include "firmware_symbols.vh"
    reg passed = 0;
    integer boots = 0;
    always @(posedge dut.system_i.mig_7series_0_ui_clk) begin
        if (resetn && dut.system_i.mig_7series_0_init_calib_complete === 1'b0
                   && dut.system_i.rst_ui_mb_reset === 1'b0)
            $fatal(1, "CPU released before DDR calibration");
        if (!dut.system_i.rst_ui_mb_reset && dut.system_i.microblaze_0_DLMB_WRITESTROBE
            && dut.system_i.microblaze_0_DLMB_ABUS == STATUS_ADDR) begin
            if (dut.system_i.microblaze_0_DLMB_WRITEDBUS == 32'hdead)
                $fatal(1, "Firmware DDR test failed");
            if (dut.system_i.microblaze_0_DLMB_WRITEDBUS == 2) passed <= 1;
        end
    end
    initial begin
        #1000 resetn = 1;
        wait (passed);
        wait (led[0] === 1'b1);
        boots = boots + 1;
        // Re-run the entire calibration/reset/BRAM boot path after a button reset.
        resetn = 0;
        #1000;
        passed = 0;
        resetn = 1;
        wait (passed);
        wait (led[0] === 1'b1);
        boots = boots + 1;
        $display("PASS: %0d BRAM boots, DDR tests, GPIO output and reset sequencing", boots);
        $finish;
    end
    initial begin
        #20000000;
        $fatal(1, "Timeout waiting for calibration/firmware/GPIO");
    end
endmodule
