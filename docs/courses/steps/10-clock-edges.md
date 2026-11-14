# 10：暫存器何時改變？

[上一節](09-count-from-zero.md) · [小單元目錄](README.md) · [下一節](11-synchronous-reset.md)

## 這節只學一件事

上升緣觸發的暫存器，只有在對應的時脈事件才更新狀態。

```verilog
always @(posedge clk) begin
    count <= count + 1;
end
```

`posedge clk` 表示 clk 從 0 變成 1。假設 count 已初始化為 5：

```text
上升緣 A        兩個上升緣之間         上升緣 B
count 更新成 6 → 保持 6              → 更新成 7
```

在兩個上升緣之間，加法器等組合邏輯可以計算下一個值；count 暫存器仍保存原本狀態，等到下一個上升緣才更新。

## 練習

假設 `count = 8`，期間沒有重置，而且還沒到門檻：

1. clk 的下降緣會讓 count 加一嗎？
2. 下一個上升緣後 count 是多少？

<details>
<summary>查看答案</summary>

1. 不會。這個程序只由 `posedge clk` 觸發。
2. 9。

</details>

## 過關標準

能區分「組合邏輯正在計算」與「暫存器已保存新值」，並知道要觀察哪個時脈邊緣。
