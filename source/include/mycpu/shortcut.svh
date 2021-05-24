`ifndef __SHORTCUT_SVH__
`define __SHORTCUT_SVH__

`define MAKE_PUBLIC_READ(typename, new_name, name) \
    typename new_name /* verilator public_flat_rd */; \
    assign new_name = name;

`endif

