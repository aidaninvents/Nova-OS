from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# 1. kernel.asm
k_path = ROOT / "kernel.asm"
content = k_path.read_bytes()
content = content.replace(b'NovaOS v0.8.5648 (Build 5648)', b'NovaOS v0.9.5167 (Build 5167)')
k_path.write_bytes(content)

# 2. uefi/loader.asm
u_path = ROOT / "uefi" / "loader.asm"
u_content = u_path.read_text(encoding="latin1")
u_content = u_content.replace("'5','6','4','8'", "'5','1','6','7'")
u_content = u_content.replace("v0.8.5648", "v0.9.5167")
u_content = u_content.replace("Build 5648", "Build 5167")
u_path.write_text(u_content, encoding="latin1")

# 3. installer/init
i_path = ROOT / "installer" / "init"
i_content = i_path.read_text(encoding="utf-8")
i_content = i_content.replace("v0.8.5648 (Build 5648)", "v0.9.5167 (Build 5167)")
i_content = i_content.replace("v0.8.5648", "v0.9.5167")
i_path.write_text(i_content, encoding="utf-8")

# 4. isolinux.cfg
iso_path = ROOT / "installer" / "isolinux" / "isolinux.cfg"
iso_content = iso_path.read_text(encoding="utf-8")
iso_content = iso_content.replace("v0.8.5648 (Build 5648)", "v0.9.5167 (Build 5167)")
iso_path.write_text(iso_content, encoding="utf-8")

print("Updated version across all subsystems to v0.9.5167 (Build 5167)!")
