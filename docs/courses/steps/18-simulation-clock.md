# 18：always #5 的完整週期是多少？

[上一節](17-testbench-structure.md) · [小單元目錄](README.md) · [下一節](19-off-by-one-experiment.md)

## 這節只學一件事

一次反轉是半個週期，反轉兩次才完成一個時脈週期。

```verilog
`timescale 1ns/1ps
reg clk = 0;
always #5 clk = ~clk;
```

在這個 timescale 下，`#5` 是 5 ns。clk 由 0 變 1，再由 1 回到 0，經過 10 ns，所以頻率是 100 MHz。

| 反轉間隔 | 完整週期 | 頻率 |
| --- | --- | --- |
| `#10` | 20 ns | 50 MHz |
| `#5` | 10 ns | 100 MHz |
| `#2.5` | 5 ns | 200 MHz |

1 ns 是時間單位，1 ps 是時間精度，所以可以表示 2.5 ns 的延遲。這個 `always #...` 寫在 testbench 中，用來產生模擬時脈；上板時的時脈來自實際振盪器或 FPGA 時脈電路。

## 與計數器接起來

200 MHz 對應每個週期 5 ns。COUNT_MAX = 3 時，切換間隔為 `3 × 5 = 15 ns`，完整 LED 亮暗週期為 30 ns。

## 練習

1. `always #4 clk = ~clk` 的完整週期與頻率是多少？
2. 在這個時脈下，每四個週期切換一次 LED，切換間隔是多少？

<details>
<summary>查看答案</summary>

1. 8 ns、125 MHz。
2. `4 × 8 = 32 ns`。完整 LED 週期為 64 ns。

</details>

## 過關標準

能先把反轉間隔乘二，算出完整時脈週期，再計算計數器的時間。
