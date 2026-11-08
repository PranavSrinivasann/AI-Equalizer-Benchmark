/* Decision-feedback equalizer run: y[n] = sum c[k] r[n-k] - sum b[k-1] d[n-k].
 * d[] are the PAM4 decisions (-3,-1,1,3) of earlier outputs, so errors propagate.
 * Output n estimates the symbol sent `delay` before the newest sample. */
#include <stdint.h>

static int decide(double v) { return v < -2 ? -3 : v < 0 ? -1 : v < 2 ? 1 : 3; }

/* Returns symbol errors; bit errors via Gray map (-3:00 -1:01 1:11 3:10). */
int64_t dfe_run(const double *r, const int8_t *sent, int64_t n, int nff, const double *c,
                int nb, const double *b, int64_t skip, int64_t *bit_errors) {
    static const int gray[4] = {0, 1, 3, 2};
    int64_t sym = 0, bits = 0;
    int d[128] = {0};            /* d[k-1] = decision k outputs ago */
    for (int64_t i = nff - 1; i < n; i++) {
        double y = 0;
        for (int k = 0; k < nff; k++) y += c[k] * r[i - k];
        for (int k = 0; k < nb; k++) y -= b[k] * d[k];
        int dec = decide(y);
        for (int k = nb - 1; k > 0; k--) d[k] = d[k - 1];
        if (nb > 0) d[0] = dec;
        if (i >= skip) {
            int s = sent[i];
            if (dec != s) {
                sym++;
                int a = gray[(s + 3) / 2], bb = gray[(dec + 3) / 2];
                int x = a ^ bb;
                bits += (x & 1) + ((x >> 1) & 1);
            }
        }
    }
    *bit_errors = bits;
    return sym;
}
