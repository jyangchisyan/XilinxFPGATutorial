# 09：為什麼比較 COUNT_MAX - 1？

[上一節](08-count-and-interval.md) · [小單元目錄](README.md) · [下一節](10-clock-edges.md)

## 這節只學一件事

計數從 0 開始，0 到 N−1 一共有 N 個狀態。

假設每三個有效上升緣切換一次 LED，重置後 `count = 0`：

| 第幾個上升緣 | 判斷前 count | 更新後 count | LED |
| --- | --- | --- | --- |
| 1 | 0 | 1 | 保持 |
| 2 | 1 | 2 | 保持 |
| 3 | 2 | 0 | 切換 |

對應程式：

```verilog
if (count == COUNT_MAX - 1) begin
    count <= 0;
    led   <= ~led;
end else begin
    count <= count + 1;
end
```

這裡的片段放在上升緣觸發的程序中，且 `COUNT_MAX` 必須為正整數。完整模組見第 16 小節。

`COUNT_MAX = 3` 時，比較值是 2；`COUNT_MAX = 4` 時，比較值是 3。

## 練習

要每 5 個有效上升緣切換一次，`COUNT_MAX` 與實際比較值分別是多少？

<details>
<summary>查看答案</summary>

`COUNT_MAX = 5`，比較 `count == 4`。狀態 0、1、2、3、4 共五個。

</details>

## 過關標準

能先列出小數值的狀態序列，再確認門檻，避免只背減一公式。
