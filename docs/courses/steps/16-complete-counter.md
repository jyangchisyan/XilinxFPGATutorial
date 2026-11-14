# 16：把核心規則組成完整模組

[上一節](15-instance-connections.md) · [小單元目錄](README.md) · [下一節](17-testbench-structure.md)

## 這節只學一件事

將參數、接腳、狀態與更新規則組成可編譯的模組。

練習檔案是 `learning/03/blink_counter.v`：

```verilog
`timescale 1ns/1ps

module blink_counter #(
    parameter integer COUNT_MAX = 50_000_000
) (
    input  wire clk,
    input  wire rst,
    output reg  led
);
    reg [31:0] count;

    always @(posedge clk) begin
        if (rst) begin
            count <= 32'd0;
            led   <= 1'b0;
        end else if (count == COUNT_MAX - 1) begin
            count <= 32'd0;
            led   <= ~led;
        end else begin
            count <= count + 32'd1;
        end
    end
endmodule
```

本練習要求 COUNT_MAX 為正整數，且維持在正的 32 bit signed integer 範圍內。

## 由外而內閱讀

1. `parameter`：預設每 50,000,000 個有效上升緣切換。
2. 接腳：clk、rst 進入，led 輸出。
3. `count`：保存目前進度。
4. `always`：每個上升緣執行一次狀態更新。
5. 優先序：重置 → 到達門檻 → 一般加一。

一般加一的分支沒有指定 led，所以該暫存器保持原值。這個上升緣程序會推導出循序電路；`reg` 關鍵字本身仍要配合使用方式理解。

## 練習

同一個上升緣，rst = 1 且 count 剛好等於門檻，led 原本為 0。結果會是重置的 0，還是切換的 1？

<details>
<summary>查看答案</summary>

led 為 0、count 為 0。第一個 `if (rst)` 成立，後面的 `else if` 不會再執行。

</details>

## 過關標準

能說明每一部分的用途，以及同時出現多個條件時，哪一個分支優先。
