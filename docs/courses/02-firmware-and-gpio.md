# 第 02 課：用 C 程式操作 GPIO

[上一課：系統與開機](01-system-and-boot.md) · [課程目錄](README.md) · [下一課：Verilog 電路](03-verilog-counter.md)

## 這一課的目標

理解記憶體映射 I/O（MMIO）、`volatile` 與周邊暫存器，完成一次「改韌體 → 編譯 → 產生含新韌體的 bitstream → 下載 → 觀察」的循環。

## 1. CPU 如何知道要操作 LED？

CPU 執行讀寫指令時，會帶出位址與資料。系統利用位址判斷這次交易應送往 BRAM、DDR2 或 GPIO。

| 位址範圍 | 對應裝置 |
| --- | --- |
| `0x00000000–0x0000FFFF` | 64 KiB BRAM |
| `0x40000000–0x4000FFFF` | AXI GPIO 的位址視窗 |
| `0x80000000–0x87FFFFFF` | 128 MiB DDR2 |

GPIO 的 64 KiB 視窗用於系統位址解碼，不代表 GPIO 內有 64 KiB 的資料儲存空間。實際可使用的暫存器取決於該 IP 的設定。

## 2. 讀懂這一行 C

來自 [main.c](../../firmware/main.c)：

```c
#define GPIO_DATA (*(volatile uint32_t *)0x40000000u)
```

由內而外理解：

1. `0x40000000u` 是 GPIO 的基底位址。
2. `(volatile uint32_t *)` 把這個數值視為指向 32 bit 物件的指標。
3. `*` 讓程式可以直接對該位置讀寫。
4. `GPIO_DATA = 1;` 會要求一次實際的硬體寫入。

`volatile` 告訴編譯器，這個存取本身有作用，需要保留。它不會自動提供跨執行緒同步、保證複合運算原子性，或取代所有情況需要的硬體記憶體屏障。本專案的 CPU 快取已關閉，使用簡單的周邊讀寫路徑。

目前 AXI GPIO 的第 1 channel 為固定輸出，寬度為 1 bit，只有最低位元連到 LED[0]：

```c
GPIO_DATA = 1;  /* bit 0 = 1，LED 亮 */
GPIO_DATA = 0;  /* bit 0 = 0，LED 暗 */
```

因此寫入 `2` 的最低位元仍為 0，不能用它點亮另一顆 LED；其他 LED 尚未連線。

## 3. 同樣的指標寫法，為什麼 DDR2 像陣列？

```c
#define DDR_BASE ((volatile uint32_t *)0x80000000u)
#define TEST_WORDS 1024u
```

`DDR_BASE[i]` 的位址為：

```text
0x80000000 + i × sizeof(uint32_t)
```

本專案一個 `uint32_t` 是 4 bytes，所以：

- `DDR_BASE[0]`：`0x80000000`
- `DDR_BASE[1]`：`0x80000004`
- `DDR_BASE[1023]`：`0x80000FFC`
- 測試容量：`1024 × 4 = 4096 bytes = 4 KiB`

韌體先寫入 `0xa5a50000u ^ i`，再讀回比對，接著使用反相值重做一次。位址相關的 pattern 有助於發現部分位址或資料路徑錯誤，但不是完整的記憶體測試。

## 4. 第一個修改：改變亮暗比例

先保留一份 `firmware/main.c` 的原始內容，再找到測試成功後的無限迴圈。只修改成功路徑的亮燈延遲：

```c
for (;;) {
    GPIO_DATA = 1;
    delay(2000000u);  /* 原本是 4000000u */
    GPIO_DATA = 0;
    delay(4000000u);
}
```

預測：亮燈時間約縮短為原本的一半，暗燈時間大致維持原狀。先保留失敗路徑的快閃兩下，讓你仍能辨識 DDR2 測試失敗。

這裡的 `ticks` 是迴圈次數。每圈包含多條指令，執行時間也受 CPU 與編譯結果影響，不能把 `4000000` 直接解讀為 4,000,000 個時脈或精準的秒數。

## 5. 重新建置與下載

從專案根目錄執行，並等待每一步成功結束：

```bash
make -C firmware
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source scripts/build.tcl -log build/build.log -journal build/build.jou
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source scripts/program.tcl -log build/program.log -journal build/program.jou
```

`make` 產生 ELF；硬體建置腳本把 ELF 嵌入 BRAM 初始化內容，產生新的 `build/system.bit`；下載腳本才將它送到板子。只執行 `make`，板上既有程式不會自動改變。

本課使用這套完整流程理解各步驟的作用。日後可以再研究更新 BRAM 內容的較快流程，先不要省略目前需要的步驟。

如果下載失敗，先分辨錯誤層級：

| 現象 | 優先檢查 |
| --- | --- |
| ELF 編譯失敗 | C 語法、工具鏈與 linker 訊息 |
| 硬體建置失敗 | `build/build.log` 與對應 `.runs` log |
| hw_server 無法連線 | 主機 TCP 權限與服務狀態 |
| 找得到 USB target，但沒有 FPGA | 板子電源與 JTAG chain |
| 下載後節奏沒有改變 | 是否使用剛建好的 bitstream、是否仍在失敗路徑 |

可先執行 `python3 scripts/check_jtag.py` 檢查本機 TCP 與 USB 存取。受管執行環境的限制，不能只靠修改韌體解除。

## 練習

1. 先預測，再實際觀察上述亮暗比例的修改。
2. 將亮、暗兩個延遲都改為原值的一半，與第一個修改比較。
3. 找出 `test_status` 的 1、2、`0xDEAD` 分別在哪裡寫入。
4. 在 paper trace 中計算 `DDR_BASE[256]` 的位址，不必改動 DDR2 測試範圍。

## 自我檢查與參考答案

- `DDR_BASE[256]` 是 `0x80000400`。
- 只改亮燈延遲，會改變亮暗比例，也會改變完整週期。
- 兩個延遲一起減半，完整週期大致減半，亮暗比例大致不變。
- `volatile` 保留硬體存取；實際周邊由硬體位址解碼與連線決定。

## 驗收標準

能指出 MMIO 基底位址、計算陣列元素位址，並透過完整建置與下載觀察到符合預測的 LED 模式。最後還原原本的成功模式，或清楚記錄保留了哪個版本。
