#include <stdint.h>

/* Must match scripts/complete_system.tcl. All code/data/stack stay in BRAM. */
#define GPIO_DATA (*(volatile uint32_t *)0x40000000u)
#define DDR_BASE ((volatile uint32_t *)0x80000000u)
#define TEST_WORDS 1024u

/* Inspect these over JTAG: 1 = testing, 2 = pass, 0xdead = failure. */
volatile uint32_t test_status;
volatile uint32_t failed_word;
volatile uint32_t expected_value;
volatile uint32_t observed_value;

static void delay(uint32_t ticks)
{
    while (ticks--) {
        __asm__ volatile ("nop");
    }
}

static int check(uint32_t index, uint32_t expected)
{
    uint32_t actual = DDR_BASE[index];
    if (actual == expected) return 1;
    failed_word = index;
    expected_value = expected;
    observed_value = actual;
    test_status = 0xdeadu;
    return 0;
}

int main(void)
{
    test_status = 1;
    GPIO_DATA = 0;
    /* Destructive test of the first 4 KiB only; CPU caches are disabled. */
    for (uint32_t i = 0; i < TEST_WORDS; ++i)
        DDR_BASE[i] = 0xa5a50000u ^ i;
    for (uint32_t i = 0; i < TEST_WORDS; ++i)
        if (!check(i, 0xa5a50000u ^ i)) goto failed;
    for (uint32_t i = 0; i < TEST_WORDS; ++i)
        DDR_BASE[i] = ~(0xa5a50000u ^ i);
    for (uint32_t i = 0; i < TEST_WORDS; ++i)
        if (!check(i, ~(0xa5a50000u ^ i))) goto failed;
    test_status = 2;
    for (;;) {
        GPIO_DATA = 1;
        delay(4000000u);
        GPIO_DATA = 0;
        delay(4000000u);
    }
failed:
    /* Fast double blink indicates a DDR readback mismatch. */
    for (;;) {
        for (unsigned i = 0; i < 2; ++i) {
            GPIO_DATA = 1; delay(400000u);
            GPIO_DATA = 0; delay(400000u);
        }
        delay(4000000u);
    }
}
