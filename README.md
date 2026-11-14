# FPGAGetStartedAgain

Nexys A7-100T / Artix-7 (`xc7a100tcsg324-1`)，使用 Vivado / Vitis 2024.2。

## 硬體架構

```text
100 MHz → BUFG ───────────────→ MIG sys_clk_i
            └→ Clock Wizard → 200 MHz → MIG clk_ref_i

MIG ui_clk → MicroBlaze、LMB、AXI Interconnect、GPIO、Reset Controller

MicroBlaze ILMB → Instruction LMB Controller ┐
                                          ├→ 64 KiB 雙埠 BRAM（程式、資料、堆疊）
MicroBlaze DLMB → Data LMB Controller ───────┘
MicroBlaze M_AXI_DP → AXI Interconnect ┬→ MIG AXI → 128 MiB DDR2
                                    └→ AXI GPIO → LED[0]（H17）
JTAG → MDM → MicroBlaze DEBUG
```

CPU 使用 MIG UI 時脈（依現有 DDR2 設定約 81.25 MHz），未啟用指令／資料快取。
CPU 從 BRAM 執行；目前 DDR2 僅映射到 CPU 資料空間，沒有 DDR2 指令執行路徑。
AXI Interconnect 自動處理 CPU 32 bit、MIG 128 bit 及 GPIO AXI Lite 的轉換。

| 位址範圍 | 裝置 | 用途 |
| --- | --- | --- |
| `0x00000000–0x0000FFFF` | BRAM | Reset vectors、程式、資料、4 KiB 保留堆疊 |
| `0x40000000–0x4000FFFF` | AXI GPIO | offset 0：LED[0] 資料，固定為輸出 |
| `0x80000000–0x87FFFFFF` | DDR2 | 128 MiB 資料記憶體 |

## 重置與開機

1. `CPU_RESETN` 為低時，Clock Wizard、MIG、CPU 與周邊進入重置。
2. Clock Wizard 鎖定後才解除 MIG 的低有效 `sys_rst`，確保 200 MHz 參考時脈穩定。
3. `proc_sys_reset` 等待 MIG 的 `mmcm_locked`、`init_calib_complete`，並監看 `ui_clk_sync_rst`。
4. Reset Controller 在 UI 時脈域依序解除 CPU、LMB、AXI 與 GPIO 重置；MDM 也可觸發系統重置。
5. CPU 從位址 0 的 BRAM 啟動，初始化堆疊與 BSS，再執行 `main()`。

`firmware/start.S`、`linker.ld`、`main.c` 是不依賴 BSP 的最小 bare-metal 韌體。
連結時使用 `--no-relax`，保留各 exception vector 的固定位址，避免 linker 縮短指令後移動向量。
ELF 會透過 Vivado 的 processor association 嵌入 BRAM 初始化內容，因此下載 bitstream 後即可開機。
這裡的開機記憶體是 FPGA BRAM；尚未加入 QSPI Flash 開機或燒錄流程。斷電後仍需由 JTAG 或另行設定的 FPGA configuration source 載入 bitstream。

韌體會破壞性測試 DDR2 開頭的 **4 KiB**，寫入位址相關 pattern 與其反相值並讀回比對：

- 成功：LED[0] 持續規律閃爍。
- 讀回錯誤：LED[0] 快閃兩下後暫停，再重複。
- LED 不亮：可能尚未完成校準或 CPU 開機；可透過 JTAG 檢查。

JTAG 可讀取 ELF 符號 `test_status`（1：測試中，2：成功，`0xDEAD`：失敗），以及
`failed_word`、`expected_value`、`observed_value`。測試不代表整個 128 MiB 記憶體皆已驗證。
LED 延遲是軟體 busy loop，並非精準計時。

## 建置與驗證

在專案根目錄執行：

```bash
make -C firmware
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source scripts/build.tcl -log build/build.log -journal build/build.jou
```

可透過 `make -C firmware TOOLCHAIN=/path/to/mb-` 指定其他 MicroBlaze 工具鏈。
硬體腳本會驗證 Block Design、關聯 ELF、綜合、實作、檢查 setup/hold slack 並產生：

- `build/system.bit`：包含韌體的 FPGA bitstream。
- `build/system.xsa`：硬體平台（完整建置後包含 bitstream）。
- `build/firmware/app.elf`、`app.map`、`app.dis`：韌體及除錯資料。
- `build/timing_summary.rpt`、`build/drc.rpt`：實作報告。

在 Vivado Hardware Manager 連接 Nexys A7-100T，選取 `build/system.bit` 進行 Program Device。
按 CPU RESET 按鈕應重新校準並重跑測試。

也可在能存取 USB/JTAG 與本機 TCP 的一般終端機，從專案根目錄執行：

```bash
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source scripts/program.tcl -log build/program.log -journal build/program.jou
```

先將板子接到 USB PROG/JTAG 並開啟電源。腳本要求只有一個 JTAG target，且其中只有一顆
`xc7a100t`，才會下載 `build/system.bit`；下載後從裝置支援的屬性讀回 DONE 狀態。
若沒有可讀取的 DONE 屬性，會明確顯示「下載命令成功，但獨立 DONE 讀回尚未確認」，不會宣稱已完成讀回。
這是揮發性的 FPGA 設定，
不寫入 QSPI Flash。DONE 只表示 FPGA 設定完成，DDR2 功能仍須觀察 LED／JTAG 測試狀態。
本次受管環境無法建立 hw_server socket（`Operation not permitted`），USB 列舉亦無法初始化，
因此無法透過此環境直接下載到板子；主機一般終端機的執行結果則見下方紀錄。

遇到連線錯誤，可先執行只讀的診斷工具：

