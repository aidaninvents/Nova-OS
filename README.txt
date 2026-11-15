NovaOS fixed build & Bootable Installer ISO
=============================================

1. Getting Started:
   In WSL (Ubuntu):
   cd /mnt/c/Users/aidan/Downloads/NovaOS_fixed/NovaOS_fixed

2. Build NovaOS (Raw Disk Image):
   make clean
   make
   Output: build/novaos.img (512 KiB / 1024 sectors)

3. Run Raw Disk Image in QEMU:
   make run

4. Build the Bootable BIOS Installer ISO:
   make installer-iso
   Output: build/NovaOS-Installer.iso

5. Validate the ISO Structure & Bootloader:
   make validate-iso

6. Test Installer ISO in QEMU:
   make run-iso

=============================================
Package Dependencies (Ubuntu / WSL):
=============================================
The installer build pipeline requires:
  - nasm
  - xorriso
  - isolinux
  - syslinux-common
  - linux-image-virtual
  - busybox-static
  - kmod
  - make

To install missing dependencies:
  sudo apt-get update
  sudo apt-get install -y nasm xorriso isolinux syslinux-common linux-image-virtual busybox-static kmod make

=============================================
Disk Layout of Installed System:
=============================================
NovaOS uses a fixed BIOS disk layout written to the target virtual hard drive:
  - LBA 0       : Master Boot Record / Boot Sector (boot.bin)
  - LBA 1-4     : Stage 2 Loader (stage2.bin)
  - LBA 5-132   : 64-bit Long Mode Kernel (kernel.bin)
  - LBA 133-920 : NovaFS Filesystem (novafs.img, containing fonts, audio, and logo)
Total installed size: 1024 sectors (512 KiB).

=============================================
VirtualBox Testing Instructions:
=============================================
To test the installer safely in VirtualBox:

Step 1: Create a New Virtual Machine
  - Name: NovaOS Test
  - Type: Other
  - Version: Other/Unknown (64-bit)
  - Memory: 512 MB or 1024 MB
  - BIOS / Firmware: Legacy BIOS (do NOT enable EFI)

Step 2: Create a Target Virtual Hard Disk
  - Create a new Virtual Hard Disk (VDI or VMDK)
  - Size: 100 MB or 1 GB (Dynamically allocated)
  - Attach this new virtual hard drive to the VM's storage controller (IDE or SATA).

Step 3: Attach the Installer ISO
  - Add an Optical Drive (CD/DVD)
  - Choose `build/NovaOS-Installer.iso`
  - Ensure Optical Drive is set before Hard Disk in Boot Order.
  - Optional: Set Audio Controller to ICH AC97 to hear startup sound.

Step 4: Boot and Install
  - Start the VM.
  - The NovaOS BIOS boot menu will appear:
      [Start NovaOS (Live / RAM Disk)]
      [Install NovaOS to Hard Drive]
      [Boot from First Hard Disk (Drive 0x80)]
      [Reboot Computer]
      [Power Off Computer]
  - Select "Install NovaOS to Hard Drive".
  - The installer scans and displays connected target hard disks (e.g., /dev/sda).
  - Select your virtual hard drive number.
  - Review the disk capacity and warning prompt.
  - Type 'YES' to confirm writing.
  - The installer writes the boot sector, stage 2, kernel, and NovaFS,
    then computes and verifies the SHA-256 checksums.
  - When installation succeeds, press ENTER to reboot.

Step 5: Boot Installed NovaOS from Hard Disk
  - In VirtualBox, remove or unmount `NovaOS-Installer.iso` from the optical drive.
  - Start the VM.
  - The VM will boot directly from the virtual hard drive:
      * BIOS loads LBA 0 (boot.bin)
      * Loads stage2.bin from LBA 1-4
      * Enters 64-bit long mode
      * Loads kernel.bin from LBA 5
      * Loads NovaFS from LBA 133
      * Launches desktop GUI, spinner, and audio.


==================================================
Nova OS 1.00 26Q4 Build 26110.0000 Release Notes
==================================================
Formula:
{[Name][Base ver][Milestone/Quarter][Build number]} -> {[Nova OS][1.00][26Q4][26110.0000]}

What's New in Build 26110.0000:
1. WiFi & Ethernet Hardware Driver Manager (`wifi.nosp` / `run wifi.nosp`):
   - Catalogs 10 modern wireless and Ethernet chipsets (2020 and newer):
     - Intel Wi-Fi 6 AX200 / AX201 (160MHz 802.11ax) [2020]
     - Intel Wi-Fi 6E AX210 / AX211 / AX411 (6GHz Band) [2021]
     - Intel Wi-Fi 7 BE200 / BE202 (320MHz 5.8Gbps) [2023-2024]
     - Realtek RTL8852AE / RTL8852BE / RTL8852CE Wi-Fi 6 [2021-2023]
     - Realtek RTL8821CE 802.11ac PCIe Wireless Adapter [2020+]
     - MediaTek MT7921 / MT7922 (AMD RZ608 / RZ616) [2021-2023]
     - Broadcom BCM4360 / BCM43684 Wi-Fi 6/6E [2020+]
     - Qualcomm Atheros QCA6390 / FastConnect 6800 [2020-2024]
     - Realtek RTL8125 / RTL8125B 2.5GbE Gaming NIC [2020+]
     - Intel Ethernet Controller I225-V / I226-V 2.5GbE [2020+]
   - Missing Hardware Fallback Option:
     "Device currently not available. Email aidangaber67@gmail.com so I can add it!"
   - Automatic DHCP negotiation and reboot prompt.

2. WebKit-Mini Web Browser (`browser.nosp` / `run browser.nosp`):
   - Graphical tab bar, address bar, and HTTPS / TLS 1.3 encryption indicator.
   - Inline true-color image rasterization on linear framebuffer.
   - Built-in video player viewport with timeline seek bar and sound output.
   - Live GitHub integration: downloads snapshots directly from:
     https://github.com/aidaninvents/Nova-Os
     Saves archives to C:\Downloads\Nova-Os-main.zip with SHA-256 validation.

3. Global Arrow Pointer Cursor:
   - High-visibility 12x16 arrow cursor with border/interior contrast.
   - Active across the desktop, explorer, network manager, and browser.

4. File Explorer & Drive D: Navigation:
   - Interactive launching of startup.nosp, wifi.nosp, and browser.nosp.
