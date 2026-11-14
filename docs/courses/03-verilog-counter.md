# 第 03 課：第一個 Verilog 電路

[上一課：韌體與 GPIO](02-firmware-and-gpio.md) · [課程目錄](README.md) · [下一課：模擬與波形](04-testbench-and-waveforms.md)

## 這一課的目標

自己寫出以時脈驅動的計數器，理解暫存器、非阻塞賦值、重置與參數。先在 `learning/03/` 建立獨立模組，第 04 課驗證後再考慮上板；目前不要取代原專案的 LED 連線。

## 1. 用電路描述時間

假設時脈為 100 MHz，每個週期是 10 ns。如果每 50,000,000 個時脈切換一次 LED：

```text
切換間隔 = 50,000,000 / 100,000,000 = 0.5 秒
完整亮暗週期 = 2 × 0.5 = 1 秒
```

暫存器保存目前的計數值；每個時脈上升緣加一；到達設定值時歸零並切換 LED。比較器與加法器等邏輯在時脈邊緣之間計算，下一個上升緣再保存結果。

本專案原系統的 CPU／AXI 使用約 81.25 MHz 的 MIG UI 時脈。這一課的獨立範例使用板上 100 MHz；相同計數值接到不同頻率，會得到不同的閃爍速度。

## 2. 建立計數器

建立 `learning/03/blink_counter.v`：

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

本例要求 `COUNT_MAX >= 1`，課程測試使用 1、3 與 50,000,000 等正整數。這個參數以 Verilog `integer` 宣告，練習時維持在正的 32 bit signed 範圍內。

### 逐行理解

- `module` 定義電路的邊界與連接埠。
- `reg [31:0] count` 宣告 32 bit 變數；在這個時脈程序中使用時，會推導出保存狀態的暫存器。
- `always @(posedge clk)` 描述上升緣觸發的循序邏輯。
- `<=` 是非阻塞賦值。這個程序中的右側運算使用更新前的狀態，左側在該模擬時間的後續更新階段一起生效。
- `rst` 是同步、高有效重置：只有遇到上升緣時才清除狀態。
- 在一般加一分支沒有重新指定 `led`，因此 LED 暫存器保持原值。

`reg` 關鍵字本身不保證硬體一定是正反器；推導出的電路取決於使用它的程序與賦值方式。本例明確使用上升緣程序，所以是循序電路。

## 3. 為什麼比較 COUNT_MAX - 1？

把 `COUNT_MAX` 設為 3，解除重置後：

| 上升緣 | 邊緣前 count | 邊緣後 count | LED 是否切換 |
| --- | --- | --- | --- |
| 1 | 0 | 1 | 否 |
| 2 | 1 | 2 | 否 |
| 3 | 2 | 0 | 是 |
| 4 | 0 | 1 | 否 |

從 0 開始，0、1、2 共三個狀態。若比較值寫成 3，切換間隔就變成四個時脈。

## 4. 準備獨立上板用的頂層

完成第 04 課模擬後，可使用以下頂層。建立 `learning/03/blink_top.v`：

```verilog
`timescale 1ns/1ps
module blink_top (
    input  wire CLK100MHZ,
    input  wire CPU_RESETN,
    output wire [0:0] LED
);
    // 非同步進入重置，透過兩級暫存器依時脈解除重置。
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync;
    always @(posedge CLK100MHZ or negedge CPU_RESETN) begin
        if (!CPU_RESETN)
            reset_sync <= 2'b11;
        else
            reset_sync <= {reset_sync[0], 1'b0};
    end

    blink_counter #(.COUNT_MAX(50_000_000)) u_blink (
        .clk(CLK100MHZ),
        .rst(reset_sync[1]),
        .led(LED[0])
    );
endmodule
```

CPU_RESETN 是低有效、非同步的外部按鈕訊號。這裡先經過解除重置同步電路，再交給計數器。按鈕彈跳仍可能讓重置重複發生；本例的目標是可靠地回到已知狀態，沒有實作按鈕去彈跳功能。

不要把按鈕直接拿來當時脈，也先不要用計數器某一個 bit 建立另一個時脈域。這些需求通常可先用原本時脈加上 enable 條件處理。

## 5. 在獨立 Vivado 專案上板

第 04 課驗證通過後，再做這個延伸練習：

1. 建立新的 RTL project，例如 `build/learning/blink_hw`，選用原專案相同的 FPGA part。
2. 加入 `blink_counter.v` 與 `blink_top.v`，將 `blink_top` 設為 top。
3. 新增練習用 XDC，內容如下。此專案不需要加入 MicroBlaze、MIG 或原系統的 `.bd`。

```tcl
set_property -dict {PACKAGE_PIN E3 IOSTANDARD LVCMOS33} [get_ports CLK100MHZ]
create_clock -period 10.000 [get_ports CLK100MHZ]
set_property -dict {PACKAGE_PIN C12 IOSTANDARD LVCMOS33} [get_ports CPU_RESETN]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {LED[0]}]
```

4. 綜合、實作，檢查時序與 DRC，再產生 bitstream。
5. 在 Hardware Manager 選取這個獨立專案的 bitstream 下載；原本的 `scripts/program.tcl` 固定使用 `build/system.bit`，不會自動改抓練習產出。
6. 按下並放開 CPU RESET，讓計數器進入已知的初始狀態，再觀察切換間隔。

預期 LED 約每 0.5 秒切換一次。這次沒有 CPU 執行 `delay()`，是計數器電路依時脈改變狀態。

## 練習與自我檢查

1. 畫出 `COUNT_MAX = 4` 的前八個上升緣，標出 count 與 LED。
2. 計算 100 MHz 下，每 0.25 秒切換一次所需的 `COUNT_MAX`。
3. 解釋「切換間隔」與「完整亮暗週期」為什麼差兩倍。
4. 說明本模組的同步重置與頂層解除重置同步器的分工。

參考答案：第 2 題為 25,000,000；完整週期為 0.5 秒。計數器只會在上升緣取樣同步重置；頂層則處理外部重置訊號的進入與解除。

## 驗收標準

能根據時脈計算計數值、手算小參數的時序表，並解釋非阻塞賦值如何使用更新前的狀態。下一課先完成自動檢查，再進行本課的獨立上板練習。
