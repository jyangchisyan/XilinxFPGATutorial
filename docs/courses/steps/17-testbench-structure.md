# 17：Testbench 如何測試計數器？

[上一節](16-complete-counter.md) · [小單元目錄](README.md) · [下一節](18-simulation-clock.md)

## 這節只學一件事

Testbench 提供輸入，再檢查 DUT 的輸出是否符合預測。

```text
Testbench 產生 clk、rst → DUT：blink_counter → led → 自動比較
```

這次使用 `learning/04/tb_blink_counter.sv`，完整程式與執行腳本見 [第 04 課](../04-testbench-and-waveforms.md)。

待測模組的實例名稱是 `dut`，測試時覆寫參數：

```verilog
blink_counter #(.COUNT_MAX(3)) dut (
    .clk(clk), .rst(rst), .led(led)
);
```

把預設 50,000,000 改成 3，只用少量時脈就能檢查相同的規則。這個參數覆寫只作用在這個實例，不會修改模組檔的預設值。

## 這個 testbench 檢查三件事

1. 重置後，LED 為 0。
2. 正常運作時，每三個有效上升緣切換一次。
3. 運作中重置會清除狀態，解除後重新計滿三個週期。

檢查放在上升緣後 `#1`，讓非阻塞賦值的更新先生效，再讀取輸出。這是模擬取樣安排，不代表硬體有固定 1 ns 延遲。

比較時使用 `!==`，讓未知值 X 與高阻抗 Z 也能造成失敗。

## 練習

如果要檢查「每四個週期切換」，只把 DUT 的 COUNT_MAX 改成 4、保留原本每三個週期的預期值，測試會通過嗎？

<details>
<summary>查看答案</summary>

不會。DUT 的設定與 testbench 的預期必須對應；改成另一個正確規格時，也要同步修改預期結果。

</details>

## 過關標準

能區分 DUT、測試輸入、預期結果與檢查邏輯。知道通過測試所支持的行為範圍。
