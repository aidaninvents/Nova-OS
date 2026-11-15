# ==============================================================================
# NovaOS Extensions Build Makefile
# ==============================================================================

NASM ?= nasm
CXX ?= g++
CXXFLAGS ?= -std=c++17 -O2 -mavx2 -fno-rtti -fno-exceptions -Wall -I.

all: net_pack.o gpu_pack.o cef_bridge.o youtube_interceptor.o

net_pack.o: net_pack.asm
	$(NASM) -f elf64 net_pack.asm -o net_pack.o

gpu_pack.o: gpu_pack.asm
	$(NASM) -f elf64 gpu_pack.asm -o gpu_pack.o

cef_bridge.o: cef_bridge.cpp cef_bridge.hpp
	$(CXX) $(CXXFLAGS) -c cef_bridge.cpp -o cef_bridge.o

youtube_interceptor.o: youtube_interceptor.cpp youtube_interceptor.hpp cef_bridge.hpp
	$(CXX) $(CXXFLAGS) -c youtube_interceptor.cpp -o youtube_interceptor.o

clean:
	rm -f *.o *.bin
