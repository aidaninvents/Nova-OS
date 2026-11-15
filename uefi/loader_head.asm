; ================================================================
; NovaOS UEFI bootloader — single-file source of truth.
; Assembled by tools/build_efi.py from this file (loader.asm).
; Kept as one file so labels/branches are verified by NASM.
; Legacy part1..part4 drafts are frozen in uefi/backup_draft/.
; ================================================================
; UEFI x86-64 calling convention: RCX, RDX, R8, R9 + 32B shadow.
; Boot Services offsets used below (x86-64 SystemTable->BootServices):
;   GetMemoryMap    +56, AllocatePool +128, FreePool +136,
;   HandleProtocol  +152, LocateHandle +176, ExitBootServices +216.
; GOP offsets: QueryMode +8, SetMode +16; GOP.Mode: MaxMode +0,
; Mode +4, Info +8, SizeOfInfo +16, FBBase +24, FBSize +32.
; GOP Info: Version +0, Width +4, Height +8, PixFmt +12, PPSL +16.
; FileProto: Open +8, Read +32(0x20); SimpleFS: OpenVolume +8.
; LoadedImage.DeviceHandle is at +32.
; Handoff at 0x9000 (see HANDOFF PLAN below).
BITS 64
DEFAULT REL
%define IMAGE_BASE      0x140000000
%define SECTION_RVA     0x1000
%define BY_PROTOCOL     2
%define PixelBitMask    2
%define PixelBltOnly    3
%define PixelFormatMax  4
%define KERNEL_PHYS     0x10000
%define KERNEL_MAX      0x10000
%define FS_PHYS         0x20000
%define FS_MAX          0x80000
%define HANDOFF         0x9000
%define STACK_TOP       0x400000
%define PT_PML4         0xA000
%define PT_PDPT         0xB000
%define PT_PD0          0xC000
%define MAX_GOP_WIDTH   2560
%define MAX_GOP_HEIGHT  1600
%define EFI_FILE_MODE_READ  0x0000000000000001
%define EFI_FILE_READ_ONLY  0x0000000000000001
%define EFI_BUFFER_TOO_SMALL 0x8000000000000005
section .text vstart=(IMAGE_BASE + SECTION_RVA)
efi_main:
