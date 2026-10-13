`timescale 1ns/1ns

module tb_alu();

reg [31:0] a;
reg [31:0] b;
reg [2:0]  alu_op;
wire  [31:0] result;

initial
    begin
        /* a=32'd32;
        b=32'd45;
        alu_op=3'b0;
        #20
        alu_op=3'd1;
        #20
        alu_op=3'd2;      
        #20
        alu_op=3'd3;           
        #20 
        alu_op=3'd4;      
        #20;
        $stop;         // 暂停仿真，查看波形       */  
        // 1. 加法溢出：只保留低 32 位
        a = 32'hFFFFFFFF;
        b = 32'd1;
        alu_op = 3'd0;
        #20;
        if (result !== 32'h00000000)
            $display("FAIL: ADD overflow");
        
        // 2. 0 - 1：结果为全 1
        a = 32'd0;
        b = 32'd1;
        alu_op = 3'd1;
        #20;
        if (result !== 32'hFFFFFFFF)
            $display("FAIL: SUB negative");
        
        // 3. 互补位按位与
        a = 32'hAAAAAAAA;
        b = 32'h55555555;
        alu_op = 3'd2;
        #20;
        if (result !== 32'h00000000)
            $display("FAIL: AND");
        
        // 4. 互补位按位或，a、b 保持不变
        alu_op = 3'd3;
        #20;
        if (result !== 32'hFFFFFFFF)
            $display("FAIL: OR");
        
        // 5. 相同数据异或
        b = 32'hAAAAAAAA;
        alu_op = 3'd4;
        #20;
        if (result !== 32'h00000000)
            $display("FAIL: XOR");
        
        // 6. 检查三个未使用的操作码
        // 每次先产生非零结果，再切换到默认分支，检查是否清零
        a = 32'd1;
        b = 32'd2;
        
        alu_op = 3'd0;
        #20;
        alu_op = 3'd5;
        #20;
        if (result !== 32'h00000000)
            $display("FAIL: default op 5");
        
        alu_op = 3'd0;
        #20;
        alu_op = 3'd6;
        #20;
        if (result !== 32'h00000000)
            $display("FAIL: default op 6");
        
        alu_op = 3'd0;
        #20;
        alu_op = 3'd7;
        #20;
        if (result !== 32'h00000000)
            $display("FAIL: default op 7");
        
        $display("Boundary tests completed.");
        $stop;
    end

alu alu_inst (
    .a(a),
    .b(b),
    .alu_op(alu_op),
    .result(result)
);

endmodule