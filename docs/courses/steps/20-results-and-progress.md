# 20：判讀 log，整理目前的學習成果

[上一節](19-off-by-one-experiment.md) · [小單元目錄](README.md)

## 這節只學一件事

把「工具完成某一步」與「檢查的行為通過」分開判讀。

## 一份成功的模擬 log

本次主機終端機回報：

```text
XSim simulation ran for 0ns
# run all
PASS: blink interval and mid-run reset
$finish called at time : 186 ns
```

| 訊息 | 意義 |
| --- | --- |
| snapshot loaded／ran for 0ns | 模擬映像已載入，最初還沒有推進時間 |
| `run all` | 開始執行，直到結束條件 |
| PASS 訊息 | 程式已走完目前 testbench 的檢查 |
| `$finish` | 結束模擬；還要看它之前有沒有 Fatal 或其他錯誤 |

錯誤實驗同樣會出現 `$finish`，但前面有 `Fatal: Wrong LED at cycle 3`。因此不能只看最後「Simulation closed」就判斷通過。

## 目前有證據支持的結果

- 原系統上板後 LED 規律閃爍，通過目前韌體的 DDR2 前 4 KiB 測試與 GPIO 路徑。
- 將成功路徑的兩個 delay 減半，重新建置、下載後，使用者確認實際節奏變化正確。
- 獨立計數器 testbench 在主機 XSim 執行通過。
- 故意製造 off-by-one 錯誤時，在第 3 個有效週期失敗；還原後再次通過。

## 目前尚未完成的部分

- `blink_counter` 的獨立頂層整合與上板，尚未完成驗證。
- AXI 可設定計數器的延伸設計，尚未實作到原系統。
- 完整 128 MiB DDR2 與長時間穩定性，尚未驗證。
- 不能用小計數器模擬成功，推論包含 CPU／DDR2 的完整系統模擬也已通過。

## 學習紀錄

| 觀念 | 回顧重點 |
| --- | --- |
| BRAM／DDR2 | BRAM 保存指令，DDR2 保存本課被測試的資料 |
| 同步重置 | 等上升緣取樣 rst，短脈衝可能被漏掉 |
| 非阻塞賦值 | 先讀舊值，安排新值 |
| 計數門檻 | 從 0 到 N−1 共 N 個狀態 |
| 頻率／週期 | 互為倒數，時脈反轉間隔是半週期 |
| 實例接線 | `.led(LED[0])`：led 是子模組接腳，LED[0] 是本層訊號 |

## 下一步

先用第 15 小節的例子，說清楚括號前後各代表誰，再回到 [第 03 課的獨立頂層](../03-verilog-counter.md)，準備把板上時脈、整理過的重置訊號與 LED 接到計數器。

本節之後再進行頂層整合。先保留已通過模擬的原始碼，並記錄新實作的預測與結果。
