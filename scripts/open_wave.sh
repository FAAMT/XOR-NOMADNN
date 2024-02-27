#!/bin/zsh

# Open GTKWave with .ghw and .gtkw files
cd ..
pkill gtkwave
gtkwave network.ghw network.gtkw
cd scripts
