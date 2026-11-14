# 14：認識 clk、rst、led 三個接腳

[上一節](13-compare-old-state.md) · [小單元目錄](README.md) · [下一節](15-instance-connections.md)

## 這節只學一件事

從 module 宣告找出訊號方向與用途。

```verilog
input  wire clk,
input  wire rst,
output reg  led
```

| 接腳 | 方向 | 本模組中的意義 |
| --- | --- | --- |
| `clk` | input | 接收時脈，上升緣觸發狀態更新 |
| `rst` | input | 接收高有效同步重置 |
| `led` | output | 輸出目前 LED 狀態 |

`input` 與 `output` 是相對於這個模組而言。clk 與 rst 由外部送進來；led 把模組內的結果送出去。

這些名稱需要配合程式內容理解。此處 clk 被用於 `posedge clk`，rst 被用於 `if (rst)`；不能只靠名字就假設所有模組都使用相同邊緣或極性。

## 變數寬度

```verilog
reg [31:0] count;
```

位元編號從 31 到 0，共 32 bit。`32'd1` 表示以 32 bit 表示十進位的 1；`1'b0` 表示 1 bit 的二進位 0。

## 練習

1. 板上的時脈應該連到 clk 還是 rst？
2. 哪個接腳把 LED 狀態送出模組？

<details>
<summary>查看答案</summary>

1. clk。
2. led。

</details>

## 過關標準

能指出三個接腳的方向與用途，並區分接腳名稱、訊號寬度與訊號值。
