// Educational M-mode subset for the board's private countdown Timer.
// The Timer is a platform-local interrupt, cause 16 / mie[16] / mip[16].
// It is not the standard mtime/mtimecmp machine timer interrupt (cause 7).
module irq_csrs
(
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire [11:0] csr_addr,
    input  wire [31:0] csr_wdata,
    input  wire        csr_write,
    input  wire        trap,
    input  wire [31:0] trap_pc,
    input  wire        mret,
    input  wire        timer_irq,
    output reg  [31:0] csr_rdata,
    output wire        irq_request,
    output reg  [31:0] mtvec,
    output reg  [31:0] mepc,
    output reg  [31:0] mcause
);
reg mie_global, mpie, mie_local;
assign irq_request = mie_global && mie_local && timer_irq;

always @(*)
    case (csr_addr)
        12'h300: csr_rdata = {19'd0, 2'b11, 3'd0, mpie, 3'd0, mie_global, 3'd0};
        12'h304: csr_rdata = {15'd0, mie_local, 16'd0};
        12'h305: csr_rdata = mtvec;
        12'h341: csr_rdata = mepc;
        12'h342: csr_rdata = mcause;
        12'h344: csr_rdata = {15'd0, timer_irq, 16'd0};
        default: csr_rdata = 32'd0;
    endcase

always @(posedge sys_clk or negedge sys_rst_n)
    if (sys_rst_n == 1'b0)
    begin
        mie_global <= 1'b0;
        mpie       <= 1'b0;
        mie_local  <= 1'b0;
        mtvec      <= 32'd0;
        mepc       <= 32'd0;
        mcause     <= 32'd0;
    end
    else if (trap)
    begin
        mepc       <= {trap_pc[31:2], 2'b00};
        mcause     <= 32'h8000_0010;
        mpie       <= mie_global;
        mie_global <= 1'b0;
    end
    else if (mret)
    begin
        mie_global <= mpie;
        mpie       <= 1'b1;
    end
    else if (csr_write)
        case (csr_addr)
            12'h300:
            begin
                mie_global <= csr_wdata[3];
                mpie       <= csr_wdata[7];
            end
            12'h304: mie_local <= csr_wdata[16];
            12'h305: mtvec <= {csr_wdata[31:2], 2'b00}; // direct mode
            12'h341: mepc <= {csr_wdata[31:2], 2'b00};
            12'h342: mcause <= csr_wdata;
            default: ; // mip is read-only; sourced from Timer STATUS.
        endcase
endmodule
