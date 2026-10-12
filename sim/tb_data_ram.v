`timescale 1ns/1ps

module tb_data_ram;

reg         sys_clk;
reg         sys_rst_n;
reg         wen;
reg  [31:0] addr;
reg  [31:0] wdata;
wire [31:0] rdata;

integer checks;
integer errors;

data_ram #(.ADDR_WIDTH(8)) dut
(
    .sys_clk   (sys_clk),
    .sys_rst_n (sys_rst_n),
    .wen       (wen),
    .addr      (addr),
    .wdata     (wdata),
    .rdata     (rdata)
);

initial
begin
    sys_clk = 1'b0;
    forever #5 sys_clk = ~sys_clk;
end

task check32;
    input [8*80-1:0] name;
    input [31:0] actual;
    input [31:0] expected;
    begin
        checks = checks + 1;
        if (actual === expected)
            $display("[PASS] %0s: actual=%h", name, actual);
        else
        begin
            errors = errors + 1;
            $display("[FAIL] %0s: actual=%h expected=%h",
                     name, actual, expected);
        end
    end
endtask

task write_word;
    input [31:0] write_addr;
    input [31:0] write_data;
    begin
        @(negedge sys_clk);
        addr  = write_addr;
        wdata = write_data;
        wen   = 1'b1;
        @(posedge sys_clk);
        #1;
        wen = 1'b0;
    end
endtask

task read_and_check;
    input [31:0] read_addr;
    input [31:0] expected;
    input [8*80-1:0] name;
    begin
        @(negedge sys_clk);
        addr = read_addr;
        wen  = 1'b0;
        @(posedge sys_clk);
        #1;
        check32(name, rdata, expected);
    end
endtask

initial
begin
    checks    = 0;
    errors    = 0;
    sys_rst_n = 1'b1;
    wen        = 1'b0;
    addr       = 32'd0;
    wdata      = 32'd0;

    #2;
    sys_rst_n = 1'b0;
    #1;
    $display("\nTEST 1: reset masks RAM output");
    check32("rdata is zero during reset", rdata, 32'd0);

    @(negedge sys_clk);
    sys_rst_n = 1'b1;

    $display("\nTEST 2: synchronous write and read");
    write_word(32'd0, 32'hDEAD_BEEF);
    read_and_check(32'd0, 32'hDEAD_BEEF,
                   "address 0 is returned one clock after read request");

    $display("\nTEST 3: multiple and boundary addresses");
    write_word(32'd4,    32'h1111_1111);
    write_word(32'd8,    32'h1234_5678);
    write_word(32'd1020, 32'hFFFF_0000);
    read_and_check(32'd4,    32'h1111_1111, "read address 4");
    read_and_check(32'd8,    32'h1234_5678, "read address 8");
    read_and_check(32'd1020, 32'hFFFF_0000, "read address 1020");

    $display("\nTEST 4: invalid addresses");
    write_word(32'd1, 32'hAAAA_0001);
    read_and_check(32'd1, 32'd0, "misaligned address returns zero");
    write_word(32'd1024, 32'hCAFE_BABE);
    read_and_check(32'd1024, 32'd0, "out-of-range address returns zero");
    read_and_check(32'd0, 32'hDEAD_BEEF,
                   "invalid writes do not change address 0");

    $display("\nTEST 5: read-during-write behavior");
    @(negedge sys_clk);
    addr  = 32'd8;
    wdata = 32'hCAFE_BABE;
    wen   = 1'b1;
    @(posedge sys_clk);
    #1;
    check32("same-cycle read returns old data", rdata, 32'h1234_5678);
    wen = 1'b0;
    read_and_check(32'd8, 32'hCAFE_BABE,
                   "following read returns new data");

    $display("\nTEST 6: reset does not clear M9K contents");
    #2;
    sys_rst_n = 1'b0;
    #1;
    check32("rdata becomes zero immediately during reset", rdata, 32'd0);
    @(negedge sys_clk);
    sys_rst_n = 1'b1;
    read_and_check(32'd0, 32'hDEAD_BEEF,
                   "stored data remains after reset");

    $display("\n========================================");
    if (errors == 0)
        $display("tb_data_ram PASS: checks=%0d", checks);
    else
        $display("tb_data_ram FAIL: checks=%0d errors=%0d", checks, errors);
    $display("========================================\n");
    $stop;
end

endmodule
