`include "common.svh"

module abcICache (
    input logic clk, resetn,

    input  flex_bus_req_t  ireq,
    output flex_bus_resp_t iresp,
    output cbus_req_t  icreq,
    input  cbus_resp_t icresp
);
    flex_bus_req_t  in_ireq;
    flex_bus_resp_t in_iresp;
    assign in_ireq = ireq;
    assign iresp = in_iresp;
    /*
    SkidBuffer #(.req_t(flex_bus_req_t), .resp_t(flex_bus_resp_t))
             SkidBuffer_inst  (.m_req(ireq), 
                               .m_resp(iresp),
                               .s_req(in_ireq),
                               .s_resp(in_iresp),
                               .*);
    */
    cache_state_t Cache_state /* verilator public_flat_rd */;
    assign Cache_state = CacheContext.stat;
    
    Icache_context_t CacheContext, cacheContext;
    
    tag_t tag;
    index_t index;
    offset_t offset, offset_plus_1;
    i2 offset_byte;
    
    assign offset_plus_1 = offset + 1;
    
    always_comb begin
        if (CacheContext.stat == SC_IDLE) begin
            {tag, index, offset, offset_byte} = in_ireq.addr;
        end
        else begin
            {tag, index, offset, offset_byte} = CacheContext.req.addr;
        end
    end

    logic cached;
    position_t target_position;
    cache_set_meta_t target_cache_set_meta;
    cache_line_meta_t target_cache_line_meta;

    always_comb begin
        target_cache_set_meta = CacheContext.cache_set_meta[index];
        
        cached = 0;
        target_position = 0;
        
        for (int i = 0; i < cache_line_size; i++)
            if (target_cache_set_meta.cache_line_meta[i].valid && target_cache_set_meta.cache_line_meta[i].tag == tag) begin
                cached = 1;
                target_position = i[cache_line_len - 1:0];
            end
        
        target_cache_line_meta = target_cache_set_meta.cache_line_meta[target_position];
    end
    
    tag_t flush_tag;
    position_t flush_position;
    cache_line_meta_t flush_cache_line_meta;
    addr_t flush_addr;
    
    always_comb begin
        flush_position = CacheContext.cache_set_meta[index].flush_position;
        flush_cache_line_meta = CacheContext.cache_set_meta[index].cache_line_meta[flush_position];
        flush_tag = flush_cache_line_meta.tag;
        flush_addr = {flush_tag, index, 6'b0};
    end
    
    word_t write_in_data;
    
    icache_ram_switch_t [cache_set_size * cache_line_size - 1: 0] ram_switch;
    word_t [cache_set_size * cache_line_size - 1: 0] ram_rdata_1, ram_rdata_2;
    
    
    generate
        for (genvar i = 0; i < cache_set_size * cache_line_size; i++) begin : Test_RAM_Initial
            Test_RAM #(.NUM_BYTES(64)) icache_inst (
                .clk(clk), .en(ram_switch[i].en),
                .addr_1(ram_switch[i].offset_1),
                .strobe(ram_switch[i].strobe),
                .wdata(ram_switch[i].wdata),
                .addr_2(ram_switch[i].offset_2),
                .rdata(ram_rdata_1[i]),
                .rdata_2(ram_rdata_2[i])
            );
        end
    endgenerate
    
    always_comb begin 
        cacheContext = CacheContext;
        in_iresp = '0;
        icreq = '0;
        write_in_data = '0;
        ram_switch = '0;
        unique case (CacheContext.stat)
            SC_IDLE: begin
                if (in_ireq.valid) begin
                    if (cached) begin
                        // 写入到缓存，并返回写入前的值
                        ram_switch[{index, target_position}].en = 1;
                        ram_switch[{index, target_position}].offset_1 = offset;
                        ram_switch[{index, target_position}].strobe = '0;
                        ram_switch[{index, target_position}].wdata = '0;
                        ram_switch[{index, target_position}].offset_2 = offset_plus_1;
                        
                        in_iresp.valid_2 = offset_plus_1 != 0;
                        in_iresp.data_1 = ram_rdata_1[{index, target_position}];
                        in_iresp.data_2 = ram_rdata_2[{index, target_position}];
                        in_iresp.addr_ok = 1;
                        in_iresp.data_ok = 1;
                    end
                    else begin
                        in_iresp.addr_ok = 1; // 1
                        in_iresp.data_ok = 0;
                        cacheContext.offset = '0;
                        cacheContext.req = in_ireq;
                        // 从内存中读取数据存入缓存
                        cacheContext.stat = SC_FETCH;
                    end
                end
            end
            SC_FETCH: begin
                icreq.valid = 1;
                icreq.is_write = 0;
                icreq.size = MSIZE4;
                icreq.addr = {CacheContext.req.addr[31:6], 6'b0};
                icreq.strobe = '0;
                icreq.data = '0;
                icreq.len = MLEN16;
                in_iresp = '0;
                if (icresp.ready) begin
                    ram_switch[{index, flush_position}].en = 1;
                    ram_switch[{index, flush_position}].offset_1 = CacheContext.offset;
                    ram_switch[{index, flush_position}].strobe = 4'b1111;
                    ram_switch[{index, flush_position}].wdata = icresp.data;
                    ram_switch[{index, flush_position}].offset_2 = '0;
                    if (CacheContext.offset == offset) begin
                        in_iresp.addr_ok = 0;
                        in_iresp.data_ok = 1;
                        in_iresp.data_1 = icresp.data;
                        in_iresp.valid_2 = '0;
                        in_iresp.data_2 = '0;
                        cacheContext.stat = SC_FETCH_IDLE;
                    end
                    if (CacheContext.offset == 4'hf) begin // !icresp.last
                        cacheContext.stat = SC_IDLE;
                        cacheContext.offset = '0;
                        cacheContext.cache_set_meta[index].cache_line_meta[flush_position].tag = tag;
                        cacheContext.cache_set_meta[index].cache_line_meta[flush_position].valid = 1;
                        cacheContext.cache_set_meta[index].cache_line_meta[flush_position].dirty = 0;
                        cacheContext.cache_set_meta[index].flush_position = CacheContext.cache_set_meta[index].flush_position + 1;
                    end
                    else begin
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                end
            end
            SC_FETCH_IDLE: begin
                icreq.valid = 1;
                icreq.is_write = 0;
                icreq.size = MSIZE4;
                icreq.addr = {CacheContext.req.addr[31:6], 6'b0};
                icreq.strobe = '0;
                icreq.data = '0;
                icreq.len = MLEN16;
                in_iresp = '0;
                if (icresp.ready) begin
                    ram_switch[{index, flush_position}].en = 1;
                    ram_switch[{index, flush_position}].offset_1 = CacheContext.offset;
                    ram_switch[{index, flush_position}].strobe = 4'b1111;
                    ram_switch[{index, flush_position}].wdata = icresp.data;
                    if (in_ireq.valid && CacheContext.req.addr[31:6] == in_ireq.addr[31:6]) begin
                        ram_switch[{index, flush_position}].offset_2 = in_ireq.addr[5:2];
                        unique if (CacheContext.offset == in_ireq.addr[5:2]) begin
                            in_iresp.addr_ok = 1;
                            in_iresp.data_ok = 1;
                            in_iresp.data_1 = icresp.data;
                            in_iresp.valid_2 = '0;
                            in_iresp.data_2 = '0;
                        end
                        else if (CacheContext.offset > in_ireq.addr[5:2]) begin
                            in_iresp.addr_ok = 1;
                            in_iresp.data_ok = 1;
                            in_iresp.data_1 = ram_rdata_2[{index, flush_position}];
                            in_iresp.valid_2 = '0;
                            in_iresp.data_2 = '0;
                        end
                        else begin
                            in_iresp.addr_ok = 0;
                            in_iresp.data_ok = 0;
                            in_iresp.data_1 = '0;
                            in_iresp.valid_2 = '0;
                            in_iresp.data_2 = '0;
                        end
                    end
                    else begin
                        ram_switch[{index, flush_position}].offset_2 = '0;
                    end
                    if (CacheContext.offset == 4'hf) begin // !icresp.last
                        cacheContext.stat = SC_IDLE;
                        cacheContext.offset = '0;
                        cacheContext.cache_set_meta[index].cache_line_meta[flush_position].tag = tag;
                        cacheContext.cache_set_meta[index].cache_line_meta[flush_position].valid = 1;
                        cacheContext.cache_set_meta[index].cache_line_meta[flush_position].dirty = 0;
                        cacheContext.cache_set_meta[index].flush_position = CacheContext.cache_set_meta[index].flush_position + 1;
                    end
                    else begin
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                end
            end
            default: begin
                // pass
            end
        endcase
    end

    always_ff @(posedge clk)
        if (~resetn)
            CacheContext <= ICACHE_CONTEXT_RESET;
        else
            CacheContext <= cacheContext;

endmodule
