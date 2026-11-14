# 第 05 課：讓 CPU 控制自己寫的硬體

[上一課：模擬與波形](04-testbench-and-waveforms.md) · [課程目錄](README.md) · [下一課：DDR2 與時序](06-ddr-reset-and-timing.md)

## 這一課的目標

理解 AXI 交易與暫存器介面的分工，利用現有 AXI GPIO 把 CPU 寫入值交給自訂 RTL，做出「C 程式設定速度、硬體負責計數」的 LED。

本課是原專案的延伸設計，尚未套用到目前已上板的版本。請在獨立副本實作。

## 1. 先建立練習副本

從專案根目錄執行：

```bash
mkdir -p build/learning/05
cp FPGAGetStartedAgain.xpr build/learning/05/
cp -r FPGAGetStartedAgain.srcs firmware scripts constraints sim build/learning/05/
```

後續只修改這個副本。以 Vivado 開啟 `build/learning/05/FPGAGetStartedAgain.xpr`，確認 File Properties 中的來源都在副本之下。缺少 `.gen` 或舊 run 產物可重新產生。

完成修改後，從副本根目錄執行 `make -C firmware` 與 `scripts/build.tcl`。不要對已完成的系統重跑一次性遷移腳本 `complete_system.tcl`。

## 2. CPU 的一次寫入包含什麼？

```c
GPIO_DATA = 1;
```

這行 C 會形成記憶體映射寫入。AXI Interconnect 解碼位址，將交易送到 AXI GPIO；GPIO 完成寫入後，其輸出暫存器改變，進而控制外部訊號。

AXI 的五個 channel：

| Channel | 工作 |
| --- | --- |
| AW | 寫入位址 |
| W | 寫入資料與 byte strobes |
| B | 寫入回應 |
| AR | 讀取位址 |
| R | 讀取資料與回應 |

某個 channel 的交易在上升緣時，同時看到 `VALID = 1` 與 `READY = 1` 才算接受。送出端在 `VALID = 1` 且尚未被接受時，要保持該筆 payload 穩定。

AW 與 W 是獨立 channel，可能在不同時脈被接受。自行寫 AXI slave 時，如果假設位址與資料永遠同時到達，很容易在 backpressure 下出錯。本課先由現有 AXI GPIO 負責完整協定，讓你專注在軟體與自訂電路的界面。

## 3. 定義軟硬體契約

將現有 `axi_gpio_0` 改成雙 channel：

| 暫存器 | 位址 | 硬體意義 |
| --- | --- | --- |
| Channel 1 DATA | `0x40000000` | bit 0：enable，0 時 LED 與計數器清零 |
| Channel 2 DATA | `0x40000008` | 32 bit：每次切換所需的 UI 時脈數，0 視為 1 |

GPIO 內的 TRI 暫存器分別在 offset `0x04` 與 `0x0C`。本練習把兩個 channel 都設為固定輸出，不需要用韌體設定方向。

在 GPIO 設定中啟用 Dual Channel，保留 channel 1 寬度 1 且 All Outputs，將 channel 2 設為寬度 32 且 All Outputs。對應參數為 `C_IS_DUAL`、`C_GPIO_WIDTH`、`C_GPIO2_WIDTH`、`C_ALL_OUTPUTS` 與 `C_ALL_OUTPUTS_2`。

## 4. 建立可設定的計數器

在副本中建立 `rtl/programmable_blink.v`：

