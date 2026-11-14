# 第 06 課：DDR2、重置與時序

[上一課：CPU 控制自訂硬體](05-axi-and-custom-logic.md) · [課程目錄](README.md)

## 這一課的目標

理解 MIG 為什麼需要校準、CPU 為什麼要等待 ready、不同時脈域如何互動，以及如何閱讀 setup／hold 報告。完成後能把「LED 不亮」拆成可逐步檢查的問題。

## 1. 為什麼 DDR2 需要專用控制器？

外部 DDR2 透過資料線、位址／命令線與 DQS 等訊號傳輸資料。記憶體的初始化順序、存取時序、更新與資料擷取相位，都需要控制器處理。

本專案的 MIG 提供 AXI 介面給系統使用。CPU 發出交易後，由 MIG 轉成 DDR2 命令與實體訊號；韌體不需要自己切換 DDR2 腳位。

本專案的設定：

| 項目 | 設定 |
| --- | --- |
| DDR2 容量 | 128 MiB |
| 外部資料寬度 | 16 bit |
| MIG AXI 資料寬度 | 128 bit |
| CPU 資料交易寬度 | 32 bit |
| 介面轉換 | AXI Interconnect 內的轉換模組 |
| CPU／AXI／GPIO 時脈 | MIG UI clock，約 81.25 MHz |

介面寬度、時脈頻率與每秒傳輸次數是不同概念。不能僅憑「16 bit DDR2」或「128 bit AXI」算出整個應用程式的有效頻寬；還有交易長度、協定、等待與 CPU 執行成本。

## 2. 讀懂時脈樹

```text
板上 100 MHz → BUFG ─────────────→ MIG sys_clk_i
                   └→ Clock Wizard → 200 MHz → MIG clk_ref_i

MIG 內部時脈電路 → DDR2 實體介面
                 → ui_clk → CPU、LMB、AXI、GPIO、Reset Controller
```

`sys_clk_i` 與 `clk_ref_i` 的用途不同，不能因為都叫 clock 就任意交換。

200 MHz 是 MIG 的參考時脈；CPU 使用 UI 時脈。CPU 的頻率應從實際設定與報告確認，而不是直接沿用板上振盪器或參考時脈的數字。

## 3. 重置順序決定系統能否開機

對照 [complete_system.tcl](../../scripts/complete_system.tcl) 的接線描述與實際 Block Design：

| 訊號 | 用途 |
| --- | --- |
| `CPU_RESETN` | 外部低有效重置輸入 |
| `clk_wiz_0/locked` | 參考時脈產生電路已鎖定 |
| `mig_7series_0/mmcm_locked` | MIG 內部對應的鎖定狀態 |
| `mig_7series_0/init_calib_complete` | DDR2 初始化／校準完成 |
| `mig_7series_0/ui_clk_sync_rst` | MIG UI 時脈域的高有效重置狀態 |
| `rst_ui/mb_reset` | MicroBlaze 的高有效重置 |
| `rst_ui/peripheral_aresetn` | 周邊的低有效重置 |

本專案以 `CPU_RESETN AND clk_wiz_locked` 驅動 MIG 的低有效系統重置，讓參考時脈鎖定前 MIG 維持重置。

CPU 的 Reset Controller 則等待 MIG 的鎖定與校準狀態，並監看 UI reset，最後在 UI 時脈域依序解除相關重置。

重要的依賴關係是：MIG 必須先能運作，才能完成校準。若反過來用「尚未校準」持續重置整個 MIG，就可能形成永遠無法完成校準的循環依賴。現有設計把 MIG 系統重置與 CPU ready 條件分開處理。

## 4. 時脈域與 CDC

同一時脈域中的暫存器共享時脈關係，可用時序分析檢查資料能否準時到達。訊號跨越不同時脈域時，還需要合適的 CDC（Clock Domain Crossing）設計。

- 單 bit、變化較慢的狀態，可依需求使用同步器。
- 短脈衝可能被接收端漏掉，需要脈衝延長、toggle 或握手等設計。
- 多 bit 資料要維持彼此一致，通常需要握手、穩定資料取樣機制或非同步 FIFO。

把 32 bit 設定值的每個 bit 分別接兩級同步器，不能保證接收端看到的是同一筆數值。第 05 課讓 GPIO 與自訂模組使用相同 UI 時脈，正是先避免這個額外問題。

