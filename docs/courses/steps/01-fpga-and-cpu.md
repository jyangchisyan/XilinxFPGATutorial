# 01：FPGA 裡的 CPU 與周邊

[小單元目錄](README.md) · [下一節](02-address-and-data.md)

## 這節只學一件事

看懂目前 LED 閃爍是哪些元件共同完成的。

FPGA 內建立了 MicroBlaze CPU、BRAM、AXI Interconnect、MIG 與 AXI GPIO。外部 DDR2 晶片位於板上，由 FPGA 內的 MIG 控制。

| 元件 | 在本專案的工作 |
| --- | --- |
| MicroBlaze | 執行編譯後的 C 韌體 |
| BRAM | 保存指令、全域變數與堆疊 |
| AXI Interconnect | 將 CPU 的交易送到對應裝置 |
| MIG | 初始化、校準並存取 DDR2 |
| AXI GPIO | 保存輸出值，驅動 LED 訊號 |

目前控制 LED 的路徑是：

```text
MicroBlaze → AXI Interconnect → AXI GPIO → LED[0]
```

CPU 執行 `GPIO_DATA = 1` 時會發出寫入交易。GPIO 接受交易後更新輸出，LED 因而改變。

## 練習

如果 CPU 想讓 LED 熄滅，哪個元件最後把數值變成接到 LED 的輸出訊號？

<details>
<summary>查看答案</summary>

AXI GPIO。MicroBlaze 負責執行程式與發出交易，GPIO 負責保存輸出值並驅動訊號。

</details>

## 過關標準

能說出 CPU 到 LED 的路徑，並指出這個版本的閃爍節奏由 CPU 執行韌體產生。