```verilog
`timescale 1ns/1ps
module programmable_blink (
    input  wire        clk,
    input  wire        rst,
    input  wire        enable,
    input  wire [31:0] period_cycles,
    output reg         led
);
    reg [31:0] count;
    wire [31:0] limit = (period_cycles == 32'd0)
                      ? 32'd1 : period_cycles;

    always @(posedge clk) begin
        if (rst || !enable) begin
            count <= 32'd0;
            led   <= 1'b0;
        end else if (count >= limit - 32'd1) begin
            count <= 32'd0;
            led   <= ~led;
        end else begin
            count <= count + 32'd1;
        end
    end
endmodule
```

使用 `>=`，讓執行途中將 period 調小時，即使 count 已超過新門檻，也能在下一個上升緣切換並重新計數。

這個版本直接使用目前 period，因此修改時可能縮短或延長正在進行的半週期。若需求是不打斷目前週期，可以再增加一個暫存器，只在週期邊界載入新設定，並為該行為建立測試。

## 5. 在 Block Design 加入 Module Reference

把 RTL 檔加入副本的 Design Sources，再用 Add Module 將 `programmable_blink` 放入 Block Design，依下表接線：

| 自訂模組訊號 | 連接來源／去向 |
| --- | --- |
| `clk` | `mig_7series_0/ui_clk` |
| `rst` | `rst_ui/peripheral_reset`，高有效 |
| `enable` | `axi_gpio_0/gpio_io_o`，channel 1 |
| `period_cycles` | `axi_gpio_0/gpio2_io_o`，channel 2 |
| `led` | 外部 `LED[0]` |

先移除原本 GPIO 直接連到 LED 的 net，再依表格重接。LED 只能有一個輸出驅動來源。外部 LED 的 H17 腳位約束保持不變。

此時 GPIO、自訂電路與 CPU 使用同一個 UI 時脈。若把自訂電路改接到板上 100 MHz，就形成新的跨時脈域問題，32 bit period 不能直接套用單 bit 同步器處理；相關原則見下一課。

儲存並執行 Validate Design。原本 `0x40000000` 的 GPIO 位址視窗保持不變，新增 channel 的 offset 位於同一個視窗內。

## 6. 修改成功路徑的 C 程式

在副本的 `firmware/main.c` 增加：

```c
#define GPIO_PERIOD (*(volatile uint32_t *)0x40000008u)
```

保留 DDR2 測試。在 `test_status = 2;` 後，把原本的成功閃爍迴圈替換成：

```c
GPIO_DATA = 0;            /* 調整前先停用並歸零 */
GPIO_PERIOD = 40625000u;  /* UI clock 約 81.25 MHz，切換間隔約 0.5 秒 */
GPIO_DATA = 1;
for (;;) {
    __asm__ volatile ("nop");
}
```

CPU 設定一次後，硬體就會持續計數。這個迴圈本身沒有切換 GPIO。

GPIO channel 1 的意義現在變成 enable，因此舊的失敗快閃程式不再對應原本的直接 LED 輸出。請把失敗路徑改為 `GPIO_DATA = 0;` 後停在無限迴圈；失敗細節仍可由 `test_status` 與其他除錯變數讀取。成功／失敗顯示規則有改變，要同步記錄。

## 7. 驗證順序

1. 先參照第 04 課，對自訂模組測試 reset、enable、period = 0、period = 1，以及運作中修改 period。
2. 執行 Block Design 驗證，確認沒有多重驅動、未接的必要輸入或不一致時脈。
3. 從副本根目錄編譯韌體、建置硬體、檢查時序與 DRC，再下載副本產生的 bitstream。
4. 改 period 後重做建置與下載，比較實際切換間隔。

穩定設定下，完整 LED 週期約為 `2 × period_cycles / f_ui`。實際 UI 頻率可由 Clock Report 查到，不應永遠假設精確等於 81.25 MHz。

## 練習與驗收標準

- 能說明 VALID／READY 的接受條件，以及 AW、W 獨立的意義。
- 能從 C 位址追到 GPIO channel，再追到自己的 RTL 輸入。
- 模擬確認 enable = 0 會清零，period = 0 被視為 1，調小 period 不會等待 counter 溢位。
- 上板後，CPU 停在空迴圈時 LED 仍依硬體計數器切換。

下一階段可把 GPIO 橋接改成自訂 AXI4-Lite IP；到那時再加入位址／資料分開接受、byte strobes、回應與 backpressure 的完整測試。
