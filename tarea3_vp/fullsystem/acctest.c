/* acctest.c — Programa en C de referencia: maneja el acelerador RGB→gris del VP desde el
 * ARM64 (Linux), por MMIO + DMA. Es la "cara CPU" del prototipo virtual (rol de P5 en el
 * sistema real; aquí lo provee P4 para demostrar la frontera end-to-end).
 *
 * Modelo de memoria (ver TRASPASO-P5.md):
 *   - Registros del acelerador en la dirección física ACC_BASE (device MMIO), vía /dev/mem.
 *   - Buffers de imagen en una región de DRAM RESERVADA al kernel (arranque con mem=1536M):
 *     [0xE0000000, 0x100000000) queda fuera de "System RAM", así que /dev/mem la mapea en una
 *     dirección física CONOCIDA y CONTIGUA (BUF_PHYS). El acelerador hace DMA ahí; el memory
 *     controller de gem5 respalda los 2 GiB completos, así que CPU y acelerador comparten esa RAM.
 *
 * Imprime diagnósticos con prefijo ACCTEST_ para poder rastrear cada etapa en la consola.
 *
 * Compilar (host):  aarch64-linux-gnu-gcc -O2 -static -s acctest.c -o acctest
 */
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>

#define ACC_BASE     0x10030000UL   /* base de registros (== accelerator.h) */
#define REG_MAP_SIZE 0x1000UL
#define CONTROL      0x00           /* W: bit0=START ; R: bit0=DONE */
#define ADDR_INPUT   0x04
#define ADDR_OUTPUT  0x08
#define NUM_PIXELS   0x0C

#define BUF_PHYS     0xE0000000UL   /* base física reservada (kernel mem=1536M) */
#define IN_OFF       0x00000000UL
#define OUT_OFF      0x00800000UL   /* salida 8 MB después de la entrada */
#define BUF_MAP_SIZE 0x01000000UL   /* 16 MB */

#ifndef NPIX
#define NPIX 256
#endif

static inline uint8_t gray_golden(uint8_t r, uint8_t g, uint8_t b)
{
    double y = 0.2126 * r + 0.7152 * g + 0.0722 * b;   /* BT.709, == rgb_to_gray.h */
    return (uint8_t)(y + 0.5);
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);        /* sin buffer: cada print sale de inmediato */
    const uint32_t n = NPIX;
    printf("ACCTEST_START npix=%u ACC_BASE=0x%lx BUF_PHYS=0x%lx\n", n, ACC_BASE, BUF_PHYS);

    int fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (fd < 0) { printf("ACCTEST_FAIL open /dev/mem errno=%d (%s)\n", errno, strerror(errno)); return 1; }
    printf("ACCTEST_STEP /dev/mem abierto (fd=%d)\n", fd);

    volatile uint32_t *regs = (volatile uint32_t *)mmap(
        NULL, REG_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, ACC_BASE);
    if (regs == MAP_FAILED) { printf("ACCTEST_FAIL mmap regs errno=%d (%s)\n", errno, strerror(errno)); return 1; }
    printf("ACCTEST_STEP regs mapeados en %p\n", (void *)regs);

    uint8_t *buf = (uint8_t *)mmap(
        NULL, BUF_MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, BUF_PHYS);
    if (buf == MAP_FAILED) { printf("ACCTEST_FAIL mmap buf errno=%d (%s)\n", errno, strerror(errno)); return 1; }
    printf("ACCTEST_STEP buf mapeado en %p\n", (void *)buf);

    /* --- prueba de la cara de CONTROL (MMIO write+read) ANTES del DMA --- */
    regs[NUM_PIXELS / 4] = n;
    asm volatile("dsb sy" ::: "memory");
    uint32_t rb = regs[NUM_PIXELS / 4];
    printf("ACCTEST_STEP MMIO regcheck: NUM_PIXELS escrito=%u leido=%u -> %s\n",
           n, rb, (rb == n) ? "OK" : "MISMATCH");
    if (rb != n) { printf("ACCTEST_FAIL MMIO no funciona (control)\n"); return 1; }

    uint8_t *in  = buf + IN_OFF;
    uint8_t *out = buf + OUT_OFF;
    for (uint32_t i = 0; i < n; i++) {
        in[3 * i + 0] = (i * 7)  & 0xff;
        in[3 * i + 1] = (i * 13) & 0xff;
        in[3 * i + 2] = (i * 29) & 0xff;
    }
    for (uint32_t i = 0; i < n; i++) out[i] = 0xAA;   /* marca previa */
    asm volatile("dsb sy" ::: "memory");

    /* --- configurar y disparar el DMA --- */
    regs[ADDR_INPUT  / 4] = (uint32_t)(BUF_PHYS + IN_OFF);
    regs[ADDR_OUTPUT / 4] = (uint32_t)(BUF_PHYS + OUT_OFF);
    regs[NUM_PIXELS  / 4] = n;
    asm volatile("dsb sy" ::: "memory");
    printf("ACCTEST_STEP disparando START (in=0x%x out=0x%x n=%u)\n",
           (uint32_t)(BUF_PHYS + IN_OFF), (uint32_t)(BUF_PHYS + OUT_OFF), n);
    regs[CONTROL / 4] = 1;                                /* START */

    uint64_t guard = 0;
    while ((regs[CONTROL / 4] & 1u) == 0) {
        if (++guard > 2000000000ULL) { printf("ACCTEST_FAIL timeout esperando DONE\n"); return 1; }
    }
    asm volatile("dsb sy" ::: "memory");
    printf("ACCTEST_STEP DONE observado (guard=%llu)\n", (unsigned long long)guard);

    /* --- verificar bit-exact --- */
    uint32_t errors = 0; int first = -1;
    for (uint32_t i = 0; i < n; i++) {
        uint8_t r = (i * 7) & 0xff, g = (i * 13) & 0xff, b = (i * 29) & 0xff;
        uint8_t exp = gray_golden(r, g, b);
        if (out[i] != exp) { if (first < 0) first = (int)i; errors++; }
    }
    printf("ACCTEST_STEP muestras out[0..3]=%u,%u,%u,%u golden[0..3]=%u,%u,%u,%u\n",
           out[0], out[1], out[2], out[3],
           gray_golden(0,0,0), gray_golden(7,13,29),
           gray_golden(14,26,58), gray_golden(21,39,87));

    if (errors == 0)
        printf("ACCTEST_PASS %u pixeles bit-exact via MMIO+DMA\n", n);
    else {
        uint8_t r = (first * 7) & 0xff, g = (first * 13) & 0xff, b = (first * 29) & 0xff;
        printf("ACCTEST_FAIL %u/%u errores; primer px %d got=%u exp=%u\n",
               errors, n, first, out[first], gray_golden(r, g, b));
    }
    return errors ? 1 : 0;
}
