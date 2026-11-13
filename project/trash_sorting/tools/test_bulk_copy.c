/* Check all source/destination alignments and guard bytes in the actual DDR
 * copy primitive. The MMIO protocol is unchanged. */
#include "acc_regs.h"
#include <assert.h>
#include <stdio.h>

int main(void)
{
    unsigned char source[64], actual[64], expected[64];
    unsigned a,b,k,pattern;
    for(pattern=0;pattern<256;pattern++) {
        for(k=0;k<64;k++) source[k]=(unsigned char)(pattern+k*73);
        for(a=0;a<8;a++) for(b=0;b<8;b++) {
            for(k=0;k<64;k++) actual[k]=expected[k]=0xa5;
            for(k=0;k<8;k++) expected[16+b+k]=source[16+a+k];
            acc_host_copy8(actual+16+b,source+16+a);
            for(k=0;k<64;k++) assert(actual[k]==expected[k]);
        }
    }
    puts("TEST_PASS bulk copy all64 alignments, guard bytes, all256 byte patterns");
    return 0;
}
