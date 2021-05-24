#include "mycache.h"
#include "cache_ref.h"

CacheRefModel::CacheRefModel(MyCache *_top, size_t memory_size)
    : top(_top), scope(top->VCacheTop), mem(memory_size) {
    /**
     * TODO (Lab3) setup reference model :)
     */

    mem.set_name("ref");
}

void CacheRefModel::reset() {
    /**
     * TODO (Lab3) reset reference model :)
     */

    log_debug("ref: reset()\n");
    
    for (int i = 0; i < cache_set_size; i++){
        buffer.cache_set_meta[i].flush_position = 0;
        for (int j = 0; j < cache_line_size; j++) {
            buffer.cache_set_meta[i].cache_line_meta[j].tag = 0;
            buffer.cache_set_meta[i].cache_line_meta[j].valid = 0;
            buffer.cache_set_meta[i].cache_line_meta[j].dirty = 0;
            for (int k = 0; k < 16; k++)
                buffer.cache_set[i].cache_line[j].data[k] = 0;
        }
    }
    
    mem.reset();
}

void CacheRefModel::fetch(addr_t addr) {
    int tag = addr >> (6 + cache_set_len);
    int index = (addr >> 6) & (cache_set_size - 1);
    int position = -1;
    for (int p = 0; p < cache_line_size; p++)
        if (buffer.cache_set_meta[index].cache_line_meta[p].valid && buffer.cache_set_meta[index].cache_line_meta[p].tag == tag) {
            position = p;
            break;
        }
    if (position == -1) {
        position = buffer.cache_set_meta[index].flush_position;
        if (buffer.cache_set_meta[index].cache_line_meta[position].dirty) {
            int flush_tag = buffer.cache_set_meta[index].cache_line_meta[position].tag;
            int flush_index = index;
            int flush_addr = ((flush_tag << cache_set_len) | flush_index) << 6;
            for (int i = 0; i < 16; i++){
                mem.store(flush_addr, buffer.cache_set[index].cache_line[position].data[i], STROBE_TO_MASK[15]);
                flush_addr = flush_addr + 4;
            }
            buffer.cache_set_meta[index].cache_line_meta[position].dirty = 0;
        }
        int target_addr = ((tag << cache_set_len) | index) << 6;
        for (int i = 0; i < 16; i++) {
            buffer.cache_set[index].cache_line[position].data[i] = mem.load(target_addr);
            target_addr = target_addr + 4;
        }
        buffer.cache_set_meta[index].cache_line_meta[position].tag = tag;
        buffer.cache_set_meta[index].cache_line_meta[position].valid = 1;
        buffer.cache_set_meta[index].cache_line_meta[position].dirty = 0;
        buffer.cache_set_meta[index].flush_position = (buffer.cache_set_meta[index].flush_position + 1) % cache_line_size;
    }
}

auto CacheRefModel::load(addr_t addr, AXISize size) -> word_t {
    /**
     * TODO (Lab3) implement load operation for reference model :)
     */

    log_debug("ref: load(0x%x, %d)\n", addr, 1 << size);
    fetch(addr);
    
    int tag = addr >> (6 + cache_set_len);
    int index = (addr >> 6) & (cache_set_size - 1);
    int offset = (addr >> 2) & 15;
    int position = -1;
    for (int p = 0; p < cache_line_size; p++)
        if (buffer.cache_set_meta[index].cache_line_meta[p].valid && buffer.cache_set_meta[index].cache_line_meta[p].tag == tag) {
            position = p;
            break;
        }
    
    asserts(position != -1, "position == -1\n");
    
    return buffer.cache_set[index].cache_line[position].data[offset];
}

void CacheRefModel::store(addr_t addr, AXISize size, word_t strobe, word_t data) {
    /**
     * TODO (Lab3) implement store operation for reference model :)
     */
    log_debug("ref: store(0x%x, %d, %x, \"%08x\")\n", addr, 1 << size, strobe, data);
    fetch(addr);

    int tag = addr >> (6 + cache_set_len);
    int index = (addr >> 6) & (cache_set_size - 1);
    int offset = (addr >> 2) & 15;
    int position = -1;
    for (int p = 0; p < cache_line_size; p++)
        if (buffer.cache_set_meta[index].cache_line_meta[p].valid && buffer.cache_set_meta[index].cache_line_meta[p].tag == tag) {
            position = p;
            break;
        }
    
    asserts(position != -1, "position == -1\n");
    
    auto mask = STROBE_TO_MASK[strobe];
    auto &value = buffer.cache_set[index].cache_line[position].data[offset];
    value = (data & mask) | (value & ~mask);
    buffer.cache_set_meta[index].cache_line_meta[position].dirty = 1;
}

void CacheRefModel::check_internal() {
    /**
     * TODO (Lab3) compare reference model's internal states to RTL model :)
     *
     * NOTE: you can use pointer top and scope to access internal signals
     *       in your RTL model, e.g., top->clk, scope->mem.
     */

    log_debug("ref: check_internal()\n");

    for (int index = 0; index < cache_set_size; index++)
        for (int position = 0; position < cache_line_size; position++)
            for (int offset = 0; offset < 16; offset++){
                int i = index * cache_line_size + position;
                asserts(
                    !scope->get_meta_from_array(index, position) || buffer[i * 16 + offset] == scope->mem[i * 16 + offset],
                    "reference model's internal state is different from RTL model."
                    " at mem[%x][%x][%x], valid = %d, expected = %08x, got = %08x",
                    index, position, offset, 
                    scope->get_meta_from_array(index, position), 
                    buffer[i * 16 + offset], 
                    scope->mem[i * 16 + offset]
                );
            }
}

void CacheRefModel::check_memory() {
    /**
     * TODO (Lab3) compare reference model's memory to RTL model :)
     *
     * NOTE: you can use pointer top and scope to access internal signals
     *       in your RTL model, e.g., top->clk, scope->mem.
     *       you can use mem.dump() and MyCache::dump() to get the full contents
     *       of both memories.
     */

    log_debug("ref: check_memory()\n");

    /**
     * the following comes from StupidBuffer's reference model.
     */
    auto v1 = mem.dump(0, mem.size());
    asserts(mem.dump(0, mem.size()) == top->dump(), "reference model's memory content is different from RTL model");
}
