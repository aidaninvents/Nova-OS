all: build/novaos.img media netsurf-port

build:
	mkdir -p build

build/boot.bin: boot.asm | build
	nasm -f bin boot.asm -o build/boot.bin

build/stage2.bin: stage2.asm | build
	nasm -f bin stage2.asm -o build/stage2.bin

build/kernel.bin: kernel.asm | build
	nasm -f bin kernel.asm -o build/kernel.bin

build/fs.bin: fs/novafs.img | build
	cp fs/novafs.img build/fs.bin

# Media & Audio Subsystem (16-bit 44.1kHz AC'97 DMA + YouTube Input)
build/audio_ac97.o: media/audio_ac97.asm | build
	nasm -f elf64 media/audio_ac97.asm -o build/audio_ac97.o

build/yt_input.o: media/yt_input.asm | build
	nasm -f elf64 media/yt_input.asm -o build/yt_input.o

build/media.o: build/audio_ac97.o build/yt_input.o
	ld -m elf_x86_64 -r build/audio_ac97.o build/yt_input.o -o build/media.o

media: build/media.o

# NetSurf C Bridge & Direct Framebuffer Driver
build/novaos_bridge.o: port/novaos_bridge.c port/novaos_bridge.h | build
	gcc -ffreestanding -nostdlib -mno-red-zone -mcmodel=kernel -fno-pic -fno-pie -Wall -Wextra -c port/novaos_bridge.c -o build/novaos_bridge.o

build/novaos_nsfb.o: port/novaos_nsfb.c port/novaos_bridge.h | build
	gcc -ffreestanding -nostdlib -mno-red-zone -mcmodel=kernel -fno-pic -fno-pie -Wall -Wextra -c port/novaos_nsfb.c -o build/novaos_nsfb.o

build/netsurf_bridge.o: build/novaos_bridge.o build/novaos_nsfb.o
	ld -m elf_x86_64 -r build/novaos_bridge.o build/novaos_nsfb.o -o build/netsurf_bridge.o

netsurf-port: build/netsurf_bridge.o

build/novaos.img: build/boot.bin build/stage2.bin build/kernel.bin build/fs.bin
	dd if=/dev/zero of=build/novaos.img bs=512 count=1280 2>/dev/null
	dd if=build/boot.bin of=build/novaos.img bs=512 seek=0 conv=notrunc 2>/dev/null
	dd if=build/stage2.bin of=build/novaos.img bs=512 seek=1 conv=notrunc 2>/dev/null
	dd if=build/kernel.bin of=build/novaos.img bs=512 seek=5 conv=notrunc 2>/dev/null
	dd if=build/fs.bin of=build/novaos.img bs=512 seek=261 conv=notrunc 2>/dev/null

installer-iso: all
	@echo "Building NovaOS Installer ISO..."
	@tools/build_initramfs.sh
	@tools/build_iso.sh

validate-iso:
	@tools/validate_iso.sh

run-iso: installer-iso
	qemu-system-x86_64 -cdrom build/NovaOS-Installer.iso -boot d -m 512M -device AC97

run: all
	qemu-system-x86_64 -drive format=raw,file=build/novaos.img -device AC97

debug: all
	qemu-system-x86_64 -drive format=raw,file=build/novaos.img \
		-d cpu_reset,int,guest_errors -D qemu-debug.log \
		-no-reboot -no-shutdown

clean:
	rm -rf build
