`ifndef __CACHE_SVH__
`define __CACHE_SVH__

`include "common.svh"
`include "../mycommon.svh"

parameter int cache_set_len = 4;
parameter int cache_line_len = 2;

parameter int cache_set_size = 1 << cache_set_len; // how many sets
parameter int cache_line_size = 1 << cache_line_len; //how many "lines"
parameter int cacheline_words = 16; //how many lines

typedef `BITS(32 - cache_set_len - 6) tag_t;
typedef `BITS(cache_set_len) index_t;
typedef `BITS(cache_line_len) position_t;
typedef i4 offset_t;

typedef enum i3 {
    SC_IDLE = 3'h0,     // 空闲
                        // 当已经被缓存时，target指向目标位置，否则指向0。
                        // flush始终指向待flush（或者说，待存储）的位置。
                        // 当有新读取操作时，（先从内存加载缓存，加载结束后再）返回缓存中的对应数据。
                        // 当有新修改操作时，（先从内存加载缓存，加载结束后再）修改缓存中的对应数据。
                        // 每次加载之前，判断目标缓存是否需要写回
    SC_FETCH = 3'h1,    // 加载一条cacheline，如果 ready = 1 则 offset + 1 并保存，否则等待
                        // 加载结束进入READY状态
                        // 目标值如果已经在缓存中则返回缓存中的值，否则返回最后一次读取的值
    SC_FLUSH = 3'h2,    // 将一条cacheline中的写回内存
                        // 写回结束判断是否正等待读取，如果是则读取内存。
    SC_FETCH_IDLE = 3'h3,     // 执行存储的req请求，并返回值
    SC_FETCH_SEC = 3'h4,
    SC_SEC = 3'h5,
    SC_UNCACHED = 3'h6,
    SC_FLUSH_IDLE = 3'h7
} cache_state_t /* verilator public */;

// the DCache
typedef struct packed {
    logic    en;
    position_t offset;
    strobe_t strobe;
    word_t   wdata;
} ram_switch_t;

// the ICache
typedef struct packed {
    logic    en;
    offset_t offset_1;
    strobe_t strobe;
    word_t   wdata;
    offset_t offset_2;
} icache_ram_switch_t;

typedef struct packed {
    tag_t tag;
    logic valid;
    logic dirty;
} cache_line_meta_t;

typedef struct packed {
    cache_line_meta_t [cache_line_size - 1:0] cache_line_meta;
    position_t flush_position;
} cache_set_meta_t;

typedef struct packed {
    cache_state_t stat;
    i4 offset; //这个offset就是busy offset
    dbus_req_t [1:0] req;
    // dreq 必须存储，否则 addr_ok 会失去意义，导致后续无法进行优化。
    // 那么在 IDLE 阶段，使用 dreq 进行解码。
    // 在其他阶段，因为已经在 context 中存储了 dreq，则用存储的 dreq 进行解码。
    cache_set_meta_t [cache_set_size - 1:0] cache_set_meta;
    dbus_req_t busy_req;
    logic busy_req_index;
    dbus_resp_t [1:0] resp;
    //cache_set_t [cache_set_size - 1:0] cache_set;
} cache_context_t /* verilator public */;

typedef struct packed {
    cache_state_t stat;
    offset_t offset;
    flex_bus_req_t req;
    // dreq 必须存储，否则 addr_ok 会失去意义，导致后续无法进行优化。
    // 那么在 IDLE 阶段，使用 dreq 进行解码。
    // 在其他阶段，因为已经在 context 中存储了 dreq，则用存储的 dreq 进行解码。
    cache_set_meta_t [cache_set_size - 1:0] cache_set_meta;
} Icache_context_t /* verilator public */;

parameter cache_line_meta_t CACHE_LINE_META_RESET = '{
    tag : '0,
    valid : '0,
    dirty : '0
} ;

parameter cache_set_meta_t CACHE_SET_META_RESET = '{
    cache_line_meta : {cache_line_size{CACHE_LINE_META_RESET}},
    flush_position : 0
};

parameter cache_context_t CACHE_CONTEXT_RESET = '{
    stat : SC_IDLE,
    offset : '0,
    req : '0,

    busy_req : '0,
    busy_req_index : '0,
    resp : '0,
    cache_set_meta : {cache_set_size{CACHE_SET_META_RESET}}
};

parameter Icache_context_t ICACHE_CONTEXT_RESET = '{
    stat : SC_IDLE,
    offset : '0,
    req : '0,
    cache_set_meta : {cache_set_size{CACHE_SET_META_RESET}}
};

`define RW_CACHE(M) \
    ram_switch[{index[M], offset[M]}].en = 1'b1;\
    ram_switch[{index[M], offset[M]}].offset = target_position[M];\
    ram_switch[{index[M], offset[M]}].strobe = strobe_i4[M];\
    ram_switch[{index[M], offset[M]}].wdata = in_dreq[M].data;\
    in_dresp[M].data = ram_rdata[{index[M], offset[M]}];\
    in_dresp[M].addr_ok = 1'b1;\
    in_dresp[M].data_ok = 1'b1;\
    cacheContext.resp[M].data = ram_rdata[{index[M], offset[M]}];\
    cacheContext.resp[M].addr_ok = 1'b1;\
    cacheContext.resp[M].data_ok = 1'b1;\
    if (|strobe_i4[M]) begin\
        cacheContext.cache_set_meta[index[M]].cache_line_meta[target_position[M]].dirty = 1'b1;\
    end

`endif
