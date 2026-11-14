# 19：故意寫錯，確認測試能抓到

[上一節](18-simulation-clock.md) · [小單元目錄](README.md) · [下一節](20-results-and-progress.md)

## 這節只學一件事

用一個已知錯誤，確認 testbench 真正檢查了目標行為。

先確認正確版本出現：

```text
PASS: blink interval and mid-run reset
```

接著暫時將 DUT 的條件改成：

```verilog
count == COUNT_MAX
```

COUNT_MAX = 3、從 0 開始時：

| 上升緣 | 判斷前 count | 修改後的結果 |
| --- | --- | --- |
| 1 | 0 | 加到 1 |
| 2 | 1 | 加到 2 |
| 3 | 2 | 加到 3，LED 不變 |
| 4 | 3 | 歸零並切換 LED |

切換間隔變成四個時脈，比正確的三個多一個。testbench 仍預期第三個時脈就切換，因此應抓到：

```text
Fatal: Wrong LED at cycle 3
```

## 還原也要驗證

把條件恢復為 `count == COUNT_MAX - 1`，重新執行，確認再次得到 PASS。

```text
正確版本 PASS → 故意改錯 FAIL → 還原後 PASS
```

本次教學已實際完成此循環：錯誤版本在 46 ns、cycle 3 被抓到；還原版本在 186 ns 完成檢查。

## 練習

為什麼修改後不是每兩個週期切換？

<details>
<summary>查看答案</summary>

門檻從 2 增加到 3，多等待一個狀態。0、1、2、3 共四個狀態，所以切換間隔增加為四個週期。

</details>

## 過關標準

能先預測失敗的位置，實際觀察它，再還原並重新通過測試。上板前保留正確版本。
