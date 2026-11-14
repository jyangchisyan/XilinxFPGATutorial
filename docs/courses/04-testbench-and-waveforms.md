# 第 04 課：用模擬與波形驗證電路

[上一課：Verilog 計數器](03-verilog-counter.md) · [課程目錄](README.md) · [下一課：CPU 控制自訂硬體](05-axi-and-custom-logic.md)

## 這一課的目標

對第 03 課的計數器建立 testbench，自動檢查切換間隔與運作中的重置行為。這是獨立小模組測試，不需要 DDR2 model 或 MicroBlaze 韌體。

## 1. Testbench 的角色

待測電路稱為 DUT（Device Under Test）。Testbench 提供時脈、重置與其他輸入，再把輸出與預期值比較。

課程中的 `#5`、`initial` 時脈產生器與 `$fatal` 等寫法用於模擬；不要把這段 testbench 當成要放進 FPGA 的 RTL。

模擬不必真的等半秒才看一次 LED。使用參數把 `COUNT_MAX` 設為 3，可以在少量時脈內檢查同一個計數規則。

## 2. 建立自動檢查

先建立第 03 課的 `learning/03/blink_counter.v`，再建立 `learning/04/tb_blink_counter.sv`：

```systemverilog
`timescale 1ns/1ps
module tb_blink_counter;
    reg clk = 0;
    reg rst = 1;
    wire led;
    integer cycle;
    integer expected;

    always #5 clk = ~clk;

    blink_counter #(.COUNT_MAX(3)) dut (
        .clk(clk), .rst(rst), .led(led)
    );

    initial begin
        repeat (2) @(negedge clk);
        if (led !== 1'b0)
            $fatal(1, "Reset did not clear LED");
        rst = 0;

        for (cycle = 1; cycle <= 12; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            expected = (cycle / 3) % 2;
            if (led !== expected[0])
                $fatal(1, "Wrong LED at cycle %0d", cycle);
        end

        // 先執行一個未完成的計數，再於運作中重置。
        @(posedge clk);
        #1;
        @(negedge clk);
        rst = 1;
        @(posedge clk);
        #1;
        if (led !== 1'b0 || dut.count !== 32'd0)
            $fatal(1, "Mid-run reset did not clear state");

        @(negedge clk);
        rst = 0;
        for (cycle = 1; cycle <= 3; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            expected = (cycle == 3);
            if (led !== expected[0])
                $fatal(1, "Wrong restart interval at cycle %0d", cycle);
        end

        $display("PASS: blink interval and mid-run reset");
        $finish;
    end

    initial begin
        #1000;
        $fatal(1, "Simulation timeout");
    end
endmodule
```

### 為什麼在上升緣後等待 #1？

DUT 使用非阻塞賦值。Testbench 如果在同一個上升緣立刻檢查，有可能讀到更新前的值。這個簡單範例等 1 ns，讓輸出更新後才比較；它是在處理 testbench 的取樣時機，沒有描述硬體延遲。

### 為什麼使用 !==？

`!==` 會把 X（未知）與 Z（高阻抗）當作明確可比較的值，讓未知輸出也能觸發失敗。重置前的狀態未必已知；重置完成後，testbench 要求輸出是已知的 0。

## 3. 用獨立 Vivado 專案執行

建立 `learning/04/simulate.tcl`：

```tcl
set root [file normalize [file join [file dirname [info script]] ../..]]
create_project -force blink_sim $root/build/learning/blink_sim -part xc7a100tcsg324-1
add_files -norecurse $root/learning/03/blink_counter.v
add_files -fileset sim_1 -norecurse $root/learning/04/tb_blink_counter.sv
set_property top tb_blink_counter [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
launch_simulation
run all
close_sim
close_project
```

從根目錄執行：

```bash
mkdir -p build
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source learning/04/simulate.tcl -log build/learning_sim.log -journal build/learning_sim.jou
```

在 log 中確認出現 `PASS: blink interval and mid-run reset`，且沒有 `$fatal`、編譯或 elaboration 錯誤。不要只憑程序退出碼判定模擬通過。

若要看波形，可在 Vivado GUI 的 Simulation 中開啟這個練習專案，加入 `clk`、`rst`、`dut.count`、`led`，再重新執行。

## 4. 先做一次失敗實驗

把 DUT 的比較條件由 `COUNT_MAX - 1` 改成 `COUNT_MAX`，重新模擬。

預期：第三個有效上升緣時 LED 還沒有切換，testbench 應報錯。這證明檢查能抓到你想避免的 off-by-one 錯誤。觀察後還原條件，再確認 PASS。

## 5. 與原專案系統模擬的差異

| 測試 | 範圍 | 主要用途 |
| --- | --- | --- |
| 本課計數器 testbench | 一個小 RTL 模組 | 精確檢查週期與重置 |
| [system_tb.sv](../../sim/system_tb.sv) | CPU、BRAM、DDR2 model、GPIO | 驗證開機、記憶體測試與重啟流程 |

原專案的受管執行環境曾在啟動 XSim 時回報 `unexpected exception when evaluating tcl command`，最小測試也有相同現象。如果這個練習也在啟動階段失敗，先於可正常使用 XSim 的主機終端機重跑。模擬器未啟動與 testbench 檢查失敗，需要分開判讀。

### 互動課程的實際結果

使用者已在主機終端機執行本課 testbench：正確版本於 186 ns 回報 PASS；比較條件改成 `COUNT_MAX` 時，於 46 ns 回報 `Wrong LED at cycle 3`；還原後於 186 ns 再次 PASS。這項結果驗證小計數器的目前測試範圍，不代表 CPU／DDR2 的完整系統模擬也已通過。

## 練習與自我檢查

1. 把參數與預期值一起改成 4，執行至少三次切換。
2. 使用 `COUNT_MAX = 1`，預測每個有效上升緣都會切換 LED，再修改 testbench 檢查。
3. 在計數途中加入重置，確認解除後重新計滿所需的時脈。
4. 記下故意寫錯比較條件後，第一次失敗的 cycle 與波形。

## 驗收標準

正確電路得到 PASS；刻意製造的 off-by-one 錯誤得到失敗；能從波形指出「取樣前的狀態、上升緣、更新後的輸出」。完成後，可回到第 03 課進行獨立上板練習。
