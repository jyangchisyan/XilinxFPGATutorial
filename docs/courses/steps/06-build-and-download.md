# 06：從修改 C 到板子執行新版

[上一節](05-delay-and-duty.md) · [小單元目錄](README.md) · [下一節](07-frequency-and-period.md)

## 這節只學一件事

理解本專案更新韌體的三個階段。

```text
修改 firmware/main.c
    ↓
編譯：產生 app.elf
    ↓
Vivado 建置：將韌體填入 BRAM 初始內容，產生 system.bit
    ↓
JTAG 下載：板子開始執行新版
```

從專案根目錄依序執行，每步成功後才進入下一步：

```bash
make -C firmware
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source scripts/build.tcl -log build/build.log -journal build/build.jou
/tools/Xilinx/Vivado/2024.2/bin/vivado -mode batch -source scripts/program.tcl -log build/program.log -journal build/program.jou
```

| 階段 | 主要產物／結果 | LED 節奏是否立即更新 |
| --- | --- | --- |
| `make` | `build/firmware/app.elf` | 否 |
| 硬體建置 | `build/system.bit`、`system.xsa` | 否 |
| 成功下載新版 | FPGA 載入新的設定與 BRAM 初始內容 | 應開始執行新版，再觀察結果 |

這些指令沿用目前安裝路徑；換電腦時需要調整工具位置。下載需要主機的 USB/JTAG 與本機 TCP 存取權限。

## 練習

只修改 C 並執行 `make`，原本正在閃爍的板子會立即加快嗎？為什麼？

<details>
<summary>查看答案</summary>

不會。新版 ELF 仍在電腦上；本課流程還需要產生包含新版韌體的 bitstream 並下載。板子不會自動讀取電腦上剛改的檔案。

</details>

## 過關標準

能根據 log 分辨編譯、硬體建置與下載是否各自完成，再用實際 LED 行為驗證修改效果。
