# 13：條件判斷也使用當前舊狀態

[上一節](12-nonblocking-assignment.md) · [小單元目錄](README.md) · [下一節](14-module-ports.md)

## 這節只學一件事

這個上升緣要走哪個分支，依據的是更新前的 count。

```verilog
if (count == COUNT_MAX - 1) begin
    count <= 0;
    led   <= ~led;
end else begin
    count <= count + 1;
end
```

設 `COUNT_MAX = 4`、rst = 0：

| 更新前 count／led | 比較 `count == 3` | 更新後 count／led |
| --- | --- | --- |
| 2／0 | 不成立 | 3／0 |
| 3／0 | 成立 | 0／1 |
| 3／1 | 成立 | 0／0 |

count 從 2 加到 3 的這個上升緣，不會再立刻回頭判斷一次並切換 LED。要到下一個上升緣，才使用新狀態做下一次判斷。

## 常見混淆

如果原本 count = 2，回答「count = 0、led = 1」，其實跨過了兩個上升緣。請每次只推進一個上升緣，寫出一次更新後的結果。

## 練習

`COUNT_MAX = 4`，重置剛解除時 count = 0、led = 0。依序填出接下來四個上升緣後的 count／led。

<details>
<summary>查看答案</summary>

1／0 → 2／0 → 3／0 → 0／1。

</details>

## 過關標準

手算時每列只代表一個上升緣，不把「加一後到達門檻」與「下一次看到門檻並切換」合併。
