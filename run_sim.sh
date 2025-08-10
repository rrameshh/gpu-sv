#!/bin/bash

echo "=== Compiling SIMD GPU ==="
iverilog -g2012 -o gpu_sim \
    src/gpu_top.sv \
    src/core.sv \
    src/alu.sv \
    src/register_file.sv \
    src/shared_memory.sv \
    test/gpu_tb.sv

if [ $? -eq 0 ]; then
    echo "=== Running Simulation ==="
    ./gpu_sim
    
    echo "=== Opening Waveforms ==="
    gtkwave gpu_sim.vcd &
else
    echo "Compilation failed!"
fi
