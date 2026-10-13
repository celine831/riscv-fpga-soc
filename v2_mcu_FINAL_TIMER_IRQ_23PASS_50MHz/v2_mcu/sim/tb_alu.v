`timescale 1ns/1ps
module tb_alu;
reg [31:0] a,b;
reg [2:0] alu_op;
wire [31:0] result;
integer checks=0;
integer errors=0;
alu dut(.a(a),.b(b),.alu_op(alu_op),.result(result));
task check_op;
    input [2:0] op;
    input [31:0] av,bv,expected;
    begin
        a=av; b=bv; alu_op=op; #1;
        checks=checks+1;
        if(result !== expected)
        begin
            errors=errors+1;
            $display("[FAIL] ALU op=%d actual=%h expected=%h",op,result,expected);
        end
    end
endtask
initial
begin
    check_op(0,10,3,13);
    check_op(1,10,3,7);
    check_op(2,10,3,2);
    check_op(3,10,3,11);
    check_op(4,10,3,9);
    check_op(0,32'hFFFFFFFF,1,0);
    check_op(1,0,1,32'hFFFFFFFF);
    check_op(2,32'hAAAAAAAA,32'h55555555,0);
    check_op(3,32'hAAAAAAAA,32'h55555555,32'hFFFFFFFF);
    check_op(4,32'hAAAAAAAA,32'hAAAAAAAA,0);
    check_op(0,1,2,3);
    check_op(5,1,2,0);
    check_op(0,1,2,3);
    check_op(6,1,2,0);
    check_op(0,1,2,3);
    check_op(7,1,2,0);
    if(errors==0) $display("tb_alu PASS: checks=%0d",checks);
    else $display("tb_alu FAIL: checks=%0d errors=%0d",checks,errors);
    $finish;
end
endmodule
