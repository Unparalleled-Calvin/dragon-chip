`include "common.svh"
`include "mycpu/mycpu.svh"

module DCache (
    input logic clk, resetn,
    
    input  dbus_req_t  dreq,
    output dbus_resp_t dresp,
    
    output cbus_req_t  dcreq,
    input  cbus_resp_t dcresp
);
    dbus_req_t  in_dreq;
    dbus_resp_t in_dresp;
    assign in_dreq = dreq;
    assign dresp = in_dresp;
    /*
    SkidBuffer SkidBuffer_inst(.m_req(dreq), 
                               .m_resp(dresp),
                               .s_req(in_dreq),
                               .s_resp(in_dresp),
                               .*);
                               */
    cache_state_t Cache_state /* verilator public_flat_rd */;
    assign Cache_state = CacheContext.stat;
    
    cache_context_t CacheContext, cacheContext;
    
    tag_t tag;
    index_t index;
    offset_t offset;
    i2 offset_byte;
    strobe_t strobe_i4;
    
    always_comb begin
        if (CacheContext.stat == SC_IDLE) begin
            {tag, index, offset, offset_byte} = in_dreq.addr;
            strobe_i4 = in_dreq.strobe;
        end
        else begin
            {tag, index, offset, offset_byte} = CacheContext.req.addr;
            strobe_i4 = CacheContext.req.strobe;
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
    
    ram_switch_t [cache_set_size * cache_line_size - 1: 0] ram_switch;
    word_t       [cache_set_size * cache_line_size - 1: 0] ram_rdata;
    
    
    generate
        for (genvar i = 0; i < cache_set_size * cache_line_size; i++) begin : LUTRAM_Initial
            LUTRAM #(.NUM_BYTES(64)) ram_inst (
                .clk(clk), .en(ram_switch[i].en),
                .addr(ram_switch[i].offset),
                .strobe(ram_switch[i].strobe),
                .wdata(ram_switch[i].wdata),
                .rdata(ram_rdata[i])
            );
        end
    endgenerate
    
    always_comb begin 
        cacheContext = CacheContext;
        in_dresp = '0;
        dcreq = '0;
        write_in_data = '0;
        ram_switch = '0;
        unique case (CacheContext.stat)
            SC_IDLE: begin
                if (in_dreq.valid) begin
                    if (cached) begin
                        // 写入到缓存，并返回写入前的值
                        ram_switch[{index, target_position}].en = 1;
                        ram_switch[{index, target_position}].offset = offset;
                        ram_switch[{index, target_position}].strobe = strobe_i4;
                        ram_switch[{index, target_position}].wdata = in_dreq.data;
                        
                        in_dresp.data = ram_rdata[{index, target_position}];
                        in_dresp.addr_ok = 1;
                        in_dresp.data_ok = 1;
                        if (|in_dreq.strobe) begin
                            // TODO 判断值是否相同
                            cacheContext.cache_set_meta[index].cache_line_meta[target_position].dirty = 1;
                        end
                    end
                    else begin
                        in_dresp.data = '0;
                        in_dresp.addr_ok = 1; // 1
                        in_dresp.data_ok = 0;
                        cacheContext.offset = '0;
                        cacheContext.req = in_dreq;
                        if (cacheContext.cache_set_meta[index].cache_line_meta[flush_position].dirty) begin
                            // 需要在缓存中腾出一个位置
                            // 将缓存中的目标位置写回内存中
                            cacheContext.stat = SC_FLUSH;
                        end
                        else begin
                            // 从内存中读取数据存入缓存
                            cacheContext.stat = SC_FETCH;
                        end
                    end
                end
            end
            SC_FETCH: begin
                dcreq.valid = 1;
                dcreq.is_write = 0;
                dcreq.size = MSIZE4;
                dcreq.addr = {CacheContext.req.addr[31:6], 6'b0};
                dcreq.strobe = '0;
                dcreq.data = '0;
                dcreq.len = MLEN16;
                in_dresp = '0;
                if (dcresp.ready) begin
                    ram_switch[{index, flush_position}].en = 1;
                    ram_switch[{index, flush_position}].offset = CacheContext.offset;
                    ram_switch[{index, flush_position}].strobe = 4'b1111;
                    ram_switch[{index, flush_position}].wdata = dcresp.data;
                    if (CacheContext.offset == 4'hf) begin // !dcresp.last
                        cacheContext.stat = SC_READY;
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
            SC_FLUSH: begin
                ram_switch[{index, flush_position}].en = 1;
                ram_switch[{index, flush_position}].offset = CacheContext.offset;
                ram_switch[{index, flush_position}].strobe = '0;
                ram_switch[{index, flush_position}].wdata = '0;
                
                dcreq.valid = 1;
                dcreq.is_write = 1;
                dcreq.size = MSIZE4;
                dcreq.addr = flush_addr;
                dcreq.strobe = 4'b1111;
                dcreq.data = ram_rdata[{index, flush_position}];
                dcreq.len = MLEN16;
                if (dcresp.ready) begin
                    if (CacheContext.offset != 4'hf) begin // !dcresp.last
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                    else begin
                        cacheContext.stat = SC_FETCH;
                        cacheContext.offset = '0;
                    end
                end
            end
            SC_READY: begin
                ram_switch[{index, target_position}].en = 1;
                ram_switch[{index, target_position}].offset = offset;
                ram_switch[{index, target_position}].strobe = strobe_i4;
                ram_switch[{index, target_position}].wdata = CacheContext.req.data;
                
                in_dresp.addr_ok = 0;
                in_dresp.data_ok = 1;
                in_dresp.data = ram_rdata[{index, target_position}];
                cacheContext.stat = SC_IDLE;
                cacheContext.offset = '0;
                cacheContext.req = '0;
                if (|CacheContext.req.strobe) begin
                    cacheContext.cache_set_meta[index].cache_line_meta[target_position].dirty = 1;
                end
            end
            default: begin
                // pass
            end
        endcase
    end

    always_ff @(posedge clk)
        if (~resetn)
            CacheContext <= CACHE_CONTEXT_RESET;
        else
            CacheContext <= cacheContext;

endmodule
