#pragma once

#include "defs.h"
#include "memory.h"
#include "reference.h"

class MyCache;

#define cache_line_size 4
#define cache_set_size 16
#define cache_line_len 2
#define cache_set_len 4

class cache_line_meta_t{
    public:
    int tag;
    bool valid;
    bool dirty;
};

class cache_line_t{
    public:
    int data[16];
};

class cache_set_meta_t{
    public:
    cache_line_meta_t cache_line_meta[cache_line_size];
    int flush_position;
};

class cache_set_t {
    public:
    cache_line_t cache_line[cache_line_size];
};

class cache_context_t{
    public:
    cache_set_meta_t cache_set_meta[cache_set_size];
    cache_set_t cache_set[cache_set_size];
    int& operator[](int x){
        int a = x / (16 * cache_line_size);
        int b = x % (16 * cache_line_size);
        int c = b / 16;
        int d = b % 16;
        return cache_set[a].cache_line[c].data[d];
    }
};

class CacheRefModel final : public ICacheRefModel {
public:
    CacheRefModel(MyCache *_top, size_t memory_size);

    void reset();
    auto load(addr_t addr, AXISize size) -> word_t;
    void store(addr_t addr, AXISize size, word_t strobe, word_t data);
    void check_internal();
    void check_memory();

private:
    cache_context_t buffer;
    MyCache *top;
    VModelScope *scope;

    /**
     * TODO (Lab3) declare reference model's memory and internal states :)
     *
     * NOTE: you can use BlockMemory, or replace it with anything you like.
     */

    // int state;
    BlockMemory mem;
    
    // fetch the cache line containing addr into buffer.
    void fetch(addr_t addr);
};
