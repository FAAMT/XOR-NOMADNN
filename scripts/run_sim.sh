#!/bin/bash
clear
cd ..

# Clean previous compilation
ghdl --remove

# Compile all VHDL files including sub-components
ghdl -a --std=08 -fsynopsys --workdir=/Users/faamt/Desktop/XOR-NOMADNN --work=work neuron/dnn_pkg.vhd
ghdl -a --std=08 -fsynopsys --workdir=/Users/faamt/Desktop/XOR-NOMADNN --work=work neuron/relu.vhd
ghdl -a --std=08 -fsynopsys --workdir=/Users/faamt/Desktop/XOR-NOMADNN  --work=work neuron/neuron.vhd
ghdl -a --std=08 -fsynopsys --workdir=/Users/faamt/Desktop/XOR-NOMADNN  --work=work gradient_descent/gradient_descent.vhd

# Add all necessary component files before the main file
ghdl -a --std=08 -fsynopsys --workdir=/Users/faamt/Desktop/XOR-NOMADNN  --work=work network/network.vhd
ghdl -a --std=08 -fsynopsys --workdir=/Users/faamt/Desktop/XOR-NOMADNN  --work=work network/tb_network.vhd

# Run the simulation
rm -f network.ghw
ghdl -r --std=08 -fsynopsys tb_network --wave=network.ghw | grep -v "warning"

# Change back to scripts directory
cd scripts
