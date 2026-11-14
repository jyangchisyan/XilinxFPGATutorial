# 15：讀懂 .led(LED[0])

[上一節](14-module-ports.md) · [小單元目錄](README.md) · [下一節](16-complete-counter.md)

## 這節只學一件事

命名式接線的格式是：

```verilog
.模組接腳名稱(這一層的訊號名稱)
```

例如在頂層放入一個計數器實例：

```verilog
blink_counter u_blink (
    .clk(CLK100MHZ),
    .rst(reset),
    .led(LED[0])
);
```

這是接線片段，需要放在有宣告對應訊號的頂層中。完整頂層與按鈕重置處理見 [第 03 課](../03-verilog-counter.md)。

| 寫法 | 子模組接腳 | 這一層訊號 |
| --- | --- | --- |
| `.clk(CLK100MHZ)` | clk | CLK100MHZ |
| `.rst(reset)` | rst | reset |
| `.led(LED[0])` | led | LED 向量的第 0 bit |

**點號後、括號前是子模組接腳；括號裡是外部連接的訊號。** 因此在 `.led(LED[0])` 中，`blink_counter` 內的接腳是小寫 `led`。

`blink_counter` 是模組種類；`u_blink` 是這一個實例的名字。Verilog 區分大小寫，`led` 與 `LED` 是不同識別字。

## 接線還需要腳位約束

頂層的 `LED[0]` 還需要 XDC，才能對應到實際 FPGA 腳位。本專案使用 H17。module 接線與封裝腳位配置是兩個不同層次。

## 練習

如果另一個模組的接腳叫 `out_bit`，頂層的訊號叫 `status_led`，應寫成哪個？

```text
A. .out_bit(status_led)
B. .status_led(out_bit)
```

<details>
<summary>查看答案</summary>

A。括號前是被放進來的模組接腳 `out_bit`，括號裡是本層的 `status_led`。

</details>

## 過關標準

看到 `.名稱(訊號)`，能明確分出內外兩側，不會因為 LED[0] 比較像板上元件就把它當成子模組接腳。
