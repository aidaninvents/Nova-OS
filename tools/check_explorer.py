from pathlib import Path
content = Path("NovaOS_fixed/kernel.asm").read_text(encoding="utf-8")

# The new command_files pushes r11,r12,r13,r14,r15 (5 regs)
# then .explorer_draw does push rcx, push rdx each iteration but they're balanced within
# The issue: .explorer_close does extra pop rdx / pop rcx that don't exist
# Let's check what's actually pushed at the start of command_files
idx = content.find("command_files:")
snippet = content[idx:idx+1000]
print(snippet[:600])
