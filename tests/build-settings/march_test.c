/* Runs instructions that -march=native can use, then says which thread ran it. */
#define _GNU_SOURCE
#include <immintrin.h>
#include <sched.h>
#include <stdio.h>

__attribute__((noinline)) static double work(int n) {
    double a[256], b[256], total = 0;
    for (int i = 0; i < 256; i++) { a[i] = i * n; b[i] = i + n; }
    for (int r = 0; r < 2000; r++)
        for (int i = 0; i < 256; i++) total += a[i] * b[i] + (double)__builtin_popcount(i);
    return total;
}

int main(void) {
    unsigned long long x = _pdep_u64(0xff, 0xf0f0);          /* BMI2 */
    __m256i v = _mm256_set1_epi32(3);                        /* AVX2 */
    v = _mm256_dpbusd_avx_epi32(v, v, v);                    /* AVX-VNNI */
    printf("thread %d ok: %.0f %llu %d\n", sched_getcpu(), work(3), x, _mm256_extract_epi32(v, 0));
    return 0;
}
