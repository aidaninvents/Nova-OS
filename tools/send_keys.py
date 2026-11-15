import sys, time, subprocess

VBOX = r"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe"
VM = "Nova OS"

SCANCODES = {
    'a': '1e 9e', 'b': '30 b0', 'c': '2e ae', 'd': '20 a0', 'e': '12 92', 'f': '21 a1', 'g': '22 a2',
    'h': '23 a3', 'i': '17 97', 'j': '24 a4', 'k': '25 a5', 'l': '26 a6', 'm': '32 b2', 'n': '31 b1',
    'o': '18 98', 'p': '19 99', 'q': '10 90', 'r': '13 93', 's': '1f 9f', 't': '14 94', 'u': '16 96',
    'v': '2f af', 'w': '11 91', 'x': '2d ad', 'y': '15 95', 'z': '2c ac',
    '1': '02 82', '2': '03 83', '3': '04 84', '4': '05 85', '5': '06 86', '6': '07 87', '7': '08 88',
    '8': '09 89', '9': '0a 8a', '0': '0b 8b',
    ' ': '39 b9', '.': '34 b4', '-': '0c 8c', '/': '35 b5', ':': '2a 27 a7 aa',
    '(': '2a 0a 8a aa', ')': '2a 0b 8b aa', '*': '2a 09 89 aa', '+': '2a 0d 8d aa',
    "'": '28 a8', '~': '2a 29 a9 aa',
    '\n': '1c 9c', '\r': '1c 9c', 'esc': '01 81', 'up': 'e0 48 e0 c8', 'down': 'e0 50 e0 d0'
}

def send_text(text, enter=True):
    for ch in text.lower():
        if ch in SCANCODES:
            codes = SCANCODES[ch].split()
            subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode"] + codes, stdout=subprocess.DEVNULL)
            time.sleep(0.06)
    if enter:
        subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode", "1c", "9c"], stdout=subprocess.DEVNULL)
        time.sleep(0.1)

if __name__ == "__main__":
    no_enter = False
    args = sys.argv[1:]
    if "--raw" in args:
        no_enter = True
        args.remove("--raw")
    msg = " ".join(args) if args else ""
    if msg == "<ENTER>":
        subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode", "1c", "9c"], stdout=subprocess.DEVNULL)
    elif msg == "<ESC>":
        subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode", "01", "81"], stdout=subprocess.DEVNULL)
    elif msg == "<TAB>":
        subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode", "0f", "8f"], stdout=subprocess.DEVNULL)
    elif msg == "<CTRL+U>":
        subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode", "1d", "16", "96", "9d"], stdout=subprocess.DEVNULL)
    elif msg == "<UP>":
        subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode", "e0", "48", "e0", "c8"], stdout=subprocess.DEVNULL)
    elif msg == "<DOWN>":
        subprocess.run([VBOX, "controlvm", VM, "keyboardputscancode", "e0", "50", "e0", "d0"], stdout=subprocess.DEVNULL)
    else:
        send_text(msg, enter=(not no_enter))
