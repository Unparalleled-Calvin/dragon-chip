#pragma once

#include "bus.h"

#include "VModel__Syms.h"

using VScope = VModel___024unit;
using VModelScope = VModel_VCacheTop;

using CBusWrapper = CBusWrapperGen<VModelScope>;

using BufferState = VScope::cache_state_t;
