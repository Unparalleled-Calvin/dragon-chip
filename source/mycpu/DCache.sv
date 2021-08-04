`include "common.svh"
`include "mycpu/mycpu.svh"

module DCache (
    input logic clk, resetn,
    
    input  dbus_req_t [1:0] dreq,
    output dbus_resp_t [1:0] dresp,
    
    output cbus_req_t dcreq,
    input  cbus_resp_t dcresp
);
 


    dbus_req_t [1:0] in_dreq;
    dbus_resp_t [1:0] in_dresp;
    assign in_dreq = dreq;
    assign dresp = in_dresp;
//    SkidBuffer SkidBuffer_inst0(.m_req(dreq[0]), 
//                               .m_resp(dresp[0]),
//                               .s_req(in_dreq[0]),
//                               .s_resp(in_dresp[0]),
//                               .*);
//    SkidBuffer SkidBuffer_inst1(.m_req(dreq[1]), 
//                               .m_resp(dresp[1]),
//                               .s_req(in_dreq[1]),
//                               .s_resp(in_dresp[1]),
//                               .*);
    //changed, 4 is the size of the cache set
    ram_switch_t [cache_set_size * cacheline_words - 1: 0] ram_switch;
    word_t       [cache_set_size * cacheline_words - 1: 0] ram_rdata;

    logic [1:0] uncached;
    assign uncached[0] = in_dreq[0].addr[31:29] == 3'b101;
    assign uncached[1] = in_dreq[1].addr[31:29] == 3'b101;


    //use the lutram with 16 bytes, that is, 4 words
    generate
        for (genvar i = 0; i < cache_set_size * cacheline_words; i++) begin : LUTRAM_Initial
            LUTRAM #(.NUM_BYTES(16)) ram_inst (
                .clk(clk), .en(ram_switch[i].en),
                .addr(ram_switch[i].offset),
                .strobe(ram_switch[i].strobe),
                .wdata(ram_switch[i].wdata),
                .rdata(ram_rdata[i])
            );
        end
    endgenerate

    cache_state_t Cache_state /* verilator public_flat_rd */;
    assign Cache_state = CacheContext.stat;
    
    cache_context_t CacheContext, cacheContext;
    
    tag_t [2:0] tag;
    index_t [2:0] index;
    offset_t [2:0] offset;
    
    i2 [2:0] offset_byte;
    strobe_t [2:0] strobe_i4;
    //index[2],offset[2] 储存的是请求本身的offset,而不是正在操作的offset
    always_comb begin
        if (CacheContext.stat == SC_IDLE) begin
            {tag[0], index[0], offset[0], offset_byte[0]} = in_dreq[0].addr;
            strobe_i4[0] = in_dreq[0].strobe;
            {tag[1], index[1], offset[1], offset_byte[1]} = in_dreq[1].addr;
            strobe_i4[1] = in_dreq[1].strobe;
            {tag[2], index[2], offset[2], offset_byte[2]} = '0;
            strobe_i4[2] = '0;
        end
        else if (CacheContext.stat == SC_FETCH_IDLE || CacheContext.stat == SC_FLUSH_IDLE) begin
            {tag[0], index[0], offset[0], offset_byte[0]} = in_dreq[0].addr;
            strobe_i4[0] = in_dreq[0].strobe;
            {tag[1], index[1], offset[1], offset_byte[1]} = in_dreq[1].addr;
            strobe_i4[1] = in_dreq[1].strobe;
            {tag[2], index[2], offset[2], offset_byte[2]} = CacheContext.busy_req.addr;
            strobe_i4[2] = CacheContext.busy_req.strobe;
        end
        else begin
            {tag[0], index[0], offset[0], offset_byte[0]} = CacheContext.req[0].addr;
            strobe_i4[0] = CacheContext.req[0].strobe;
            {tag[1], index[1], offset[1], offset_byte[1]} = CacheContext.req[1].addr;
            strobe_i4[1] = CacheContext.req[1].strobe;
            {tag[2], index[2], offset[2], offset_byte[2]} = CacheContext.busy_req.addr;
            strobe_i4[2] = CacheContext.busy_req.strobe;
        end
    end
    logic [1:0] write_en;
    assign write_en[0] = |strobe_i4[0];
    assign write_en[1] = |strobe_i4[1]; 
    logic [1:0] cached;
    position_t [1:0] target_position;
    cache_set_meta_t target_cache_set_meta;

    always_comb begin
        
        for (int i = 0; i < 2; i++) begin
            target_cache_set_meta = CacheContext.cache_set_meta[index[i]];
            unique if (target_cache_set_meta.cache_line_meta[0].valid && target_cache_set_meta.cache_line_meta[0].tag == tag[i]) begin
                cached[i] = 1;
                target_position[i] = 0;
            end
            else if (target_cache_set_meta.cache_line_meta[1].valid && target_cache_set_meta.cache_line_meta[1].tag == tag[i]) begin
                cached[i] = 1;
                target_position[i] = 1;
            end
            else if (target_cache_set_meta.cache_line_meta[2].valid && target_cache_set_meta.cache_line_meta[2].tag == tag[i]) begin
                cached[i] = 1;
                target_position[i] = 2;
            end
            else if (target_cache_set_meta.cache_line_meta[3].valid && target_cache_set_meta.cache_line_meta[3].tag == tag[i]) begin
                cached[i] = 1;
                target_position[i] = 3;
            end
            else begin
                cached[i] = 0;
                target_position[i] = 0;
            end
        end
    end
    
    tag_t flush_tag;
    position_t [2:0] flush_position;
    cache_line_meta_t flush_cache_line_meta;
    addr_t flush_addr;
    always_comb begin
        flush_position = '0;
        flush_cache_line_meta = '0;
        flush_tag             = '0;
        flush_addr            = '0;
        if (CacheContext.stat == SC_IDLE) begin
            for (int i = 0; i < 2; i++) begin
                flush_position[i] = CacheContext.cache_set_meta[index[i]].flush_position;
            end
        end
        else begin
            for (int i = 0; i < 3; i++) begin
                flush_position[i] = CacheContext.cache_set_meta[index[i]].flush_position;
                flush_cache_line_meta = CacheContext.cache_set_meta[index[i]].cache_line_meta[flush_position[i]];
                flush_tag             = flush_cache_line_meta.tag;
                flush_addr            = {flush_tag, index[i], 6'b0};
            end
            
        end
        
    end
    i4 busy_offset;
    logic busy_req_index, non_busy_req_index;
    assign busy_offset = CacheContext.offset;
    assign busy_req_index = CacheContext.busy_req_index;
    assign non_busy_req_index = ~CacheContext.busy_req_index;
    i2 [2:0] comp_reqs;
    i2 [1:0] manipu;
    assign manipu[0] = cached[0] == 1'b1 ? target_position[0] : flush_position[0];
    assign manipu[1] =  cached[1] == 1'b1 ? target_position[1] : flush_position[1];
    always_comb begin
        comp_reqs[0][0] = manipu[0] == manipu[1];
        comp_reqs[0][1] = offset[0] == offset[1];
        
        //以下两个是 请求 和 正在处理的那一行 的对比（而不是与正在处理的req的对比）
        comp_reqs[1][0] = manipu[0] == flush_position[2];
        comp_reqs[1][1] = offset[0] == busy_offset;

        comp_reqs[2][0] = manipu[1] == flush_position[2];   
        comp_reqs[2][1] = offset[1] == busy_offset;
    end

    always_comb begin 
        cacheContext = CacheContext;
        in_dresp = '0;
        dcreq = '0;
        /* verilator lint_off WIDTHCONCAT */
        ram_switch = '0;
        /* verilator lint_off WIDTHCONCAT */
        cacheContext.offset = '0;
        cacheContext.stat = SC_IDLE;
        cacheContext.resp = '0;
        unique case (CacheContext.stat)
            SC_IDLE: begin
                // 如果只有一个有效
                if (~in_dreq[0].valid && ~in_dreq[1].valid) begin
                    
                end
                else if (in_dreq[0].valid && ~in_dreq[1].valid) begin
                    if (uncached[0]) begin
                        cacheContext.busy_req_index = 1'b0;
                        cacheContext.busy_req = in_dreq[0];
                        
                        cacheContext.stat = SC_UNCACHED;
                        cacheContext.req = in_dreq;
                    end
                    else if (cached[0]) begin
                        `RW_CACHE(1'b0); 
                        cacheContext.stat = SC_IDLE;
                    end
                    else begin
                        in_dresp[0].data = '0;
                        in_dresp[0].addr_ok = 1'b1; // 1
                        in_dresp[0].data_ok = 0;
                        cacheContext.offset = '0;
                        if (cacheContext.cache_set_meta[index[0]].cache_line_meta[flush_position[0]].dirty) begin
                            if (write_en[0] == 1'b1) begin
                                cacheContext.stat = SC_FLUSH_IDLE; 
                            end
                            else 
                                cacheContext.stat = SC_FLUSH;
                        end
                        else begin
                            if (write_en[0] == 1'b1) begin
                                cacheContext.stat = SC_FETCH_IDLE;
                            end
                            else begin
                                cacheContext.stat = SC_FETCH;
                            end
                        end
                        cacheContext.busy_req = in_dreq[0];
                        cacheContext.req = in_dreq;
                        cacheContext.busy_req_index = 1'b0;
                    end
                end
                else if (in_dreq[1].valid && ~in_dreq[0].valid) begin
                    if (uncached[1]) begin
                        cacheContext.busy_req_index = 1'b1;
                        cacheContext.busy_req = in_dreq[1];
                        cacheContext.stat = SC_UNCACHED;
                        cacheContext.req = in_dreq;
                    end
                    else if (cached[1]) begin
                        `RW_CACHE(1'b1); 
                        ram_switch[{index[1], offset[1]}].offset = target_position[1];
                        cacheContext.stat = SC_IDLE;
                    end
                    else begin
                        in_dresp[1].data = '0;
                        in_dresp[1].addr_ok = 1'b1; // 1
                        in_dresp[1].data_ok = 0;
                        cacheContext.offset = '0;
                        if (cacheContext.cache_set_meta[index[1]].cache_line_meta[flush_position[1]].dirty) begin
                            if (write_en[1] == 1'b1) begin
                                cacheContext.stat = SC_FLUSH_IDLE;
                            end
                            else begin
                                cacheContext.stat = SC_FLUSH;
                            end
                        end
                        else begin
                            if (write_en[1] == 1'b1) begin
                                cacheContext.stat = SC_FETCH_IDLE;
                            end
                            else begin
                                cacheContext.stat = SC_FETCH;
                            end
                        end 
                        cacheContext.busy_req = in_dreq[1];
                        cacheContext.req = in_dreq;
                        cacheContext.busy_req_index = 1'b1;
                    end
                end
                //如果两个都有效
                else begin
                    if (uncached[0]) begin
                        cacheContext.busy_req_index = 1'b0;
                        cacheContext.busy_req = in_dreq[0];
                        cacheContext.stat = SC_UNCACHED;
                        cacheContext.req = in_dreq;
                    end
                    else if (uncached[1]) begin
                        cacheContext.busy_req_index = 1'b1;
                        cacheContext.busy_req = in_dreq[1];
                        cacheContext.stat = SC_UNCACHED;
                        cacheContext.req = in_dreq;
                    end
                     // 两个均命中
                    else if (cached[0] && cached[1]) begin
                        if (index[0] != index[1]) begin
                            for (int i = 0; i < 2; i++) begin
                                `RW_CACHE(i);  
                            end
                            cacheContext.stat = SC_IDLE;
                            
                        end
                        else begin
                            unique case (comp_reqs[0])
                               // 如果两个的行(offset)不同，列(target_pos)不同
                                // 如果他们行(offset)不同，列(target_pos)同
                                2'b00, 2'b01: begin
                                    for (int i = 0; i < 2; i++) begin
                                        `RW_CACHE(i);  
                                    end
                                    cacheContext.stat = SC_IDLE; 
                                end
                                // 如果他们的行相同，列不同
                                2'b10: begin
                                    `RW_CACHE(1'b0);    
                                end
                                // 如果他们的index和offset target_pos均相同
                                2'b11: begin
                                    // if the second req is to write, then do parallelly.
                                    // the second one will overwrite the first one.
                                    if (write_en[1] == 1'b1 && write_en[0] == 1'b1) begin
                                        
                                        `RW_CACHE(1'b0);  
                                        for (int j = 0; j < 4; j++) begin
                                            if (strobe_i4[1][j] == 1'b1) begin
                                                ram_switch[{index[1], offset[1]}].wdata[(((j + 1) << 3) - 1)-:8] = in_dreq[1].data[(((j + 1) << 3) - 1)-:8];
                                            end
                                        end
                                      
                                        ram_switch[{index[0], offset[0]}].strobe = (strobe_i4[0] | strobe_i4[1]);
                                        cacheContext.stat = SC_IDLE;
                                        
                                    end
                                    else if ((write_en[0] == 1'b1)) begin
                                        // if the reqs manipulate the same position, then do parallelly
                                            `RW_CACHE(1'b0);
                                            in_dresp[1].data = ram_rdata[{index[1], offset[1]}];
                                            
                                            for (int j = 0; j < 4; j++) begin
                                                if (strobe_i4[0][j] == 1'b1) begin
                                                    in_dresp[1].data[(((j + 1) << 3) - 1)-:8] = in_dreq[0].data[(((j + 1) << 3) - 1)-:8];
                                                    
                                                end
                                            end    
                                            
                                            in_dresp[1].addr_ok = 1'b1;
                                            in_dresp[1].data_ok = 1'b1;
                                            
                                            
                                            
                                            cacheContext.stat = SC_IDLE;
                                            
                                        end
                                    // both reqs are to read
                                    else begin
                                        for (int i = 0; i < 2; i++) begin
                                            `RW_CACHE(i);    
                                        end
                                        
                                        cacheContext.stat = SC_IDLE;
                                    end
                                end  
                                default: begin
                                    
                                end    
                            endcase
                        end
                        
                    end
                    else if (cached[0] && (~cached[1])) begin
                        `RW_CACHE(1'b0);   

                        in_dresp[1].data = '0;
                        in_dresp[1].addr_ok = 1'b1; // 1
                        in_dresp[1].data_ok = 0;
                        
                        
                        
                        cacheContext.offset = '0;
                        if (cacheContext.cache_set_meta[index[1]].cache_line_meta[flush_position[1]].dirty) begin
                            if (write_en[1] == 1'b1) begin
                                cacheContext.stat = SC_FLUSH_IDLE;
                                
                            end
                            else
                                cacheContext.stat = SC_FLUSH;
                        end
                        else begin
                            if (write_en[1] == 1'b1) begin
                                cacheContext.stat = SC_FETCH_IDLE;
                                
                            end
                            else
                                cacheContext.stat = SC_FETCH;
                        end
                        cacheContext.busy_req = in_dreq[1];
                        cacheContext.req = in_dreq;
                        cacheContext.busy_req_index = 1'b1;
                    end
                    //命中第二个 
                    else if (~cached[0] && cached[1]) begin
                        if (index[0] != index[1] || comp_reqs[0] == 2'b00 || comp_reqs[0] == 2'b10) begin
                            `RW_CACHE(1'b1);   
                            in_dresp[0].data = '0;
                            in_dresp[0].addr_ok = 1'b1; // 1
                            in_dresp[0].data_ok = 0;
                            
                            
                            
                            cacheContext.offset = '0;
                            if (cacheContext.cache_set_meta[index[0]].cache_line_meta[flush_position[0]].dirty) begin
                            if (write_en[0] == 1'b1) begin
                                cacheContext.stat = SC_FLUSH_IDLE;
                                
                            end
                            else
                                cacheContext.stat = SC_FLUSH;
                            end
                            else begin
                                if (write_en[0] == 1'b1) begin
                                    cacheContext.stat = SC_FETCH_IDLE;
                                    
                                end
                                else
                                    cacheContext.stat = SC_FETCH;
                            end
                        end
                        else begin
                            for (int i = 0; i < 2; i++) begin
                                in_dresp[i].data = '0;
                                in_dresp[i].addr_ok = 1'b0; // 1
                                in_dresp[i].data_ok = 0;
                                
                                
                                
                                cacheContext.offset = '0;
                            end
                            if (cacheContext.cache_set_meta[index[0]].cache_line_meta[flush_position[0]].dirty) begin
                                cacheContext.stat = SC_FLUSH;
                            end
                            else begin
                                cacheContext.stat = SC_FETCH;
                            end
                        end
             
                        cacheContext.busy_req = in_dreq[0];
                        cacheContext.req = in_dreq;
                        cacheContext.busy_req_index = 1'b0;
                    end
                    // 两个都不命中
                    else begin
                        for (int i = 0; i < 2; i++) begin
                            in_dresp[i].data = '0;
                            in_dresp[i].addr_ok = 1'b0; // 1
                            in_dresp[i].data_ok = 0;
                            
                            
                            
                            cacheContext.offset = '0;
                        end
                        if (cacheContext.cache_set_meta[index[0]].cache_line_meta[flush_position[0]].dirty) begin
                            cacheContext.stat = SC_FLUSH;
                        end
                        else begin
                            cacheContext.stat = SC_FETCH;
                        end
                        cacheContext.busy_req = in_dreq[0];
                        cacheContext.req = in_dreq;
                        cacheContext.busy_req_index = 1'b0;
                    end
                end 
            end
            SC_UNCACHED: begin
                dcreq.valid    = 1'b1;
                dcreq.is_write = (strobe_i4[2] != 4'b0);
                dcreq.size     = MSIZE4;
                dcreq.addr = CacheContext.busy_req.addr;
                dcreq.len      = MLEN1;
                dcreq.strobe = strobe_i4[2];
                dcreq.data = CacheContext.busy_req.data;
                cacheContext.stat = SC_UNCACHED;
                if (dcresp.ready) begin
                    for (int q = 0; q < 2; q++) begin
                        if (q[0] == busy_req_index) begin
                            in_dresp[q].addr_ok = 1'b1;
                            in_dresp[q].data_ok = 1'b1;
                            in_dresp[q].data = dcresp.data;
                            if (in_dreq[1 - q].valid == 1'b1) begin
                                if (uncached[1 - q]) begin
                                    cacheContext.busy_req_index = non_busy_req_index;
                                    cacheContext.busy_req = in_dreq[1 - q];
                                    cacheContext.stat = SC_UNCACHED;
                                    cacheContext.req = in_dreq;
                                    
                                end
                                else if (cached[1 - q]) begin
                                    for (int i = 0; i < 2; i++) begin
                                        if (i[0] == (non_busy_req_index)) begin
                                            `RW_CACHE(i); 
                                        end
                                    end
                                    
                                    
                                    cacheContext.stat = SC_IDLE;
                                    cacheContext.offset = '0; 
                                end
                                else begin
                                    in_dresp[1 - q].data = '0;
                                    in_dresp[1 - q].addr_ok = 1'b1; // 1
                                    in_dresp[1 - q].data_ok = 0;
                                    
                                    
                                    
                                    cacheContext.offset = '0;
                                    if (cacheContext.cache_set_meta[index[1 - q]].cache_line_meta[flush_position[1 - q]].dirty) begin
                                        if (write_en[1 - q] == 1'b1) begin
                                            cacheContext.stat = SC_FLUSH_IDLE;
                                            
                                        end
                                        else
                                            cacheContext.stat = SC_FLUSH;
                                    end
                                    else begin
                                        if (write_en[1 - q] == 1'b1) begin
                                            cacheContext.stat = SC_FETCH_IDLE;
                                            
                                        end
                                        else
                                            cacheContext.stat = SC_FETCH;
                                    end
                                    cacheContext.busy_req = in_dreq[1 - q];
                                    cacheContext.req = in_dreq;
                                    cacheContext.busy_req_index = non_busy_req_index;
                                end
                            end
                            else begin
                                cacheContext.stat = SC_IDLE;
                                cacheContext.offset = '0;
                                
                            end
                        end
                    end
                    
                end
                else begin
                    cacheContext.stat = SC_UNCACHED;
                end            
            end
            SC_FETCH: begin
                dcreq.valid = 1;
                dcreq.is_write = 0;
                dcreq.size = MSIZE4;
                dcreq.addr = {CacheContext.busy_req.addr[31:6], 6'b0};
                dcreq.strobe = '0;
                dcreq.data = '0;
                dcreq.len = MLEN16;
                cacheContext.stat = SC_FETCH;
            
                
                if (dcresp.ready) begin
                    ram_switch[{index[2], busy_offset}].en = 1;
               
                    ram_switch[{index[2], busy_offset}].offset = flush_position[2];
                    ram_switch[{index[2], busy_offset}].strobe = 4'b1111;
                    ram_switch[{index[2], busy_offset}].wdata = dcresp.data;
                    if (busy_offset == 4'b0) begin
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].tag =  tag[2];
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].dirty = 0;
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].valid = 1;
                    end
                    //
                    if (busy_offset == offset[2]) begin
                        for (int q = 0; q < 2; q++) begin
                            if (q[0] == busy_req_index) begin
                                in_dresp[q].addr_ok = 1'b1;
                                in_dresp[q].data_ok = 1'b1;
                                in_dresp[q].data = dcresp.data;
                                if (|strobe_i4[2]) begin
                                    for (int i = 0; i < 4; i++) begin
                                        if (strobe_i4[2][i] == 1'b1) begin
                                            ram_switch[{index[2], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                        end
                                    end
                                
                                    cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].dirty = 1;
                                end
                                else begin
                                    ram_switch[{index[2], busy_offset}].wdata = dcresp.data;
                                end
                                if (CacheContext.req[1 - q].valid == 1'b1) 
                                    cacheContext.stat = SC_FETCH_SEC;
                                else 
                                    cacheContext.stat = SC_FETCH_IDLE;
                            end
                        end
                        
                    end
                    if (busy_offset == 4'hf) begin // !dcresp.last
                        for (int q = 0; q < 2; q++) begin
                            if (q[0] == non_busy_req_index) begin
                                if (CacheContext.req[q].valid == 1'b1) begin
                                    if (cached[q] == 1'b1) begin
                                        cacheContext.stat = SC_IDLE;
                                    end
                                    else begin
                                        if (cacheContext.cache_set_meta[index[q]].cache_line_meta[flush_position[q]].dirty) begin
                                        if (write_en[q] == 1'b1) begin
                                            cacheContext.stat = SC_FLUSH_IDLE;
                                        end
                                        else
                                            cacheContext.stat = SC_FLUSH;
                                        end
                                        else begin
                                            if (write_en[q] == 1'b1) begin
                                                cacheContext.stat = SC_FETCH_IDLE;
                                            end
                                            else 
                                                cacheContext.stat = SC_FETCH;
                                        end
                                        cacheContext.busy_req = in_dreq[q];
                                        cacheContext.req = in_dreq;
                                        cacheContext.busy_req_index = non_busy_req_index;
                                        cacheContext.offset = '0;
                                    end
                                end
                                else begin
                                    cacheContext.stat = SC_IDLE; 
                                end
                            end
                        end
                        cacheContext.offset = '0;
                        cacheContext.cache_set_meta[index[2]].flush_position = CacheContext.cache_set_meta[index[2]].flush_position + 1;
                    end
                    else begin
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                end
            end
            SC_FETCH_SEC: begin
                dcreq.valid = 1;
                dcreq.is_write = 0;
                dcreq.size = MSIZE4;
                dcreq.addr = {CacheContext.busy_req.addr[31:6], 6'b0};
                dcreq.strobe = '0;
                dcreq.data = '0;
                dcreq.len = MLEN16;
                cacheContext.stat = SC_FETCH_SEC;
      
                if (dcresp.ready) begin
                    ram_switch[{index[2], busy_offset}].en = 1;
                    //这里flush_postion用1、0都行
                    ram_switch[{index[2], busy_offset}].offset = flush_position[2];
                    ram_switch[{index[2], busy_offset}].strobe = 4'b1111;
                    ram_switch[{index[2], busy_offset}].wdata = dcresp.data;
                    for (int q = 0; q < 2; q++) begin
                        if (q[0] == non_busy_req_index) begin
                            if (cached[q] == 1'b1) begin
                                if (busy_offset >= offset[q]) begin
                                    if (busy_offset == offset[q]) begin
                                        in_dresp[q].data = dcresp.data;
                                        in_dresp[q].data_ok = 1'b1;
                                        in_dresp[q].addr_ok = 1'b1;
                                        
                                        
                                        
                                        if (|strobe_i4[q]) begin
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[q][i] == 1'b1) begin
                                                    ram_switch[{index[q], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = in_dreq[q].data[(((i + 1) << 3) - 1)-:8];
                                                end
                                            end
                                        
                                            cacheContext.cache_set_meta[index[q]].cache_line_meta[target_position[q]].dirty = 1;
                                        end
                                        else begin
                                            ram_switch[{index[q], offset[q]}].wdata = dcresp.data;
                                        end
                                    end
                                    else  begin
                                        for (int i = 0; i < 2; i++) begin
                                            if (i[0] == (non_busy_req_index)) begin
                                                `RW_CACHE(i); 
                                            end
                                        end 
                                        
                                    end
                                    cacheContext.stat = SC_FETCH_IDLE;
                                    
                                end
                                else 
                                    cacheContext.stat = SC_FETCH_SEC;  
                            end
                            else begin
                                cacheContext.stat = SC_FETCH_SEC;
                            end
                        end
                    end
                    
                    if (CacheContext.offset == 4'hf) begin // !dcresp.last
                        cacheContext.stat = SC_IDLE;
                        cacheContext.offset = '0;
                        // cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].tag = tag[2];
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].valid = 1;
                        // cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].dirty = 0;
                        cacheContext.cache_set_meta[index[2]].flush_position = CacheContext.cache_set_meta[index[2]].flush_position + 1;
                        for (int q = 0; q < 2; q++) begin
                            if (q[0] == non_busy_req_index) begin
                                if (CacheContext.req[q].valid == 1'b1 && cached[q] == 1'b0) begin
                                    if (cacheContext.cache_set_meta[index[q]].cache_line_meta[flush_position[q]].dirty) begin
                                        if (write_en[q] == 1'b1) begin
                                            cacheContext.stat = SC_FLUSH_IDLE;
                                            
                                        end
                                        else 
                                            cacheContext.stat = SC_FLUSH;
                                    end
                                    else begin
                                        if (write_en[q] == 1'b1) begin
                                            cacheContext.stat = SC_FETCH_IDLE;
                                            
                                        end
                                        else 
                                            cacheContext.stat = SC_FETCH;
                                    end
                                    cacheContext.busy_req = in_dreq[q];
                                    cacheContext.req = in_dreq;
                                    cacheContext.busy_req_index = non_busy_req_index;
                                    cacheContext.offset = '0;
                                end  
                            end
                        end
                         
                    end
                    else begin
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                end
            end
            SC_FLUSH_IDLE: begin
                ram_switch[{index[2], busy_offset}].en = 1;
                ram_switch[{index[2], busy_offset}].offset = flush_position[2];
                ram_switch[{index[2], busy_offset}].strobe = '0;
                ram_switch[{index[2], busy_offset}].wdata = '0;
                
                dcreq.valid = 1;
                dcreq.is_write = 1;
                dcreq.size = MSIZE4;
                dcreq.addr = flush_addr;
                dcreq.strobe = 4'b1111;
                dcreq.data = ram_rdata[{index[2], busy_offset}];
                dcreq.len = MLEN16;
                cacheContext.stat = SC_FLUSH_IDLE;
                if (dcresp.ready) begin
                    if (busy_offset != 4'hf) begin // !dcresp.last
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                    else begin
                        cacheContext.stat = SC_FETCH_IDLE;
                        cacheContext.offset = '0;
                    end
                end
                if (in_dreq[0].valid && cached[0] && (~in_dreq[1].valid)) begin
                    if (index[0] == index[2]) begin
                        unique case (comp_reqs[1])
                            2'b00: begin
                                `RW_CACHE(1'b0);   
                                
                            end
                            //here
                            2'b01, 2'b11: begin
                                if (write_en[0] == 1'b0) begin
                                    `RW_CACHE(1'b0); 
                                    if (CacheContext.busy_req.addr[31:2] == in_dreq[0].addr[31:2] && (|strobe_i4[2])) begin
                                        for (int i = 0; i < 4; i++) begin
                                            if (strobe_i4[2][i] == 1'b1) begin
                                                in_dresp[0].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                
                                            end
                                        end
                                    end
                                end
                            end  
                            2'b10: begin end
                            default: begin end
                        endcase
                    end
                    else begin
                        `RW_CACHE(1'b0);  
                        
                    end
                end
                else if (in_dreq[1].valid && cached[1] && (~in_dreq[0].valid)) begin
                    if (index[1] == index[2]) begin
                        unique case (comp_reqs[2])
                            2'b00: begin
                                `RW_CACHE(1'b1);   
                            end
                            //here
                            2'b01, 2'b11: begin
                                if (write_en[1] == 1'b0) begin
                                    `RW_CACHE(1'b1); 
                                    if (CacheContext.busy_req.addr[31:2] == in_dreq[1].addr[31:2] && (|strobe_i4[2])) begin
                                        for (int i = 0; i < 4; i++) begin
                                            if (strobe_i4[2][i] == 1'b1) begin
                                                in_dresp[1].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                
                                            end
                                        end
                                    end
                                end
                            end  
                            2'b10: begin end
                            default: begin end
                        endcase
                    end
                    else begin
                        `RW_CACHE(1'b1);   
                    end
                end
                else if ( (in_dreq[0].valid & cached[0] & in_dreq[1].valid & cached[1]) == 1'b1) begin
                    if (index[0] != index[1] || comp_reqs[0] != 2'b10) begin
                        if (index[0] == index[2]) begin
                            unique case (comp_reqs[1])
                            2'b00: begin
                                `RW_CACHE(1'b0);   
                            end
                            //here
                            2'b01, 2'b11: begin
                                if (write_en[0] == 1'b0) begin
                                    `RW_CACHE(1'b0); 
                                    if (CacheContext.busy_req.addr[31:2] == in_dreq[0].addr[31:2] && (|strobe_i4[2])) begin
                                        for (int i = 0; i < 4; i++) begin
                                            if (strobe_i4[2][i] == 1'b1) begin
                                                in_dresp[0].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                
                                            end
                                        end
                                    end
                                end
                            end  
                            2'b10: begin end
                            default: begin end
                        endcase
                        end
                        else begin
                            `RW_CACHE(1'b0);   
                        end
                        if (index[1] == index[2]) begin
                            unique case (comp_reqs[2])
                            2'b00: begin
                                `RW_CACHE(1'b1);   
                            end
                            //here
                            2'b01, 2'b11: begin
                                if (write_en[1] == 1'b0) begin
                                    `RW_CACHE(1'b1); 
                                    if (CacheContext.busy_req.addr[31:2] == in_dreq[1].addr[31:2] && (|strobe_i4[2])) begin
                                        for (int i = 0; i < 4; i++) begin
                                            if (strobe_i4[2][i] == 1'b1) begin
                                                in_dresp[1].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                
                                            end
                                        end
                                    end
                                end
                            end  
                            2'b10: begin end
                            default: begin end
                        endcase
                        end
                        else begin
                            `RW_CACHE(1'b1);
                        end
                    end
                    else begin
                        if (index[0] == index[2]) begin
                            unique case (comp_reqs[1])
                            2'b00: begin
                                `RW_CACHE(1'b0);   
                            end
                            //here
                            2'b01, 2'b11: begin
                                if (write_en[0] == 1'b0) begin
                                    `RW_CACHE(1'b0); 
                                    if (CacheContext.busy_req.addr[31:2] == in_dreq[0].addr[31:2] && (|strobe_i4[2])) begin
                                        for (int i = 0; i < 4; i++) begin
                                            if (strobe_i4[2][i] == 1'b1) begin
                                                in_dresp[0].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                
                                            end
                                        end
                                    end
                                end
                            end  
                            2'b10: begin end
                            default: begin end
                        endcase
                        end
                        else begin
                            `RW_CACHE(1'b0);   
                        end
                    end    
                end
            end
            // 进入这个状态的，要么是即将write的req，要么是已经做完了的req
            SC_FETCH_IDLE: begin
                dcreq.valid = 1;
                dcreq.is_write = 0;
                dcreq.size = MSIZE4;
                dcreq.addr = {CacheContext.busy_req.addr[31:6], 6'b0};
                dcreq.strobe = '0;
                dcreq.data = '0;
                dcreq.len = MLEN16;
                cacheContext.stat = SC_FETCH_IDLE;
           
                if (dcresp.ready) begin
                    ram_switch[{index[2], busy_offset}].en = 1;
                    ram_switch[{index[2], busy_offset}].offset = flush_position[2];
                    ram_switch[{index[2], busy_offset}].strobe = 4'b1111;
                    ram_switch[{index[2], busy_offset}].wdata = dcresp.data;
                    if (busy_offset == 4'b0) begin
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].tag =  tag[2];
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].dirty = 0;
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].valid = 1;
                    end
                    if (busy_offset == offset[2] && (|strobe_i4[2])) begin
                        for (int i = 0; i < 4; i++) begin
                            if (strobe_i4[2][i] == 1'b1) begin
                                ram_switch[{index[2], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                            end
                        end
                   
                        cacheContext.cache_set_meta[index[2]].cache_line_meta[flush_position[2]].dirty = 1;
                    end
                   
                    //to do 把strobe因素加进去
                    //只有两种情况可以在这个时候让人离开：均命中
                    if (~in_dreq[0].valid && ~in_dreq[1].valid) begin
                        
                    end
                    else if (in_dreq[0].valid && cached[0] && (~in_dreq[1].valid)) begin
                        if (index[0] == index[2]) begin
                            unique case (comp_reqs[1])
                                2'b00: begin
                                   `RW_CACHE(1'b0);
                                   
                                end
                                2'b01, 2'b11: begin
                                    ram_switch[{index[0], offset[0]}].en = 1;
                                    ram_switch[{index[0], offset[0]}].offset = target_position[0];
                                    
                                    if (busy_offset == offset[0]) begin
                                        in_dresp[0].data_ok = 1'b1;
                                        in_dresp[0].addr_ok = 1'b1;
                                        if (|strobe_i4[0]) begin
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[0][i] == 1'b1) begin
                                                    ram_switch[{index[0], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = in_dreq[0].data[(((i + 1) << 3) - 1)-:8];
                                                end
                                            end
                                            cacheContext.cache_set_meta[index[0]].cache_line_meta[target_position[0]].dirty = 1;
                                        end
                                        if (CacheContext.busy_req.addr[31:2] == in_dreq[0].addr[31:2] && (|strobe_i4[2])) begin
                                            in_dresp[0].data = dcresp.data;
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[2][i] == 1'b1) begin
                                                    in_dresp[0].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                    
                                                end
                                            end
                                        end
                                        else begin
                                            in_dresp[0].data = dcresp.data;
                                        end
                                    end
                                    else if (busy_offset > offset[0]) begin
                                        `RW_CACHE(1'b0);
                                        
                                    end
                                end  
                                2'b10: begin end
                                default: begin end
                            endcase
                        end
                        else begin
                            `RW_CACHE(1'b0);
                            
                        end
                    end
                    // 两个都要离开时，把resp清空！
                    else if (in_dreq[1].valid && cached[1] && (~in_dreq[0].valid)) begin
                        if (index[1] == index[2]) begin
                            unique case (comp_reqs[2])
                                2'b00: begin
                                   `RW_CACHE(1'b1);   
                                   
                                end
                                2'b01, 2'b11: begin
                                    ram_switch[{index[1], offset[1]}].en = 1;
                                    ram_switch[{index[1], offset[1]}].offset = target_position[1];
                                    if (busy_offset == offset[1]) begin
                                        
                                        in_dresp[1].data_ok = 1'b1;
                                        in_dresp[1].addr_ok = 1'b1;
                                        
                                        
                                        
                                        if (|strobe_i4[1]) begin
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[1][i] == 1'b1) begin
                                                    ram_switch[{index[1], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = in_dreq[1].data[(((i + 1) << 3) - 1)-:8];
                                                end
                                            end
                                            cacheContext.cache_set_meta[index[1]].cache_line_meta[target_position[1]].dirty = 1;
                                        end
                                        if (CacheContext.busy_req.addr == in_dreq[1].addr && (|strobe_i4[2])) begin
                                            in_dresp[1].data = dcresp.data;
                                            
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[2][i] == 1'b1) begin
                                                    in_dresp[1].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                    
                                                end
                                            end
                                        end
                                        else begin
                                            in_dresp[1].data = dcresp.data;
                                            
                                        end
                                        
                                        
                                    end
                                    else if (busy_offset > offset[1]) begin
                                        `RW_CACHE(1'b1); 
                                        
                                    end
                                end  
                                2'b10: begin end
                                default: begin end
                            endcase
                        end
                        else begin
                            `RW_CACHE(1'b1); 
                            
                        end
                    end
                    else if (in_dreq[0].valid && cached[0] && in_dreq[1].valid && cached[1]) begin
                        if (index[0] != index[1] || comp_reqs[0] != 2'b10) begin
                            if (index[0] == index[2]) begin
                                unique case (comp_reqs[1])
                                2'b00: begin
                                   `RW_CACHE(1'b0); 
                                    
                                end
                                2'b01, 2'b11: begin
                                    ram_switch[{index[0], offset[0]}].en = 1;
                                    ram_switch[{index[0], offset[0]}].offset = target_position[0];
                                    
                                    if (busy_offset == offset[0]) begin
                                        in_dresp[0].data_ok = 1'b1;
                                        in_dresp[0].addr_ok = 1'b1;
                                        
                                        
                                        if (|strobe_i4[0]) begin
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[0][i] == 1'b1) begin
                                                    ram_switch[{index[0], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = in_dreq[0].data[(((i + 1) << 3) - 1)-:8];
                                                end
                                            end
                                            cacheContext.cache_set_meta[index[0]].cache_line_meta[target_position[0]].dirty = 1;
                                        end
                                        if (CacheContext.busy_req.addr[31:2] == in_dreq[0].addr[31:2] && (|strobe_i4[2])) begin
                                            in_dresp[0].data = dcresp.data;
                                            
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[2][i] == 1'b1) begin
                                                    in_dresp[0].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                    
                                                end
                                            end
                                        end
                                        else begin
                                            in_dresp[0].data = dcresp.data;
                                            
                                        end
                                        
                                    end
                                    else if (busy_offset > offset[0]) begin
                                        `RW_CACHE(1'b0);
                                         
                                    end
                                end  
                                2'b10: begin end
                                    default: begin end
                                endcase
                            end
                            else begin
                                `RW_CACHE(1'b0); 
                            end
                            if (index[1] == index[2]) begin
                                unique case (comp_reqs[2])
                                2'b00: begin
                                   `RW_CACHE(1'b1);   
                                   
                                end
                                2'b01, 2'b11: begin
                                    ram_switch[{index[1], offset[1]}].en = 1;
                                    ram_switch[{index[1], offset[1]}].offset = target_position[1];
                                    if (busy_offset == offset[1]) begin
                                        
                                        in_dresp[1].data_ok = 1'b1;
                                        in_dresp[1].addr_ok = 1'b1;
                                        
                                        
                                        
                                        if (|strobe_i4[1]) begin
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[1][i] == 1'b1) begin
                                                    ram_switch[{index[1], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = in_dreq[1].data[(((i + 1) << 3) - 1)-:8];
                                                end
                                            end
                                            cacheContext.cache_set_meta[index[1]].cache_line_meta[target_position[1]].dirty = 1;
                                        end
                                        if (CacheContext.busy_req.addr == in_dreq[1].addr && (|strobe_i4[2])) begin
                                            in_dresp[1].data = dcresp.data;
                                            
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[2][i] == 1'b1) begin
                                                    in_dresp[1].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                    
                                                end
                                            end
                                        end
                                        else begin
                                            in_dresp[1].data = dcresp.data;
                                            
                                        end
                                        
                                    end
                                    else if (busy_offset > offset[1]) begin
                                        `RW_CACHE(1'b1); 
                                        
                                    end
                                end  
                                2'b10: begin end
                                    default: begin end
                                endcase
                            end
                            else begin
                                `RW_CACHE(1'b1); 
                            end
                        end 
                        else begin
                            if (index[0] == index[2]) begin
                                unique case (comp_reqs[1])
                                2'b00: begin
                                   `RW_CACHE(1'b0); 
                                    
                                end
                                2'b01, 2'b11: begin
                                    ram_switch[{index[0], offset[0]}].en = 1;
                                    ram_switch[{index[0], offset[0]}].offset = target_position[0];
                                    
                                    if (busy_offset == offset[0]) begin
                                        in_dresp[0].data_ok = 1'b1;
                                        in_dresp[0].addr_ok = 1'b1;
                                        
                                        
                                        if (|strobe_i4[0]) begin
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[0][i] == 1'b1) begin
                                                    ram_switch[{index[0], busy_offset}].wdata[(((i + 1) << 3) - 1)-:8] = in_dreq[0].data[(((i + 1) << 3) - 1)-:8];
                                                end
                                            end
                                            cacheContext.cache_set_meta[index[0]].cache_line_meta[target_position[0]].dirty = 1;
                                        end
                                        if (CacheContext.busy_req.addr[31:2] == in_dreq[0].addr[31:2] && (|strobe_i4[2])) begin
                                            in_dresp[0].data = dcresp.data;
                                            
                                            for (int i = 0; i < 4; i++) begin
                                                if (strobe_i4[2][i] == 1'b1) begin
                                                    in_dresp[0].data[(((i + 1) << 3) - 1)-:8] = CacheContext.busy_req.data[(((i + 1) << 3) - 1)-:8];
                                                    
                                                end
                                            end
                                        end
                                        else begin
                                            in_dresp[0].data = dcresp.data;
                                            
                                        end
                                        
                                    end
                                    else if (busy_offset > offset[0]) begin
                                        `RW_CACHE(1'b0);
                                         
                                    end
                                end  
                                2'b10: begin end
                                    default: begin end
                                endcase
                            end
                            else begin
                                `RW_CACHE(1'b0); 
                            end
                        end   
                    end
               
                    if (CacheContext.offset == 4'hf) begin // !dcresp.last
                        cacheContext.stat = SC_IDLE;
                        cacheContext.offset = '0;
                        cacheContext.cache_set_meta[index[2]].flush_position = CacheContext.cache_set_meta[index[2]].flush_position + 1;
                    end
                    else begin
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                end
            end
            SC_FLUSH: begin
                ram_switch[{index[2], busy_offset}].en = 1;
                ram_switch[{index[2], busy_offset}].offset = flush_position[2];
                ram_switch[{index[2], busy_offset}].strobe = '0;
                ram_switch[{index[2], busy_offset}].wdata = '0;
                cacheContext.stat = SC_FLUSH;
                dcreq.valid = 1;
                dcreq.is_write = 1;
                dcreq.size = MSIZE4;
                dcreq.addr = flush_addr;
                dcreq.strobe = 4'b1111;
                dcreq.data = ram_rdata[{index[2], busy_offset}];
                dcreq.len = MLEN16;
                if (dcresp.ready) begin
                    if (busy_offset != 4'hf) begin // !dcresp.last
                        cacheContext.offset = CacheContext.offset + 1;
                    end
                    else begin
                        cacheContext.stat = SC_FETCH;
                        cacheContext.offset = '0;
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
            CacheContext <= CACHE_CONTEXT_RESET;
        else
            CacheContext <= cacheContext;

endmodule