```bash
python3 scripts/check_jtag.py
```

本次排查確認：建立 `AF_INET` socket 即被拒絕（errno 1），而 `/dev/bus/usb` 不存在。
主機 sysfs 已辨識到 `0403:6010 Digilent USB Device`，USB authorized 為 1，
`/etc/udev/rules.d` 也已有 Digilent／Xilinx 規則。因此目前的直接阻礙是此執行環境的
網路與裝置存取限制，尚無證據需要重裝 cable driver。已連上 USB 不代表已確認 FPGA 的 JTAG chain。
`program.tcl` 現在會預先檢查本機 TCP 與 USB 節點，避免反覆啟動必定失敗的 hw_server。
請在有 USB 存取與本機 TCP 權限的主機終端機執行上述燒錄指令；修改專案設定無法解除執行環境限制。

系統模擬（先完成韌體建置；模擬使用 `build/simulation` 下的獨立專案）：

```bash
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source scripts/simulate.tcl -log build/simulate.log -journal build/simulate.jou
```

模擬使用 MIG 隨附的 DDR2 model，執行兩次完整開機與記憶體測試，中間觸發一次外部重置，
並檢查校準前 CPU 不得解除重置、韌體成功狀態以及 LED 輸出。成功時輸出 `PASS: 2 BRAM boots...`。
可用環境變數 `MB_NM` 指定 `mb-nm` 路徑。

目前受管執行環境中的 XSim 會在啟動時回報 `unexpected exception when evaluating tcl command`，
連只有 `$display` 的最小測試亦相同。系統測試已通過編譯與 elaboration，但尚無執行通過的結果；
需在可正常啟動 XSim 的環境重跑。實際上板結果見下方紀錄。

### 本次建置結果（2026-11-14）

- Vivado 2024.2：Block Design 驗證、綜合、實作、bitstream 與包含 bitstream 的 XSA 匯出均成功。
- MicroBlaze GCC：680 bytes 程式／唯讀資料、16 bytes BSS，入口位址 `0x00000000`，沒有未解析符號。
- 工具確認 `app.elf` 已填入 BRAM INIT strings；`build/system.bit` 包含韌體。
- Setup WNS **+1.316 ns**、Hold WHS **+0.066 ns**、Pulse-width slack **+0.206 ns**，所有指定時序約束通過。
- 沒有未定義時脈或未約束的內部 endpoints。外部 CPU reset 與 LED 沒有同步 I/O delay 規格。
- DRC：0 errors、5 warnings。剩餘項目為缺少明確的 `CFGBVS`／`CONFIG_VOLTAGE` 設定（1）、
  已放置 LUT 配對警告（3）、MIG 內部 PLL 的混合 buffer 類型警告（1）。未停用或降低這些檢查的嚴重度；詳見 `build/drc.rpt`。
- 主機終端機已完成 FPGA 下載，使用者確認 LED[0] 規律閃爍，代表 MicroBlaze BRAM 開機、DDR2 校準、前 4 KiB 讀寫測試與 GPIO 輸出已通過基本上板驗證。
- 完整 128 MiB DDR2、長時間穩定性及系統模擬執行尚未驗證。

### 主機燒錄 log 排查（2026-11-14）

專案根目錄的 `vivado.log`（14:07）已成功連接 hw_server、開啟 Digilent JTAG target、
辨識 `xc7a100t` 並執行 `program_hw_devices`；工具回報 `End of startup status: HIGH`。
最後的錯誤是原腳本讀取不存在的 `REGISTER.CONFIG_STATUS.BIT14_DONE` 屬性，發生在下載完成之後。
已改成先列出裝置實際支援的 DONE 屬性再讀取，避免成功下載後因屬性名稱不相容而報錯。
新檢查程式仍待在主機終端機／實際 FPGA 驗證。

`no supported debug core(s)` 是 Hardware Manager 的 debug core 掃描訊息，不是下載失敗訊息，
也不能據此判定 MicroBlaze 的 JTAG 除錯是否可用。
較早 13:59 的 log 曾出現 `No devices detected on target`；後續多次已辨識到 FPGA，
不能僅憑早期紀錄認定該問題仍存在。後續使用者確認 LED[0] 規律閃爍，已完成目前韌體涵蓋的基本上板驗證。

## 來源與產生檔

- `FPGAGetStartedAgain.xpr`：直接開啟的 Vivado 專案。
- `FPGAGetStartedAgain.srcs/sources_1/bd/system/system.bd`：已補齊的系統設計。
- `constraints/led.xdc`：LED 腳位；100 MHz 與 CPU reset 約束沿用原有 Master XDC。
- `firmware/`：啟動程式、linker script、DDR2／GPIO 測試韌體。
- `scripts/build.tcl`：日常硬體建置。
- `scripts/simulate.tcl`、`sim/system_tb.sv`：系統模擬。
- `scripts/complete_system.tcl`：從原始未接線版本補齊架構的一次性遷移腳本；目前設計已套用，無須再執行。
- `.gen/`、`.cache/`、`.runs/`、`build/`：工具產生內容；優先修改 `.srcs`、韌體或腳本。

不要直接修改 MIG 產生的 RTL。DDR2 設定變更應使用 MIG GUI，並重新產生 IP、驗證與實作。

Git 僅保存設計來源、IP 設定、約束、韌體與腳本。`.gen`、`.runs`、快取、log、bitstream、XSA 與 ELF 都可由建置重新產生，因此不上傳。
從 GitHub clone 後，先確認已安裝 Nexys A7-100T board files，再執行 `make -C firmware` 與上述 `scripts/build.tcl` 指令。
建置腳本會重新產生 IP output products 與頂層 HDL wrapper，不需要從原電腦複製 `.gen` 目錄。
