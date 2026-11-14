# 第 01 課：讀懂 FPGA 系統與開機流程

[課程目錄](README.md) · [下一課：用 C 程式操作 GPIO](02-firmware-and-gpio.md)

## 這一課的目標

讀完後，你應該能指出 FPGA、MicroBlaze、BRAM、DDR2、AXI 與 GPIO 的分工，並解釋從載入 bitstream 到 LED 閃爍的過程。本課只需閱讀，不必重新建置或下載。

## 1. FPGA 裡面建立了哪些東西？

FPGA 有可設定的邏輯資源與連線。這個專案透過 Vivado IP Integrator，把現成 IP 組成一個可執行 C 程式的系統。

| 名稱 | 在本專案中的工作 |
| --- | --- |
| LUT | 實現組合邏輯，例如條件判斷、位址解碼 |
| Flip-flop，正反器 | 在時脈邊緣保存狀態，例如計數器目前的數值 |
| BRAM | FPGA 內部的記憶體，本專案配置為 64 KiB |
| MicroBlaze | 由 FPGA 邏輯實現的 CPU，執行編譯後的韌體 |
| MIG | 控制外部 DDR2，處理初始化、校準與記憶體交易 |
| AXI Interconnect | 把 CPU 的存取導向對應的周邊，並進行必要的介面轉換 |
| AXI GPIO | 把 CPU 寫入的暫存器資料轉為輸出訊號 |

目前 LED 的節奏由 MicroBlaze 執行 C 程式產生；FPGA 同時提供 CPU、記憶體控制器與 GPIO 等電路。第 03 課會自己寫一個直接依時脈計數的電路。

## 2. 先畫出兩條路徑

程式取指與 BRAM 資料存取：

```text
MicroBlaze ILMB → Instruction LMB Controller → BRAM Port A
MicroBlaze DLMB → Data LMB Controller        → BRAM Port B
```

外部記憶體與周邊存取：

```text
MicroBlaze M_AXI_DP → AXI Interconnect → MIG      → DDR2
                                      → AXI GPIO → LED[0]
```

ILMB 與 DLMB 分別服務指令與資料，透過兩個控制器連到同一塊雙埠 BRAM。此處的 DDR2 僅映射到 CPU 資料空間；目前韌體的指令、全域變數與堆疊都放在 BRAM。

## 3. bitstream、ELF、XSA 各是什麼？

| 檔案 | 用途 | 本專案的產出位置 |
| --- | --- | --- |
| `.bit` | FPGA 設定資料，建立電路並帶入 BRAM 初始內容 | `build/system.bit` |
| `.elf` | MicroBlaze 編譯後的程式，包含程式碼、位址與除錯資訊 | `build/firmware/app.elf` |
| `.xsa` | 匯出硬體平台資訊，完整建置時也包含 bitstream | `build/system.xsa` |
| `.bd` | IP Integrator 的系統設計來源 | `FPGAGetStartedAgain.srcs/.../system.bd` |
| `.xdc` | 腳位與時序等約束 | `constraints/` 與原專案約束目錄 |

在本專案中，Vivado 會將 ELF 關聯到 MicroBlaze，再把程式資料填入 BRAM 的初始化內容。因此下載這份 bitstream 後，不需要另外手動載入 ELF 才能執行目前的範例。

## 4. 從下載到 main()

啟動順序如下：

1. JTAG 下載 bitstream，FPGA 完成設定。
2. 板上 100 MHz 經 BUFG 分配；Clock Wizard 產生 MIG 所需的 200 MHz 參考時脈。
3. Clock Wizard 鎖定後，解除 MIG 的系統重置。
4. MIG 初始化、校準 DDR2，提供 UI 時脈。
5. Reset Controller 等待相關 ready 訊號，再解除 CPU、LMB 與 AXI 周邊重置。
6. MicroBlaze 從位址 `0x00000000` 取第一條指令。
7. `start.S` 設定堆疊與資料基底暫存器，清除 BSS，再呼叫 `main()`。
8. `main()` 測試 DDR2，成功後以 GPIO 控制 LED 規律閃爍。

BSS 是未明確給定初始值的全域／靜態變數所在區域。啟動程式將它清零，讓 C 程式獲得預期的初始狀態。

注意：FPGA 的設定完成與應用程式執行成功是兩個不同的觀察點。下載 log 的 startup HIGH 支持 FPGA 設定成功；目前的規律閃爍則支持韌體已走完 DDR2 測試。

## 5. 對照原始碼

依序打開：

1. [system.bd](../../FPGAGetStartedAgain.srcs/sources_1/bd/system/system.bd)：在 Vivado 圖形介面中查看元件與連線。
2. [start.S](../../firmware/start.S)：找出 `_start`、`clear_bss`、`run_main`。
3. [linker.ld](../../firmware/linker.ld)：找出 BRAM 範圍、`.vectors`、`.text` 與 `_stack_top`。
4. [main.c](../../firmware/main.c)：找出 DDR2 寫入、讀回與 LED 成功／失敗路徑。

本專案連結時使用 `--no-relax`，避免 linker 縮短指令後改變原本以 `.org` 排定的向量位置。現階段先理解「CPU 的啟動位址必須對應到有效指令」，不需要背下每一條組合語言。

## 練習

1. 畫出 CPU 到 BRAM、DDR2、LED 的三條路徑，標出哪些經過 AXI。
2. 在 Block Design 找出 `microblaze_0`、`boot_bram`、`mig_7series_0`、`axi_gpio_0` 與 `rst_ui`。
3. 在 `linker.ld` 確認程式目前放在哪塊記憶體。
4. 寫下「有 bitstream、沒有有效韌體初始內容」時，你預期哪些部分能存在、哪些行為無法保證。

## 自我檢查與參考答案

**為什麼 CPU 可以和 DDR2 一起放在 FPGA 系統裡？**

CPU 是 FPGA 內的軟核心電路；DDR2 記憶體晶片在板上，透過 FPGA 內的 MIG 控制器連接。

**為什麼重新上電後可能沒有同樣的 LED 行為？**

目前採 JTAG 載入揮發性的 FPGA 設定，尚未建立 QSPI Flash 開機流程。

**LED 規律閃爍代表整個 128 MiB DDR2 都正常嗎？**

目前測試只涵蓋前 4 KiB 的兩組 pattern。這是基本功能驗證，沒有涵蓋全部容量或長時間穩定性。

## 驗收標準

不看文件，能在兩分鐘內說明「下載 bitstream → 時脈穩定 → DDR2 校準 → CPU 開機 → 記憶體測試 → GPIO 輸出」，並指出對應模組與來源檔。
