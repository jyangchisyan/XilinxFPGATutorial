# 03：指令放在 BRAM，測試資料放在 DDR2

[上一節](02-address-and-data.md) · [小單元目錄](README.md) · [下一節](04-reset-and-boot.md)

## 這節只學一件事

區分 CPU 執行的指令與指令操作的資料。

| 記憶體 | 本專案的用途 |
| --- | --- |
| BRAM | 指令、全域變數與堆疊，範圍為 `0x00000000–0x0000FFFF` |
| DDR2 | 記憶體讀寫測試，範圍為 `0x80000000–0x87FFFFFF` |

CPU 測試 DDR2 時，指令仍然來自 BRAM：

```text
BRAM → 指令 → MicroBlaze
                  ↓
               AXI → MIG → DDR2 測試資料
```

「正在測試哪塊記憶體」與「程式從哪裡取得」是兩個問題。其他設計可以讓程式在外部記憶體執行，但需要相應的取指連線、位址配置與軟體設定。

目前 `DDR_BASE[i]` 是 32 bit 元素，所以測試 `1024` 個元素的容量為：

```text
1024 × 4 bytes = 4096 bytes = 4 KiB
```

## 練習

CPU 正在讀回 DDR2 資料時，執行讀回與比較動作的指令從哪裡取得？

<details>
<summary>查看答案</summary>

BRAM。CPU 從 BRAM 取指令，再依指令透過 AXI 與 MIG 存取 DDR2。

</details>

## 過關標準

能解釋「BRAM 保存測試程式，DDR2 保存被測試的資料」，且知道目前未測試完整的 128 MiB。
