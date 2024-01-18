#pragma once
#include <stdint.h>

#define max(a,b) \
    ({__typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
      _a > _b ? _a : b; \
    })

#define min(a,b) \
    ({__typeof__ (a) _a = (a); \
      __typeof__ (b) _b = (b); \
      _a < _b ? _a : b; \
    })

uint32_t align(uint32_t, uint32_t);