本課不要求直接修改 MIG 或現成 IP 的內部 RTL。先學會找出訊號從哪個時脈域出發、由哪個時脈域接收，以及中間由誰負責同步。

## 5. Setup 與 hold 在檢查什麼？

一條常見路徑是：

```text
來源暫存器 Q → 組合邏輯與連線 → 目的暫存器 D
```

- Setup：在目的暫存器取樣前，資料需要提早穩定足夠時間。
- Hold：在取樣後，資料還需要繼續保持穩定足夠時間。
- Slack：相對於檢查要求的餘裕。負值代表對應檢查未滿足。

本專案既有一次完整實作的結果：

| 指標 | 結果 | 意義 |
| --- | --- | --- |
| WNS | +1.316 ns | 最差 setup slack 仍為正 |
| WHS | +0.066 ns | 最差 hold slack 仍為正 |
| WPWS | +0.206 ns | 最差 pulse-width slack 仍為正 |

這些是該次實作結果；改電路、約束或重新實作後，必須重新看報告。通過時序也不會自動證明演算法、重置順序、所有 CDC 或全部記憶體容量都正確。

## 6. 實際閱讀報告

原專案完整建置後，打開：

- `build/timing_summary.rpt`：先找 Design Timing Summary，再看最差路徑。
- `build/drc.rpt`：找每個規則的嚴重度、受影響物件與說明。
- `FPGAGetStartedAgain.runs/impl_1/`：查看實作過程與工具產生的其他報告。

這次建置沒有未定義時脈或未約束的內部 endpoints。外部 CPU reset 與 LED 沒有同步 I/O delay 規格，閱讀 check_timing 時要把這類外部介面情境與內部路徑分開理解。

本次 DRC 為 0 errors、5 warnings，包含設定電壓屬性未明確指定、LUT 配對與 MIG PLL buffer 類型等項目。閱讀警告時應確認來源與影響；不要單純降低嚴重度來取得看似乾淨的結果。設定電壓必須依實際板子與配置介面確認。

## 7. 把 LED 不亮拆成診斷步驟

| 觀察 | 下一步 |
| --- | --- |
| 連不到 hw_server | 檢查主機 TCP／服務與執行環境 |
| 有 USB target，但沒有 FPGA | 檢查電源與 JTAG chain |
| FPGA 下載／啟動未成功 | 查看 program log、檔案與設定狀態 |
| FPGA 啟動成功，LED 不亮 | 檢查時脈、校準、CPU reset 與韌體是否啟動 |
| LED 快閃兩下 | 原韌體已進入 DDR2 比對失敗路徑，讀取失敗變數 |
| LED 規律閃爍 | 原韌體已通過目前 4 KiB 測試與 GPIO 路徑 |

目前沒有把所有狀態接到外部 LED 或 ILA。若要直接觀察 `init_calib_complete`、`mb_reset` 等內部訊號，需要另外加入合適的觀察介面並重新建置；不能假設目前 Hardware Manager 已可直接讀到所有內部 net。

## 練習

1. 在 Block Design 標出 100 MHz、200 MHz、UI clock 的去向。
2. 畫出 MIG reset 與 CPU reset 的依賴圖，檢查是否有循環依賴。
3. 從 timing report 找出最差 setup 路徑的 startpoint、endpoint、時脈與 slack。
4. 對比「下載成功」「4 KiB 測試通過」「128 MiB 完整測試通過」各需要哪些證據。
5. 延伸練習：將原韌體測試改為 64 KiB，先計算 word 數、最後元素位址與測試範圍，再建置與驗證。記憶體測試會覆寫測試區域。

第 5 題參考答案：`TEST_WORDS = 16384`，最後一個 32 bit 元素位址為 `0x8000FFFC`，涵蓋 byte 範圍 `0x80000000–0x8000FFFF`。它仍然只涵蓋整個 DDR2 的一部分。

## 驗收標準

能指出原系統的時脈來源與重置解除條件，從報告判斷指定時序是否通過，並能依觀察結果選擇下一個診斷點。對每個「成功」結論，都能說出其驗證範圍。

## 六課完成後的下一個作品

把第 05 課延伸為 CPU 可控制的 PWM：先定義 period、duty 與 enable 的行為，對 0%、100%、中途更新與重置建立 testbench，再整合到系統與上板。這會把暫存器、RTL、模擬、AXI 介面與時序分析串成一個完整開發循環。
