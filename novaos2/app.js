// Nova OS 2.00 Beta 4 (27300) Complete Desktop Environment

function escapeHtml(s) {
  return String(s == null ? "" : s)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

const ICONS = {
  notepad: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="15" y="12" width="54" height="64" rx="3" fill="#F4F5F7" stroke="#CBD5E1" stroke-width="1.5"/><rect x="15" y="12" width="54" height="10" fill="#D8DCE3"/><g fill="#7A869A"><rect x="19" y="7" width="3" height="8" rx="1.5"/><rect x="26" y="7" width="3" height="8" rx="1.5"/><rect x="33" y="7" width="3" height="8" rx="1.5"/><rect x="40" y="7" width="3" height="8" rx="1.5"/><rect x="47" y="7" width="3" height="8" rx="1.5"/><rect x="54" y="7" width="3" height="8" rx="1.5"/><rect x="61" y="7" width="3" height="8" rx="1.5"/></g><line x1="21" y1="32" x2="63" y2="32" stroke="#DCE1E8" stroke-width="1.5"/><line x1="21" y1="42" x2="63" y2="42" stroke="#DCE1E8" stroke-width="1.5"/><line x1="21" y1="52" x2="63" y2="52" stroke="#DCE1E8" stroke-width="1.5"/><line x1="21" y1="62" x2="50" y2="62" stroke="#DCE1E8" stroke-width="1.5"/></svg>`,
  terminal: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="6" y="12" width="72" height="60" rx="2" fill="#000000"/><polyline points="14,22 23,28 14,34" fill="none" stroke="#FFFFFF" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/><line x1="26" y1="36" x2="36" y2="36" stroke="#FFFFFF" stroke-width="3.2" stroke-linecap="round"/></svg>`,
  files: `<svg viewBox="0 0 84 84" width="74" height="74"><path d="M8 18a4 4 0 0 1 4-4h20l6 6h34a4 4 0 0 1 4 4v42a4 4 0 0 1-4 4H12a4 4 0 0 1-4-4V18z" fill="#FCE78C"/><path d="M8 26h68v40a4 4 0 0 1-4 4H12a4 4 0 0 1-4-4V26z" fill="#FFF099"/></svg>`,
  youtube: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="6" y="17" width="72" height="50" rx="14" fill="#FF0000"/><polygon points="35,30 55,42 35,54" fill="#FFFFFF"/></svg>`,
  wifi: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="6" y="6" width="72" height="72" fill="#FFFFFF"/><path d="M16 34a37 37 0 0 1 52 0" fill="none" stroke="#000000" stroke-width="6.5" stroke-linecap="round"/><path d="M25 46a24 24 0 0 1 34 0" fill="none" stroke="#000000" stroke-width="6.5" stroke-linecap="round"/><path d="M34 57a12 12 0 0 1 16 0" fill="none" stroke="#000000" stroke-width="6.5" stroke-linecap="round"/><circle cx="42" cy="68" r="5" fill="#000000"/></svg>`,
  chrome: `<svg viewBox="0 0 84 84" width="74" height="74"><defs><clipPath id="chrClip"><circle cx="42" cy="42" r="34"/></clipPath></defs><g clip-path="url(#chrClip)"><circle cx="42" cy="42" r="34" fill="#FBBC05"/><path d="M8 8h68v17H42L27.3 50.5 8 17z" fill="#EA4335"/><path d="M8 17l19.3 33.5L42 76H8z" fill="#34A853"/><path d="M42 25h34v51H42l14.7-25.5z" fill="#FBBC05"/><circle cx="42" cy="42" r="16" fill="#FFFFFF"/><circle cx="42" cy="42" r="12.5" fill="#1A73E8"/></g></svg>`,
  settings: `<svg viewBox="0 0 84 84" width="70" height="70"><circle cx="42" cy="42" r="26" fill="#475569"/><circle cx="42" cy="42" r="12" fill="#CBD5E1"/><circle cx="42" cy="42" r="6" fill="#1E293B"/><g fill="#475569"><rect x="38" y="6" width="8" height="12" rx="2"/><rect x="38" y="66" width="8" height="12" rx="2"/><rect x="6" y="38" width="12" height="8" rx="2"/><rect x="66" y="38" width="12" height="8" rx="2"/><rect x="15" y="15" width="10" height="10" rx="2" transform="rotate(45 20 20)"/><rect x="59" y="59" width="10" height="10" rx="2" transform="rotate(45 64 64)"/><rect x="59" y="15" width="10" height="10" rx="2" transform="rotate(45 64 20)"/><rect x="15" y="59" width="10" height="10" rx="2" transform="rotate(45 20 64)"/></g></svg>`,
  appstore: `<svg viewBox="0 0 84 84" width="70" height="70"><rect x="12" y="20" width="60" height="54" rx="10" fill="#1D6FC2"/><path d="M28 20v-5a14 14 0 0 1 28 0v5" fill="none" stroke="#93C5FD" stroke-width="5"/><polygon points="42,31 46,41 57,42 49,49 51,60 42,54 33,60 35,49 27,42 38,41" fill="#FFFFFF"/></svg>`,
  videoplayer: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="8" y="14" width="68" height="56" rx="10" fill="#0F172A" stroke="#38BDF8" stroke-width="3"/><rect x="14" y="20" width="56" height="36" rx="4" fill="#1E293B"/><polygon points="36,28 54,38 36,48" fill="#38BDF8"/><rect x="16" y="61" width="52" height="4" rx="2" fill="#334155"/><rect x="16" y="61" width="28" height="4" rx="2" fill="#38BDF8"/><circle cx="44" cy="63" r="4" fill="#FFFFFF"/></svg>`,
  dvdplayer: `<svg viewBox="0 0 84 84" width="74" height="74"><circle cx="42" cy="42" r="34" fill="#1E293B" stroke="#94A3B8" stroke-width="2.5"/><path d="M18 42a24 24 0 0 1 24-24" fill="none" stroke="#38BDF8" stroke-width="4" stroke-linecap="round"/><path d="M66 42a24 24 0 0 1-24 24" fill="none" stroke="#A855F7" stroke-width="4" stroke-linecap="round"/><circle cx="42" cy="42" r="11" fill="#0F172A" stroke="#E2E8F0" stroke-width="2"/><circle cx="42" cy="42" r="4" fill="#38BDF8"/><text x="42" y="73" text-anchor="middle" fill="#FFFFFF" font-size="10" font-weight="800">DVD</text></svg>`,
  musicstudio: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="10" width="64" height="64" rx="14" fill="#7C3AED"/><path d="M34 54V26l26-6v28" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/><circle cx="28" cy="55" r="7" fill="#FFFFFF"/><circle cx="54" cy="49" r="7" fill="#FFFFFF"/></svg>`,
  paintstudio: `<svg viewBox="0 0 84 84" width="74" height="74"><circle cx="42" cy="42" r="32" fill="#FDE047" stroke="#CA8A04" stroke-width="2.5"/><circle cx="28" cy="32" r="6" fill="#EF4444"/><circle cx="42" cy="24" r="6" fill="#3B82F6"/><circle cx="56" cy="32" r="6" fill="#10B981"/><circle cx="58" cy="48" r="6" fill="#A855F7"/><circle cx="32" cy="54" r="7" fill="#FFFFFF"/></svg>`,
  exetonosp: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="12" width="64" height="60" rx="12" fill="#1E1B4B" stroke="#818CF8" stroke-width="3"/><rect x="18" y="20" width="22" height="20" rx="3" fill="#38BDF8"/><rect x="44" y="20" width="22" height="20" rx="3" fill="#818CF8"/><rect x="18" y="44" width="22" height="20" rx="3" fill="#A855F7"/><rect x="44" y="44" width="22" height="20" rx="3" fill="#F43F5E"/><text x="42" y="47" text-anchor="middle" fill="#FFFFFF" font-size="13" font-weight="900">EXE</text></svg>`,
  calculator: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="14" y="8" width="56" height="68" rx="10" fill="#1E293B" stroke="#475569" stroke-width="2"/><rect x="22" y="16" width="40" height="16" rx="4" fill="#38BDF8"/><g fill="#CBD5E1"><rect x="22" y="38" width="10" height="8" rx="2"/><rect x="37" y="38" width="10" height="8" rx="2"/><rect x="52" y="38" width="10" height="8" rx="2"/><rect x="22" y="50" width="10" height="8" rx="2"/><rect x="37" y="50" width="10" height="8" rx="2"/><rect x="52" y="50" width="10" height="8" rx="2"/><rect x="22" y="62" width="25" height="8" rx="2"/><rect x="52" y="62" width="10" height="8" rx="2" fill="#F97316"/></g></svg>`,
  imageviewer: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="14" width="64" height="56" rx="10" fill="#0EA5E9"/><circle cx="30" cy="32" r="7" fill="#FEF08A"/><polygon points="14,62 36,38 52,52 62,42 70,62" fill="#10B981"/></svg>`,
  sysmonitor: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="14" width="64" height="56" rx="10" fill="#0F172A" stroke="#22C55E" stroke-width="3"/><polyline points="16,50 28,50 36,28 46,58 54,38 68,38" fill="none" stroke="#22C55E" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  clock: `<svg viewBox="0 0 84 84" width="74" height="74"><circle cx="42" cy="42" r="32" fill="#1E293B" stroke="#38BDF8" stroke-width="4"/><line x1="42" y1="42" x2="42" y2="23" stroke="#FFFFFF" stroke-width="4.5" stroke-linecap="round"/><line x1="42" y1="42" x2="57" y2="48" stroke="#38BDF8" stroke-width="4" stroke-linecap="round"/><circle cx="42" cy="42" r="4" fill="#F97316"/></svg>`,
  calendar: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="14" width="64" height="58" rx="10" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="2"/><rect x="10" y="14" width="64" height="18" rx="8" fill="#EF4444"/><text x="42" y="57" text-anchor="middle" fill="#0F172A" font-size="26" font-weight="900">21</text></svg>`,
  tasks: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="12" y="10" width="60" height="64" rx="10" fill="#2563EB"/><polyline points="24,36 32,44 46,28" fill="none" stroke="#FFFFFF" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/><line x1="24" y1="56" x2="60" y2="56" stroke="#93C5FD" stroke-width="4" stroke-linecap="round"/></svg>`,
  codeide: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="12" width="64" height="60" rx="12" fill="#0F172A" stroke="#6366F1" stroke-width="3"/><polyline points="32,30 20,42 32,54" fill="none" stroke="#38BDF8" stroke-width="4" stroke-linecap="round"/><polyline points="52,30 64,42 52,54" fill="none" stroke="#38BDF8" stroke-width="4" stroke-linecap="round"/><line x1="45" y1="26" x2="39" y2="58" stroke="#A855F7" stroke-width="4" stroke-linecap="round"/></svg>`,
  diskutil: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="12" y="16" width="60" height="52" rx="8" fill="#334155" stroke="#94A3B8" stroke-width="2.5"/><rect x="20" y="24" width="44" height="14" rx="4" fill="#0F172A"/><rect x="22" y="26" width="26" height="10" rx="2" fill="#22C55E"/><circle cx="58" cy="54" r="5" fill="#38BDF8"/></svg>`,
  nettools: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="12" width="64" height="60" rx="12" fill="#064E3B" stroke="#10B981" stroke-width="3"/><circle cx="42" cy="42" r="18" fill="none" stroke="#34D399" stroke-width="3"/><ellipse cx="42" cy="42" rx="9" ry="18" fill="none" stroke="#34D399" stroke-width="2.5"/><line x1="24" y1="42" x2="60" y2="42" stroke="#34D399" stroke-width="2.5"/></svg>`,
  snake: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="10" width="64" height="64" rx="14" fill="#14532D"/><path d="M22 56h18v-14h16v-14" fill="none" stroke="#4ADE80" stroke-width="8" stroke-linecap="round" stroke-linejoin="round"/><circle cx="62" cy="56" r="5" fill="#EF4444"/></svg>`,
  mines: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="10" width="64" height="64" rx="12" fill="#E2E8F0" stroke="#64748B" stroke-width="2.5"/><circle cx="42" cy="44" r="14" fill="#0F172A"/><line x1="42" y1="22" x2="42" y2="66" stroke="#0F172A" stroke-width="4"/><line x1="20" y1="44" x2="64" y2="44" stroke="#0F172A" stroke-width="4"/><circle cx="37" cy="39" r="3.5" fill="#FFFFFF"/></svg>`,
  game2048: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="10" width="64" height="64" rx="12" fill="#F59E0B"/><text x="42" y="50" text-anchor="middle" fill="#FFFFFF" font-size="22" font-weight="900">2048</text></svg>`,
  weather: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="8" y="10" width="68" height="64" rx="14" fill="#0284C7"/><circle cx="34" cy="34" r="12" fill="#FDE047"/><path d="M26 56h34a10 10 0 0 0 0-20 14 14 0 0 0-27-3 10 10 0 0 0-7 23z" fill="#FFFFFF"/></svg>`,
  piano: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="14" width="64" height="56" rx="10" fill="#1E293B" stroke="#94A3B8" stroke-width="2"/><g fill="#FFFFFF"><rect x="15" y="20" width="10" height="44" rx="2"/><rect x="26" y="20" width="10" height="44" rx="2"/><rect x="37" y="20" width="10" height="44" rx="2"/><rect x="48" y="20" width="10" height="44" rx="2"/><rect x="59" y="20" width="10" height="44" rx="2"/></g><g fill="#0F172A"><rect x="22" y="20" width="6" height="26" rx="1"/><rect x="33" y="20" width="6" height="26" rx="1"/><rect x="55" y="20" width="6" height="26" rx="1"/></g></svg>`,
  pomodoro: `<svg viewBox="0 0 84 84" width="74" height="74"><circle cx="42" cy="46" r="26" fill="#EF4444"/><path d="M36 18h12M42 18v-5" stroke="#16A34A" stroke-width="5" stroke-linecap="round"/><polyline points="42,32 42,46 53,46" fill="none" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  converter: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="12" width="64" height="60" rx="12" fill="#4F46E5"/><path d="M22 34h36l-8-8M62 50H26l8 8" fill="none" stroke="#FFFFFF" stroke-width="4.5" stroke-linecap="round" stroke-linejoin="round"/></svg>`,
  tictactoe: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="10" width="64" height="64" rx="12" fill="#0F172A" stroke="#38BDF8" stroke-width="2.5"/><line x1="32" y1="18" x2="32" y2="66" stroke="#475569" stroke-width="3"/><line x1="52" y1="18" x2="52" y2="66" stroke="#475569" stroke-width="3"/><line x1="18" y1="32" x2="66" y2="32" stroke="#475569" stroke-width="3"/><line x1="18" y1="52" x2="66" y2="52" stroke="#475569" stroke-width="3"/><circle cx="42" cy="42" r="7" fill="none" stroke="#38BDF8" stroke-width="3.5"/></svg>`,
  devtools: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="12" width="64" height="60" rx="12" fill="#18181B" stroke="#F97316" stroke-width="3"/><text x="42" y="49" text-anchor="middle" fill="#FDBA74" font-size="20" font-weight="900">{ }</text></svg>`,
  journal: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="14" y="10" width="56" height="64" rx="10" fill="#0D9488"/><rect x="14" y="10" width="12" height="64" rx="4" fill="#115E59"/><rect x="34" y="24" width="26" height="12" rx="3" fill="#CCFBF1"/><line x1="34" y1="46" x2="60" y2="46" stroke="#99F6E4" stroke-width="3" stroke-linecap="round"/><line x1="34" y1="56" x2="52" y2="56" stroke="#99F6E4" stroke-width="3" stroke-linecap="round"/></svg>`,
  recorder: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="10" width="64" height="64" rx="16" fill="#BE123C"/><rect x="34" y="20" width="16" height="28" rx="8" fill="#FFFFFF"/><path d="M26 42a16 16 0 0 0 32 0" fill="none" stroke="#FECDD3" stroke-width="4" stroke-linecap="round"/><line x1="42" y1="58" x2="42" y2="66" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/><line x1="33" y1="66" x2="51" y2="66" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/></svg>`,
  budget: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="12" width="64" height="60" rx="12" fill="#15803D"/><circle cx="42" cy="42" r="20" fill="#22C55E"/><text x="42" y="50" text-anchor="middle" fill="#FFFFFF" font-size="26" font-weight="900">$</text></svg>`,
  sticky: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="12" y="12" width="60" height="60" rx="8" fill="#FACC15"/><polygon points="54,72 72,54 54,54" fill="#CA8A04"/><line x1="22" y1="30" x2="60" y2="30" stroke="#713F12" stroke-width="3.5" stroke-linecap="round"/><line x1="22" y1="44" x2="52" y2="44" stroke="#713F12" stroke-width="3.5" stroke-linecap="round"/></svg>`,
  memory: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="12" y="16" width="38" height="48" rx="8" fill="#7C3AED" stroke="#DDD6FE" stroke-width="2"/><rect x="34" y="22" width="38" height="48" rx="8" fill="#EC4899" stroke="#FBCFE8" stroke-width="2"/><polygon points="53,36 56,43 64,44 58,49 60,56 53,52 46,56 48,49 42,44 50,43" fill="#FFFFFF"/></svg>`,
  markdown: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="10" y="16" width="64" height="52" rx="10" fill="#1E293B" stroke="#38BDF8" stroke-width="3"/><text x="42" y="49" text-anchor="middle" fill="#FFFFFF" font-size="20" font-weight="900">M↓</text></svg>`,
  colorstudio: `<svg viewBox="0 0 84 84" width="74" height="74"><circle cx="34" cy="36" r="18" fill="#EF4444" opacity="0.88"/><circle cx="50" cy="36" r="18" fill="#3B82F6" opacity="0.88"/><circle cx="42" cy="52" r="18" fill="#22C55E" opacity="0.88"/></svg>`,
  qrlab: `<svg viewBox="0 0 84 84" width="74" height="74"><rect x="12" y="12" width="60" height="60" rx="10" fill="#FFFFFF" stroke="#0F172A" stroke-width="3"/><rect x="20" y="20" width="16" height="16" fill="#0F172A"/><rect x="48" y="20" width="16" height="16" fill="#0F172A"/><rect x="20" y="48" width="16" height="16" fill="#0F172A"/><rect x="46" y="46" width="8" height="8" fill="#2563EB"/><rect x="56" y="56" width="8" height="8" fill="#0F172A"/></svg>`,
};

const TRAY_ICONS = {
  none: `<svg viewBox="0 0 28 28" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.4"><circle cx="14" cy="14" r="10"/><line x1="6" y1="6" x2="22" y2="22"/></svg>`,
  wifi: `<svg viewBox="0 0 28 28" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round"><path d="M2 10a17 17 0 0 1 24 0"/><path d="M6.5 15a11 11 0 0 1 15 0"/><path d="M11 20a4.5 4.5 0 0 1 6 0"/><circle cx="14" cy="23.5" r="1.6" fill="currentColor"/></svg>`,
  ethernet: `<svg viewBox="0 0 28 28" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.3"><rect x="3" y="5" width="22" height="15" rx="2"/><path d="M9 20v4M19 20v4M6 24h16"/></svg>`,
};

// Core + Downloadable .NOSP packages (dynamically expanded by live server catalog)
const ALL_APPS = [
  { id: "files", label: "File Explorer", nosp: null, icon: ICONS.files, core: true },
  { id: "wifi", label: "WiFi/Ethernet", nosp: null, icon: ICONS.wifi, core: true },
  { id: "settings", label: "Settings", nosp: null, icon: ICONS.settings, core: true },
  { id: "appstore", label: "App Store", nosp: null, icon: ICONS.appstore, core: true },
  { id: "clock", label: "Clock", nosp: "Clock.NOSP", icon: ICONS.clock, core: false },
  { id: "calendar", label: "Calendar", nosp: "Calendar.NOSP", icon: ICONS.calendar, core: false },
  { id: "calculator", label: "Calculator", nosp: "Calculator.NOSP", icon: ICONS.calculator, core: false },
  { id: "notepad", label: "Notepad", nosp: "Notepad.NOSP", icon: ICONS.notepad, core: false },
  { id: "tasks", label: "Tasks", nosp: "Tasks.NOSP", icon: ICONS.tasks, core: false },
  { id: "codeide", label: "Code Studio", nosp: "CodeStudio.NOSP", icon: ICONS.codeide, core: false },
  { id: "chrome", label: "Chrome", nosp: "Chrome.NOSP", icon: ICONS.chrome, core: false },
  { id: "youtube", label: "YouTube", nosp: "YouTube.NOSP", icon: ICONS.youtube, core: false },
  { id: "exetonosp", label: "EXE to NOSP", nosp: "EXEtoNOSP.NOSP", icon: ICONS.exetonosp, core: false },
  { id: "terminal", label: "Terminal", nosp: "Terminal.NOSP", icon: ICONS.terminal, core: false },
  { id: "videoplayer", label: "Video Player", nosp: "VideoPlayer.NOSP", icon: ICONS.videoplayer, core: false },
  { id: "dvdplayer", label: "DVD Player", nosp: "DVDPlayer.NOSP", icon: ICONS.dvdplayer, core: false },
  { id: "musicstudio", label: "Music Player", nosp: "MusicStudio.NOSP", icon: ICONS.musicstudio, core: false },
  { id: "paintstudio", label: "Paint Studio", nosp: "PaintStudio.NOSP", icon: ICONS.paintstudio, core: false },
  { id: "imageviewer", label: "Photos", nosp: "ImageViewer.NOSP", icon: ICONS.imageviewer, core: false },
  { id: "sysmonitor", label: "Task Manager", nosp: "SystemMonitor.NOSP", icon: ICONS.sysmonitor, core: false },
  { id: "diskutil", label: "Disk Manager", nosp: "DiskManager.NOSP", icon: ICONS.diskutil, core: false },
  { id: "nettools", label: "NetTools", nosp: "NetTools.NOSP", icon: ICONS.nettools, core: false },
  { id: "snake", label: "Snake", nosp: "Snake.NOSP", icon: ICONS.snake, core: false },
  { id: "mines", label: "Minesweeper", nosp: "Minesweeper.NOSP", icon: ICONS.mines, core: false },
  { id: "game2048", label: "2048", nosp: "Game2048.NOSP", icon: ICONS.game2048, core: false },
  { id: "weather", label: "Weather", nosp: "Weather.NOSP", icon: ICONS.weather, core: false },
  { id: "piano", label: "Piano Synth", nosp: "Piano.NOSP", icon: ICONS.piano, core: false },
  { id: "pomodoro", label: "Pomodoro", nosp: "Pomodoro.NOSP", icon: ICONS.pomodoro, core: false },
  { id: "converter", label: "Converter", nosp: "Converter.NOSP", icon: ICONS.converter, core: false },
  { id: "tictactoe", label: "Tic-Tac-Toe", nosp: "TicTacToe.NOSP", icon: ICONS.tictactoe, core: false },
  { id: "devtools", label: "DevTools", nosp: "DevTools.NOSP", icon: ICONS.devtools, core: false },
  { id: "journal", label: "Journal", nosp: "Journal.NOSP", icon: ICONS.journal, core: false },
  { id: "recorder", label: "Voice Recorder", nosp: "Recorder.NOSP", icon: ICONS.recorder, core: false },
  { id: "budget", label: "Home Budget", nosp: "Budget.NOSP", icon: ICONS.budget, core: false },
  { id: "sticky", label: "Sticky Notes", nosp: "StickyNotes.NOSP", icon: ICONS.sticky, core: false },
  { id: "memory", label: "Memory Match", nosp: "MemoryMatch.NOSP", icon: ICONS.memory, core: false },
  { id: "markdown", label: "Markdown", nosp: "Markdown.NOSP", icon: ICONS.markdown, core: false },
  { id: "colorstudio", label: "Color Studio", nosp: "ColorStudio.NOSP", icon: ICONS.colorstudio, core: false },
  { id: "qrlab", label: "QR Lab", nosp: "QRLab.NOSP", icon: ICONS.qrlab, core: false },
];

const HOME_DEFAULT_APPS = [
  "wifi", "settings", "files", "appstore",
  "clock", "calendar", "calculator", "notepad", "chrome", "weather",
  "journal", "recorder", "budget", "sticky", "memory",
];
const PRO_DEFAULT_APPS = [
  ...HOME_DEFAULT_APPS,
  "devtools", "codeide", "terminal", "sysmonitor", "diskutil",
  "nettools", "exetonosp", "paintstudio", "musicstudio", "videoplayer",
];

const state = {
  theme: "light",
  language: "en-US",
  spinnerMode: "new", // 'new' = E100-E176, 'old' = E052-E0CB
  spinnerFrame: 0,
  netMode: "none", // 'none' | 'wifi' | 'ethernet'
  netConnected: false,
  wifiSsid: "",
  selectedSsid: "",
  wifiDriver: "cfg80211 / e1000 Network Stack (WPA2-PSK CCMP Enabled)",
  hasWifiHardware: false,
  isVirtualBox: true,
  ethInterfaces: ["enp0s3"],
  installedApps: [...PRO_DEFAULT_APPS],
  activated: false,
  activationKey: "",
  activationBypassed: false,
  wallpaper: "",
  userAccount: { username: "User", has_pin: false },
  appUsage: {}, // { [appId]: { count: number, last_used: number } }
  startSearchQuery: "",
  topZ: 120,
  windows: {},
  sysinfo: {
    cpu: "Detecting CPU...",
    ram: "4.0 GB",
    gpu: "Detecting GPU...",
    display: "1920x1080 (1080p) 60Hz",
    version: "Nova OS 2.00 Beta 4\n(Build 27300)",
    build: "27300",
    edition: "Nova OS 2.00 Pro",
    edition_short: "Pro",
    activated: false,
    max_file_cap: "Unlimited (> 1 GB Supported)",
  },
  updateStage: "initial",
  updateCheckMode: "auto",
  explorerPath: "",
  explorerDrive: "ThisPC",
  wifiNetworks: [], // Populated ONLY from real hardware scan (/api/wifi/scan) — never fake SSIDs!
  fonts: ["Segoe UI", "Inter", "Roboto", "Ubuntu", "DejaVu Sans", "Liberation Sans", "JetBrains Mono", "Cascadia Code"],
  systemFont: "Segoe UI",
  datetime: {
    timezone: "America/Chicago",
    offset_ms: 0,
    use_24h: false,
    show_seconds: false,
  },
};

// Spinner loop (only updates visible spinner nodes to avoid hidden-layer repaints/flashing)
function startSpinnerEngine() {
  setInterval(() => {
    const first = state.spinnerMode === "old" ? 0xE052 : 0xE100;
    const count = state.spinnerMode === "old" ? 122 : 119;
    const code = first + (state.spinnerFrame % count);
    const ch = String.fromCharCode(code);
    state.spinnerFrame = (state.spinnerFrame + 1) % count;

    document.querySelectorAll(".boot-spinner-box, .update-inline-spinner").forEach((el) => {
      if (el.offsetParent !== null) el.textContent = ch;
    });
  }, 40);
}

function getAdjustedNow() {
  return new Date(Date.now() + (Number(state.datetime.offset_ms) || 0));
}

function formatClockParts(dateObj) {
  const tz = state.datetime.timezone || "America/Chicago";
  try {
    const fmt = new Intl.DateTimeFormat("en-US", {
      timeZone: tz,
      weekday: "short",
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
      second: "2-digit",
      hour12: !state.datetime.use_24h,
    });
    const parts = {};
    fmt.formatToParts(dateObj).forEach((p) => { parts[p.type] = p.value; });
    const dateStr = `${parts.weekday} ${parts.month} ${parts.day}`;
    const secPart = state.datetime.show_seconds ? `:${parts.second}` : "";
    const ampmPart = (!state.datetime.use_24h && parts.dayPeriod) ? ` ${parts.dayPeriod}` : "";
    const timeStr = `${parts.hour}:${parts.minute}${secPart}${ampmPart}`;
    return { dateStr, timeStr, fullStr: `${dateStr} &nbsp; ${timeStr}`, year: parts.year };
  } catch {
    const days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    let h = dateObj.getHours();
    const ampm = h >= 12 ? "PM" : "AM";
    if (!state.datetime.use_24h) h = h % 12 || 12;
    const m = String(dateObj.getMinutes()).padStart(2, "0");
    const s = state.datetime.show_seconds ? ":" + String(dateObj.getSeconds()).padStart(2, "0") : "";
    const dateStr = `${days[dateObj.getDay()]} ${months[dateObj.getMonth()]} ${dateObj.getDate()}`;
    const timeStr = `${h}:${m}${s}${state.datetime.use_24h ? "" : " " + ampm}`;
    return { dateStr, timeStr, fullStr: `${dateStr} &nbsp; ${timeStr}`, year: dateObj.getFullYear() };
  }
}

// Live Ticking Clock
function updateClock() {
  const now = getAdjustedNow();
  const { fullStr, dateStr, timeStr, year } = formatClockParts(now);
  const trayClock = document.getElementById("tray-clock");
  if (trayClock) trayClock.innerHTML = fullStr;
  const dtPreview = document.getElementById("settings-dt-preview");
  if (dtPreview) dtPreview.textContent = `${dateStr}, ${year} — ${timeStr} (${state.datetime.timezone})`;
}

function applyWallpaper(wp) {
  state.wallpaper = wp || "";
  const desk = document.getElementById("desktop");
  if (!desk) return;
  if (!state.wallpaper) {
    desk.style.backgroundImage = "";
    return;
  }
  if (state.wallpaper.startsWith("data:") || state.wallpaper.startsWith("blob:") || state.wallpaper.startsWith("http") || state.wallpaper.startsWith("assets/")) {
    desk.style.backgroundImage = `url('${state.wallpaper}')`;
  } else {
    desk.style.backgroundImage = `url('/api/fs/raw?path=${encodeURIComponent(state.wallpaper)}')`;
  }
}

function showDesktopToast(id, title, bodyText, onClick) {
  const tray = document.getElementById("toast-tray");
  if (!tray) return;
  const old = document.getElementById(id);
  if (old) old.remove();
  const el = document.createElement("div");
  el.id = id;
  el.className = "nova-toast";
  el.innerHTML = `
    <div class="nova-toast-hdr">
      <span>🔔 ${escapeHtml(title)}</span>
      <button class="nova-toast-close" title="Dismiss">✕</button>
    </div>
    <div style="font-size:13.5px;line-height:1.4;opacity:0.92">${escapeHtml(bodyText)}</div>
  `;
  el.querySelector(".nova-toast-close").addEventListener("click", (e) => {
    e.stopPropagation();
    el.remove();
  });
  el.addEventListener("click", () => {
    el.remove();
    if (onClick) onClick();
  });
  tray.appendChild(el);
}

function showActivationNotification() {
  if (state.activated) return;
  showDesktopToast(
    "toast-activate-pc",
    "Activate your PC",
    "Your copy of Nova OS 2 is not activated. Click here to activate in Settings.",
    () => openSettings("activation")
  );
}

function updateStartUserBadge() {
  const b = document.getElementById("start-user-badge");
  if (!b) return;
  const uname = (state.userAccount && state.userAccount.username) ? state.userAccount.username : "";
  if (uname && uname !== "User") {
    b.textContent = `👤 ${uname}`;
    b.classList.remove("hidden");
  } else {
    b.classList.add("hidden");
  }
}

function setTheme(theme) {
  state.theme = theme;
  document.body.classList.toggle("theme-dark", theme === "dark");
  document.body.classList.toggle("theme-light", theme !== "dark");
  const startImg = document.getElementById("start-btn-img");
  if (startImg) {
    startImg.src = theme === "dark" ? "assets/start_btn_dark.png" : "assets/start_btn_light.png";
  }
  const lightBtn = document.getElementById("btn-theme-light");
  const darkBtn = document.getElementById("btn-theme-dark");
  if (lightBtn && darkBtn) {
    lightBtn.classList.toggle("active", theme === "light");
    darkBtn.classList.toggle("active", theme === "dark");
  }
  fetch("/api/theme", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ theme }),
  }).catch(() => {});
}

function updateTrayNetwork() {
  const iconEl = document.getElementById("tray-net-icon");
  const lblEl = document.getElementById("tray-net-label");
  if (state.netMode === "ethernet" && state.netConnected) {
    iconEl.innerHTML = TRAY_ICONS.ethernet;
    lblEl.textContent = state.wifiSsid || "enp0s3 (Ethernet)";
  } else if (state.netMode === "wifi") {
    iconEl.innerHTML = TRAY_ICONS.wifi;
    lblEl.textContent = state.netConnected ? state.wifiSsid : "Wi-Fi (No Network)";
  } else {
    iconEl.innerHTML = TRAY_ICONS.none;
    lblEl.textContent = "Not Connected";
  }
}

function isInstalled(appId) {
  return state.installedApps.includes(appId);
}

function recordAppUsage(appId) {
  const cur = state.appUsage[appId] || { count: 0, last_used: 0 };
  cur.count = (cur.count || 0) + 1;
  cur.last_used = Date.now();
  state.appUsage[appId] = cur;
  fetch("/api/apps/use", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ app_id: appId }),
  }).catch(() => {});
  renderStartMenuGrid();
}

/**
 * Sort installed apps for the Start Menu:
 * 1. Used apps (count > 0) appear FIRST at the top:
 *    ordered from Most Recently Used / Most Used at the top -> Least Used at the bottom.
 * 2. Unused apps (count === 0) appear AFTER used apps:
 *    ordered in Alphabetical Order (A -> Z).
 */
function getSortedStartMenuApps() {
  const query = (state.startSearchQuery || "").trim().toLowerCase();
  const installedList = ALL_APPS.filter((a) => isInstalled(a.id)).filter((a) => {
    if (!query) return true;
    return a.label.toLowerCase().includes(query) || a.id.toLowerCase().includes(query);
  });

  return installedList.sort((a, b) => {
    const ua = state.appUsage[a.id] || { count: 0, last_used: 0 };
    const ub = state.appUsage[b.id] || { count: 0, last_used: 0 };
    const aUsed = ua.count > 0;
    const bUsed = ub.count > 0;

    if (aUsed && !bUsed) return -1;
    if (!aUsed && bUsed) return 1;
    if (aUsed && bUsed) {
      if (ub.last_used !== ua.last_used) return ub.last_used - ua.last_used;
      if (ub.count !== ua.count) return ub.count - ua.count;
    }
    return a.label.localeCompare(b.label);
  });
}

function renderStartMenuGrid() {
  const grid = document.getElementById("start-menu-grid");
  if (!grid) return;
  grid.innerHTML = "";

  const sortedApps = getSortedStartMenuApps();
  sortedApps.forEach((app) => {
    const usage = state.appUsage[app.id] || { count: 0 };
    const el = document.createElement("div");
    el.className = "start-app-tile";
    el.dataset.appId = app.id;
    const badgeHtml = usage.count > 0 ? `<div class="start-app-usage-badge">${usage.count}x</div>` : "";
    el.innerHTML = `${badgeHtml}<div>${app.icon}</div><span>${app.label}</span>`;
    el.addEventListener("click", () => {
      document.getElementById("start-menu").classList.add("hidden");
      openApp(app.id);
    });
    grid.appendChild(el);
  });

  // If no search query and fewer than 8 installed apps, show clean empty grey slots
  // (NEVER show blacked-out uninstalled apps or "(Store)" labels!)
  if (!state.startSearchQuery && sortedApps.length < 8) {
    for (let i = sortedApps.length; i < 8; i++) {
      const empty = document.createElement("div");
      empty.className = "start-app-tile empty-slot";
      grid.appendChild(empty);
    }
  }
}

function renderIcons() {
  const desk = document.getElementById("desktop-icons");
  desk.innerHTML = "";

  // Only show installed apps on the desktop!
  const deskList = ALL_APPS.filter((a) => isInstalled(a.id));

  deskList.forEach((app) => {
    const el = document.createElement("div");
    el.className = "desk-icon";
    el.dataset.appId = app.id;
    el.innerHTML = `<div class="desk-icon-img">${app.icon}</div><div class="desk-icon-label">${app.label}</div>`;
    el.addEventListener("click", () => openApp(app.id));
    desk.appendChild(el);
  });

  renderStartMenuGrid();
}

// Window Manager
function createWindow(id, title, width, height, left, top, contentHtml) {
  if (state.windows[id]) {
    const existing = state.windows[id];
    existing.el.classList.remove("hidden");
    existing.el.style.zIndex = ++state.topZ;
    return existing.el;
  }

  const win = document.createElement("div");
  win.className = "nova-window";
  win.style.width = `${width}px`;
  win.style.height = `${height}px`;
  win.style.left = `${left}px`;
  win.style.top = `${top}px`;
  win.style.zIndex = ++state.topZ;

  win.innerHTML = `
    <div class="win-titlebar">
      <div class="win-title">${title}</div>
      <div class="win-controls">
        <button class="win-ctrl-btn min" title="Minimize">—</button>
        <button class="win-ctrl-btn max" title="Maximize">
          <svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2">
            <rect x="4" y="7" width="13" height="13" />
            <polyline points="8,7 8,4 20,4 20,16 17,16" />
          </svg>
        </button>
        <button class="win-ctrl-btn close" title="Close">✕</button>
      </div>
    </div>
    <div class="win-body">${contentHtml}</div>
    <div class="win-resize-handle"></div>
  `;

  win.addEventListener("mousedown", () => {
    win.style.zIndex = ++state.topZ;
  });

  const tb = win.querySelector(".win-titlebar");
  tb.ondragstart = () => false;
  let dragging = false, offX = 0, offY = 0;

  const startDrag = (e) => {
    if (e.button !== 0 || e.target.closest(".win-controls")) return;
    e.preventDefault();
    win.style.zIndex = ++state.topZ;
    if (win.classList.contains("maximized")) {
      win.classList.remove("maximized");
      const targetLeft = Math.max(0, Math.min(window.innerWidth - width, e.clientX - width / 2));
      win.style.left = `${targetLeft}px`;
      win.style.top = `10px`;
      win.style.width = `${width}px`;
      win.style.height = `${height}px`;
    }
    dragging = true;
    offX = e.clientX - win.offsetLeft;
    offY = e.clientY - win.offsetTop;
  };
  const moveDrag = (e) => {
    if (!dragging) return;
    const nx = Math.max(0, Math.min(window.innerWidth - 100, e.clientX - offX));
    const ny = Math.max(0, Math.min(window.innerHeight - 110, e.clientY - offY));
    win.style.left = `${nx}px`;
    win.style.top = `${ny}px`;
  };
  const endDrag = () => { dragging = false; };

  tb.addEventListener("mousedown", startDrag);
  window.addEventListener("mousemove", moveDrag);
  window.addEventListener("mouseup", endDrag);

  const rh = win.querySelector(".win-resize-handle");
  rh.ondragstart = () => false;
  let resizing = false, startW = 0, startH = 0, startX = 0, startY = 0;
  const startResize = (e) => {
    if (e.button !== 0) return;
    e.stopPropagation();
    e.preventDefault();
    resizing = true;
    startW = win.offsetWidth;
    startH = win.offsetHeight;
    startX = e.clientX;
    startY = e.clientY;
  };
  const moveResize = (e) => {
    if (!resizing) return;
    win.style.width = `${Math.max(440, startW + (e.clientX - startX))}px`;
    win.style.height = `${Math.max(300, startH + (e.clientY - startY))}px`;
  };
  const endResize = () => { resizing = false; };
  rh.addEventListener("mousedown", startResize);
  window.addEventListener("mousemove", moveResize);
  window.addEventListener("mouseup", endResize);

  win.querySelector(".min").addEventListener("click", () => win.classList.add("hidden"));
  win.querySelector(".max").addEventListener("click", () => win.classList.toggle("maximized"));
  win.querySelector(".close").addEventListener("click", () => {
    window.removeEventListener("mousemove", moveDrag);
    window.removeEventListener("mouseup", endDrag);
    window.removeEventListener("mousemove", moveResize);
    window.removeEventListener("mouseup", endResize);
    if (win._cleanup) {
      try { win._cleanup(); } catch {}
    }
    win.remove();
    delete state.windows[id];
    renderTaskbarApps();
  });

  document.getElementById("windows-layer").appendChild(win);
  state.windows[id] = { id, title, el: win };
  renderTaskbarApps();
  return win;
}

function renderTaskbarApps() {
  const bar = document.getElementById("taskbar-apps");
  bar.innerHTML = "";
  Object.values(state.windows).forEach((w) => {
    const btn = document.createElement("button");
    btn.className = "taskbar-app-pill";
    btn.textContent = w.title;
    btn.addEventListener("click", () => {
      w.el.classList.toggle("hidden");
      w.el.style.zIndex = ++state.topZ;
    });
    bar.appendChild(btn);
  });
}

// Open App Dispatcher (tracks usage for Start Menu MRU sorting)
function openApp(id, opts = {}) {
  const coreApps = ["wifi", "settings", "files", "appstore"];
  if (!coreApps.includes(id) && !isInstalled(id)) {
    return openAppStore(id);
  }
  recordAppUsage(id);
  if (id === "settings") return openSettings(opts.tab || "about");
  if (id === "wifi") return openWifiApp();
  if (id === "files" || id === "explorer") return openExplorer();
  if (id === "appstore" || id === "chrome_store") return openAppStore();
  if (id === "terminal") return openTerminal();
  if (id === "notepad") return openNotepad(opts.file || "Documents/Welcome_to_NovaOS_2.00.txt");
  if (id === "chrome") return openChrome(opts.url || "");
  if (id === "youtube") return openYouTube();
  if (id === "exetonosp") return openExeToNosp(opts.file || "");
  if (id === "videoplayer") return openVideoPlayer(opts.file || "Videos/NovaOS_2.00_Showcase_1080p.mp4");
  if (id === "dvdplayer") return openDVDPlayer(opts.file || "Videos/NovaOS_DVD_Feature_1080p.mp4");
  if (id === "musicstudio") return openMusicStudio(opts.file || "");
  if (id === "paintstudio") return openPaintStudio();
  if (id === "calculator") return openCalculator();
  if (id === "imageviewer") return openImageViewer(opts.file || "");
  if (id === "sysmonitor") return openSysMonitor();
  if (id === "clock") return openClockApp();
  if (id === "calendar") return openCalendarApp();
  if (id === "tasks") return openTasksApp();
  if (id === "codeide") return openCodeStudio(opts.file || "");
  if (id === "diskutil") return openDiskManager();
  if (id === "nettools") return openNetTools();
  if (id === "snake") return openSnakeGame();
  if (id === "mines") return openMinesweeperGame();
  if (id === "game2048") return open2048Game();
  if (id === "weather") return openWeatherApp();
  if (id === "piano") return openPianoApp();
  if (id === "pomodoro") return openPomodoroApp();
  if (id === "converter") return openConverterApp();
  if (id === "tictactoe") return openTicTacToeApp();
  if (id === "devtools") return openDevToolsApp();
  if (id === "journal") return openJournalApp();
  if (id === "recorder") return openRecorderApp();
  if (id === "budget") return openBudgetApp();
  if (id === "sticky") return openStickyNotesApp();
  if (id === "memory") return openMemoryGame();
  if (id === "markdown") return openMarkdownApp();
  if (id === "colorstudio") return openColorStudioApp();
  if (id === "qrlab") return openQRLabApp();
  return openLiveCustomApp(id);
}

// ============================================================================
// 1. SETTINGS APP (About, Personalization, Date & Time, Update Server Flow)
// ============================================================================
function bindInstantClick(el, fn) {
  if (!el) return;
  let fired = false;
  el.addEventListener("pointerdown", (e) => {
    e.preventDefault();
    fired = true;
    fn(e);
    setTimeout(() => { fired = false; }, 250);
  });
  el.addEventListener("click", (e) => {
    if (!fired) fn(e);
  });
}

function openSettings(initialTab = "about") {
  let changingKey = false;
  const win = createWindow("settings", "Settings", 900, 560, 580, 95, `
    <div class="settings-layout">
      <div class="settings-sidebar">
        <button class="settings-tab-btn" data-tab="about">About</button>
        <button class="settings-tab-btn" data-tab="personalization">Personalization</button>
        <button class="settings-tab-btn" data-tab="activation">Activation</button>
        <button class="settings-tab-btn" data-tab="datetime">Date &amp; Time</button>
        <button class="settings-tab-btn" data-tab="update">Update</button>
      </div>
      <div id="settings-content" class="settings-content"></div>
    </div>
  `);

  const showTab = (tab) => {
    win.querySelectorAll(".settings-tab-btn").forEach((b) =>
      b.classList.toggle("active", b.dataset.tab === tab)
    );
    const body = win.querySelector("#settings-content");
    if (tab === "about") {
      body.innerHTML = `
        <div style="font-size:28px;font-weight:700;margin-bottom:4px">This PC:</div>
        <div style="padding-left:26px;font-size:22px;line-height:1.45">
          <div>Edition: <span style="font-weight:700;color:#2563EB">${escapeHtml(state.sysinfo.edition || "Nova OS 2.00 Pro")}</span> ${state.activated ? '<span style="font-size:13px;padding:2px 8px;border-radius:6px;background:#16A34A;color:#FFF">Activated</span>' : '<span style="font-size:13px;padding:2px 8px;border-radius:6px;background:#F59E0B;color:#000">Not Activated</span>'}</div>
          <div>CPU: <span style="font-size:19px">${escapeHtml(state.sysinfo.cpu)}</span></div>
          <div>Memory: ${escapeHtml(state.sysinfo.ram || "4.0 GB")}</div>
          <div>Graphics: ${escapeHtml(state.sysinfo.gpu)}</div>
          <div>Display: ${escapeHtml(state.sysinfo.display || "1920x1080 (1080p) 60Hz")}</div>
          <div>User: ${escapeHtml((state.userAccount && state.userAccount.username) || "User")}</div>
          <div>Version: ${escapeHtml(state.sysinfo.version).replace("\n", "<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;")}</div>
        </div>
      `;
    } else if (tab === "personalization") {
      const fontOpts = (state.fonts || ["Segoe UI"]).map((f) =>
        `<option value="${f}" ${state.systemFont === f ? "selected" : ""} style="font-family:'${f}',sans-serif">${f}</option>`
      ).join("");
      const isCustomWp = Boolean(state.wallpaper);
      body.innerHTML = `
        <div class="settings-row">
          <div class="settings-label">Theme:</div>
          <div class="choice-stack">
            <button id="btn-theme-light" class="choice-btn ${state.theme === "light" ? "active" : ""}">Light</button>
            <button id="btn-theme-dark" class="choice-btn ${state.theme === "dark" ? "active" : ""}">Dark</button>
          </div>
        </div>
        <div class="settings-row">
          <div class="settings-label">Background:</div>
          <div class="choice-stack">
            <button id="btn-bg-default" class="choice-btn ${!isCustomWp ? "active" : ""}">Default</button>
            <button id="btn-bg-local" class="choice-btn ${isCustomWp ? "active" : ""}">Local File</button>
          </div>
        </div>
        <div id="pers-local-box" style="margin-top:8px;padding:12px 14px;border-radius:10px;background:rgba(148,163,184,0.12);display:flex;flex-direction:column;gap:8px">
          <div style="display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap">
            <span style="font-size:13.5px;font-weight:700">Local Background File ${state.wallpaper ? `(Active: ${escapeHtml(state.wallpaper)})` : "(Pictures / Downloads / Upload)"}</span>
            <button id="btn-bg-upload" class="btn-primary">Browse Local File...</button>
          </div>
          <div id="pers-disk-imgs" class="pers-img-grid"><span style="font-size:12.5px;color:#64748B">Loading images from Pictures &amp; Downloads...</span></div>
        </div>
        <div class="settings-row" style="margin-top:8px">
          <div class="settings-label">System Font (${(state.fonts || []).length}):</div>
          <div style="display:flex;gap:10px;align-items:center">
            <select id="sel-sys-font" style="padding:8px 12px;border-radius:8px;border:1px solid #94A3B8;font-size:15px;min-width:260px">${fontOpts}</select>
            <button id="btn-reset-font" class="btn-secondary">Reset</button>
          </div>
        </div>
      `;
      bindInstantClick(body.querySelector("#btn-theme-light"), () => setTheme("light"));
      bindInstantClick(body.querySelector("#btn-theme-dark"), () => setTheme("dark"));
      const saveWp = (wpRel) => {
        applyWallpaper(wpRel);
        fetch("/api/wallpaper", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ wallpaper: wpRel }),
        }).catch(() => {});
        showTab("personalization");
      };
      bindInstantClick(body.querySelector("#btn-bg-default"), () => saveWp(""));
      bindInstantClick(body.querySelector("#btn-bg-local"), () => {
        body.querySelector("#btn-bg-local").classList.add("active");
        body.querySelector("#btn-bg-default").classList.remove("active");
        document.getElementById("bg-file-input").click();
      });
      body.querySelector("#btn-bg-upload").addEventListener("click", () => {
        document.getElementById("bg-file-input").click();
      });
      fetch("/api/fs/images").then((r) => r.json()).then((res) => {
        const grid = body.querySelector("#pers-disk-imgs");
        if (!grid) return;
        const imgs = (res && res.images) || [];
        if (imgs.length === 0) {
          grid.innerHTML = `<span style="font-size:12.5px;color:#64748B">No local images in Pictures/ or Downloads/ yet. Click "Browse Local File..." or Paint Studio / Chrome Download to add one.</span>`;
          return;
        }
        grid.innerHTML = "";
        imgs.forEach((im) => {
          const thumb = document.createElement("img");
          thumb.src = `/api/fs/raw?path=${encodeURIComponent(im.rel)}`;
          thumb.title = im.rel;
          thumb.className = `pers-thumb ${state.wallpaper === im.rel ? "active" : ""}`;
          thumb.addEventListener("click", () => saveWp(im.rel));
          grid.appendChild(thumb);
        });
      }).catch(() => {});
      const fontSel = body.querySelector("#sel-sys-font");
      fontSel.addEventListener("change", () => {
        state.systemFont = fontSel.value;
        document.body.style.fontFamily = `'${state.systemFont}', 'Inter', 'Segoe UI', sans-serif`;
        fetch("/api/font", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ font: state.systemFont }) }).catch(() => {});
      });
      body.querySelector("#btn-reset-font").addEventListener("click", () => {
        state.systemFont = "Segoe UI";
        fontSel.value = "Segoe UI";
        document.body.style.fontFamily = "";
        fetch("/api/font", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ font: "Segoe UI" }) }).catch(() => {});
      });
    } else if (tab === "activation") {
      const submitActivation = async (keyVal, errEl) => {
        const k = (keyVal || "").trim();
        if (!k) { errEl.textContent = "Please enter a product key."; return; }
        const res = await fetch("/api/activation/activate", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ key: k }),
        }).then((r) => r.json()).catch(() => ({ ok: false, error: "Network error" }));
        if (!res.ok) {
          errEl.textContent = res.error || "Invalid product key.";
          return;
        }
        state.activated = true;
        state.activationBypassed = false;
        state.activationKey = res.activation_key || k;
        if (res.installed_apps) state.installedApps = res.installed_apps;
        if (res.sysinfo) state.sysinfo = res.sysinfo;
        else {
          state.sysinfo.edition_short = res.edition || state.sysinfo.edition_short;
          state.sysinfo.edition = `Nova OS 2.00 ${res.edition || "Pro"}`;
          state.sysinfo.activated = true;
        }
        changingKey = false;
        const toast = document.getElementById("toast-activate-pc");
        if (toast) toast.remove();
        renderIcons();
        showTab("activation");
      };

      const edShort = state.sysinfo.edition_short || (String(state.sysinfo.edition || "").includes("Home") ? "Home" : "Pro");
      if (!state.activated && !changingKey) {
        body.innerHTML = `
          <div style="display:flex;flex-direction:column;height:100%;justify-content:space-between">
            <div style="display:flex;flex-direction:column;gap:14px">
              <div style="font-size:26px;font-weight:800">Activation</div>
              <div style="padding:12px 16px;border-radius:10px;background:rgba(245,158,11,0.16);border:1px solid #F59E0B;font-size:15px;font-weight:700">
                Nova OS is not activated — Activate your PC to unlock full personalization &amp; edition features.
              </div>
              <div style="display:flex;flex-direction:column;gap:8px;max-width:460px;margin-top:6px">
                <label style="font-size:16px;font-weight:700">Product key:</label>
                <input id="act-key-inp" placeholder="Nova2-xxxxx-xxxxx-xxxxx-xxxxx" style="padding:10px 14px;border-radius:8px;border:1.5px solid #2563EB;font-size:16px;letter-spacing:0.6px" />
                <div style="display:flex;gap:10px;align-items:center">
                  <button id="act-submit-btn" class="btn-primary">Activate</button>
                </div>
                <div id="act-err" style="font-size:13.5px;color:#DC2626;font-weight:600"></div>
              </div>
            </div>
            <div style="font-size:12.5px;color:#64748B">Case-insensitive (Home or Pro keys accepted)</div>
          </div>
        `;
        const inp = body.querySelector("#act-key-inp");
        const err = body.querySelector("#act-err");
        body.querySelector("#act-submit-btn").addEventListener("click", () => submitActivation(inp.value, err));
        inp.addEventListener("keydown", (e) => { if (e.key === "Enter") submitActivation(inp.value, err); });
      } else if (changingKey) {
        body.innerHTML = `
          <div style="display:flex;flex-direction:column;height:100%;justify-content:space-between">
            <div style="display:flex;flex-direction:column;gap:14px">
              <div style="font-size:26px;font-weight:800">Change product key</div>
              <div style="display:flex;flex-direction:column;gap:8px;max-width:460px">
                <label style="font-size:16px;font-weight:700">Change product key:</label>
                <input id="act-change-inp" placeholder="Nova2-xxxxx-xxxxx-xxxxx-xxxxx" style="padding:10px 14px;border-radius:8px;border:1.5px solid #2563EB;font-size:16px;letter-spacing:0.6px" />
                <div style="display:flex;gap:10px">
                  <button id="act-change-submit" class="btn-primary">Activate</button>
                </div>
                <div id="act-change-err" style="font-size:13.5px;color:#DC2626;font-weight:600"></div>
              </div>
            </div>
            <div style="border-top:1px solid rgba(148,163,184,0.28);padding-top:12px">
              <button id="act-change-cancel" class="btn-secondary">Cancel</button>
            </div>
          </div>
        `;
        const inp = body.querySelector("#act-change-inp");
        const err = body.querySelector("#act-change-err");
        body.querySelector("#act-change-submit").addEventListener("click", () => submitActivation(inp.value, err));
        inp.addEventListener("keydown", (e) => { if (e.key === "Enter") submitActivation(inp.value, err); });
        body.querySelector("#act-change-cancel").addEventListener("click", () => {
          changingKey = false;
          showTab("activation");
        });
      } else {
        body.innerHTML = `
          <div style="display:flex;flex-direction:column;height:100%;justify-content:space-between">
            <div style="display:flex;flex-direction:column;gap:12px">
              <div style="font-size:26px;font-weight:800">Activation</div>
              <div style="padding:16px 20px;border-radius:12px;background:rgba(22,163,74,0.14);border:1px solid #16A34A;display:flex;flex-direction:column;gap:6px">
                <div style="font-size:22px;font-weight:800;color:#2563EB">Nova OS 2 ${escapeHtml(edShort)}</div>
                <div style="font-size:15px;font-weight:700;color:#16A34A">✓ Nova OS is activated</div>
                ${state.activationKey ? `<div style="font-size:13px;opacity:0.8">Active Key: <code>${escapeHtml(state.activationKey)}</code></div>` : ""}
              </div>
            </div>
            <div style="border-top:1px solid rgba(148,163,184,0.28);padding-top:12px">
              <button id="act-change-open" class="setup-link-btn" style="font-size:15px;font-weight:600">Change my product key</button>
            </div>
          </div>
        `;
        body.querySelector("#act-change-open").addEventListener("click", () => {
          changingKey = true;
          showTab("activation");
        });
      }
    } else if (tab === "datetime") {
      const adj = getAdjustedNow();
      const yyyy = adj.getFullYear();
      const mm = String(adj.getMonth() + 1).padStart(2, "0");
      const dd = String(adj.getDate()).padStart(2, "0");
      const hh = String(adj.getHours()).padStart(2, "0");
      const mi = String(adj.getMinutes()).padStart(2, "0");
      body.innerHTML = `
        <div style="display:flex;flex-direction:column;gap:16px">
          <div>
            <div style="font-size:24px;font-weight:700">Date &amp; Time Settings</div>
            <div id="settings-dt-preview" style="font-size:17px;color:#2563EB;font-weight:600;margin-top:4px"></div>
          </div>

          <div style="display:flex;flex-direction:column;gap:6px">
            <label style="font-size:15px;font-weight:700">Time Zone:</label>
            <select id="dt-tz-select" style="padding:9px 12px;border-radius:8px;border:1px solid #94A3B8;font-size:15px;max-width:440px">
              <option value="America/Chicago">US Central Time (America/Chicago — UTC-06:00)</option>
              <option value="America/New_York">US Eastern Time (America/New_York — UTC-05:00)</option>
              <option value="America/Denver">US Mountain Time (America/Denver — UTC-07:00)</option>
              <option value="America/Los_Angeles">US Pacific Time (America/Los_Angeles — UTC-08:00)</option>
              <option value="UTC">Coordinated Universal Time (UTC+00:00)</option>
              <option value="Europe/London">London / GMT (Europe/London)</option>
              <option value="Europe/Paris">Central European Time (Europe/Paris)</option>
              <option value="Asia/Tokyo">Japan Standard Time (Asia/Tokyo — UTC+09:00)</option>
            </select>
          </div>

          <div style="display:flex;flex-direction:column;gap:8px;padding:14px;border-radius:12px;background:rgba(148,163,184,0.14);max-width:480px">
            <div style="font-size:15px;font-weight:700">Manually Set Date &amp; Time:</div>
            <div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap">
              <input id="dt-date-inp" type="date" value="${yyyy}-${mm}-${dd}" style="padding:8px 10px;border-radius:8px;border:1px solid #94A3B8;font-size:14px" />
              <input id="dt-time-inp" type="time" value="${hh}:${mi}" style="padding:8px 10px;border-radius:8px;border:1px solid #94A3B8;font-size:14px" />
              <button id="dt-apply-btn" class="btn-primary">Apply Date &amp; Time</button>
              <button id="dt-sync-btn" class="btn-secondary">Sync Real Time</button>
            </div>
            <div id="dt-status-msg" style="font-size:13px;color:#16A34A;font-weight:600"></div>
          </div>

          <div style="display:flex;gap:16px;align-items:center">
            <label style="display:flex;align-items:center;gap:6px;font-size:15px;font-weight:600;cursor:pointer">
              <input id="dt-24h-chk" type="checkbox" ${state.datetime.use_24h ? "checked" : ""} />
              Use 24-Hour Clock
            </label>
            <label style="display:flex;align-items:center;gap:6px;font-size:15px;font-weight:600;cursor:pointer">
              <input id="dt-sec-chk" type="checkbox" ${state.datetime.show_seconds ? "checked" : ""} />
              Show Seconds in Taskbar
            </label>
          </div>
        </div>
      `;
      const tzSel = body.querySelector("#dt-tz-select");
      tzSel.value = state.datetime.timezone || "America/Chicago";
      updateClock();

      const saveDt = () => {
        fetch("/api/datetime", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify(state.datetime),
        }).catch(() => {});
        updateClock();
      };

      tzSel.addEventListener("change", () => {
        state.datetime.timezone = tzSel.value;
        saveDt();
        body.querySelector("#dt-status-msg").textContent = `Time zone updated to ${tzSel.value}!`;
      });

      bindInstantClick(body.querySelector("#dt-apply-btn"), () => {
        const dVal = body.querySelector("#dt-date-inp").value;
        const tVal = body.querySelector("#dt-time-inp").value;
        if (!dVal || !tVal) return;
        const targetMs = new Date(`${dVal}T${tVal}:00`).getTime();
        if (!isNaN(targetMs)) {
          state.datetime.offset_ms = targetMs - Date.now();
          saveDt();
          body.querySelector("#dt-status-msg").textContent = "System Date & Time updated!";
        }
      });

      bindInstantClick(body.querySelector("#dt-sync-btn"), () => {
        state.datetime.offset_ms = 0;
        state.datetime.timezone = "America/Chicago";
        tzSel.value = "America/Chicago";
        saveDt();
        body.querySelector("#dt-status-msg").textContent = "Synced to US Central Time (America/Chicago)!";
      });

      body.querySelector("#dt-24h-chk").addEventListener("change", (e) => {
        state.datetime.use_24h = e.target.checked;
        saveDt();
      });
      body.querySelector("#dt-sec-chk").addEventListener("change", (e) => {
        state.datetime.show_seconds = e.target.checked;
        saveDt();
      });
    } else if (tab === "update") {
      renderUpdateStage(body);
    }
  };

  if (!win.dataset.tabsBound) {
    win.dataset.tabsBound = "1";
    win.querySelectorAll(".settings-tab-btn").forEach((b) => {
      bindInstantClick(b, () => showTab(b.dataset.tab));
    });
  }
  showTab(initialTab);
}

function renderUpdateStage(container) {
  if (state.updateStage === "initial") {
    container.innerHTML = `
      <div class="update-box">
        <div class="update-title-lg">Nova OS Update Server</div>
        <div class="update-sub-lg" style="margin-top:6px">Current Build: Nova OS (${state.sysinfo.build})</div>
        <button id="btn-check-updates" class="install-now-btn" style="margin-top:20px">Check for Updates</button>
      </div>
    `;
    container.querySelector("#btn-check-updates").addEventListener("click", () => {
      state.updateStage = "looking";
      renderUpdateStage(container);
      setTimeout(async () => {
        try {
          const res = await fetch(
            `/api/update/check?current_version=${encodeURIComponent(state.sysinfo.build)}&mode=${encodeURIComponent(state.updateCheckMode)}`
          ).then((r) => r.json());
          state.updateStage = res.available ? "found" : "up_to_date";
        } catch {
          state.updateStage = state.sysinfo.build === "27300" ? "up_to_date" : "found";
        }
        renderUpdateStage(container);
      }, 900);
    });
  } else if (state.updateStage === "looking") {
    container.innerHTML = `
      <div class="update-looking-row">
        <span>Looking for Updates</span>
        <span class="update-inline-spinner"></span>
      </div>
    `;
  } else if (state.updateStage === "found") {
    container.innerHTML = `
      <div class="update-box">
        <div class="update-title-lg">Updates found:</div>
        <div class="update-sub-lg">Theres a new version of\nNova OS (27300)</div>
        <button id="btn-install-now" class="install-now-btn">Install Now?</button>
      </div>
    `;
    container.querySelector("#btn-install-now").addEventListener("click", async () => {
      document.getElementById("install-screen").classList.remove("hidden");
      try {
        await fetch("/api/update/install", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ version: "27300" }),
        });
      } catch {}
      setTimeout(() => {
        document.getElementById("install-screen").classList.add("hidden");
        state.sysinfo.build = "27300";
        state.sysinfo.version = "Nova OS 2.00 Beta 4\n(Build 27300)";
        state.updateStage = "up_to_date";
        renderUpdateStage(container);
      }, 2400);
    });
  } else if (state.updateStage === "up_to_date") {
    container.innerHTML = `
      <div class="update-box">
        <div class="update-title-lg">No Updates found:</div>
        <div class="update-sub-lg">You are already on the\nlatest version of Nova OS\n(${state.sysinfo.build})</div>
      </div>
    `;
  }
}

// ============================================================================
// 2. WIFI / ETHERNET APP (Real Hardware Detection — Zero Fake Networks!)
// ============================================================================
function openWifiApp() {
  const win = createWindow("wifi", "WiFi/Ethernet", 680, 500, 440, 130, `
    <div style="padding:20px 24px;display:flex;flex-direction:column;gap:14px;height:100%">
      <div style="padding:10px 14px;border-radius:10px;background:rgba(51,140,223,0.14);border:1px solid rgba(51,140,223,0.35);font-size:13px">
        <b>Network Stack:</b> ${state.wifiDriver}<br>
        <b>Connection Status:</b> <span id="wifi-app-status-txt">${state.netConnected ? `Connected (${state.netMode.toUpperCase()} — ${state.wifiSsid})` : "Disconnected"}</span>
      </div>

      <div style="display:flex;gap:10px">
        <button id="tab-mode-wifi" class="btn-primary" style="flex:1">Wi-Fi (WPA2-PSK)</button>
        <button id="tab-mode-eth" class="btn-secondary" style="flex:1">Ethernet (${state.ethInterfaces[0] || "enp0s3"} — No Password)</button>
      </div>

      <!-- Wi-Fi WPA2 Panel (Real Hardware Scan Only — Never Fake Networks) -->
      <div id="panel-mode-wifi" style="display:flex;flex-direction:column;gap:10px;flex:1;overflow:hidden">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <span style="font-weight:700;font-size:15px">Hardware 802.11 Wi-Fi Scan (WPA2-PSK):</span>
          <button id="wifi-app-scan" class="btn-small">Scan Real Hardware</button>
        </div>
        <div id="wifi-app-list" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:6px"></div>
        <div id="wifi-app-pw-box" style="padding:12px;border-radius:10px;background:rgba(148,163,184,0.14);display:flex;flex-direction:column;gap:8px">
          <div style="font-size:13px;font-weight:600">Manual / Hidden WPA2-PSK Wi-Fi Connection (Requires USB 802.11 Adapter in VirtualBox):</div>
          <div style="display:flex;gap:8px">
            <input id="wifi-app-ssid-input" type="text" placeholder="SSID (if physical Wi-Fi attached)" style="width:210px;padding:8px 10px;border-radius:8px;border:1px solid #94A3B8" />
            <input id="wifi-app-pw-input" type="password" placeholder="Enter WPA2-PSK Password..." style="flex:1;padding:8px 10px;border-radius:8px;border:1px solid #94A3B8" />
            <button id="wifi-app-connect-btn" class="btn-primary">Connect WPA2</button>
          </div>
          <div id="wifi-app-msg" style="font-size:12px;color:#64748B"></div>
        </div>
      </div>

      <!-- Ethernet Panel (VirtualBox NAT enp0s3 — No Password Required, Input Box Provided) -->
      <div id="panel-mode-eth" class="hidden" style="display:flex;flex-direction:column;gap:12px;padding-top:8px">
        <div style="font-size:15px;font-weight:700">Intel PRO/1000 MT Desktop Ethernet (${state.ethInterfaces[0] || "enp0s3"} — VirtualBox NAT)</div>
        <div style="font-size:13px;color:#64748B">Ethernet does not require a WPA2 password. Type the Ethernet interface or connection profile below to connect:</div>
        <input id="eth-profile-input" type="text" value="${state.ethInterfaces[0] || "enp0s3"} (Ethernet NAT)" placeholder="Type Ethernet interface or connection label..." style="padding:10px 12px;border-radius:8px;border:1px solid #94A3B8;font-size:14px" />
        <div style="display:flex;gap:10px">
          <button id="eth-connect-btn" class="btn-primary">Connect Ethernet</button>
          <button id="net-disconnect-btn" class="btn-secondary">Disconnect</button>
        </div>
        <div id="eth-app-msg" style="font-size:13px;color:#16A34A;font-weight:600"></div>
      </div>
    </div>
  `);

  const wifiPanel = win.querySelector("#panel-mode-wifi");
  const ethPanel = win.querySelector("#panel-mode-eth");
  const tabWifi = win.querySelector("#tab-mode-wifi");
  const tabEth = win.querySelector("#tab-mode-eth");

  tabWifi.addEventListener("click", () => {
    wifiPanel.classList.remove("hidden");
    ethPanel.classList.add("hidden");
    tabWifi.className = "btn-primary";
    tabEth.className = "btn-secondary";
    state.netMode = "wifi";
    updateTrayNetwork();
  });

  tabEth.addEventListener("click", () => {
    ethPanel.classList.remove("hidden");
    wifiPanel.classList.add("hidden");
    tabEth.className = "btn-primary";
    tabWifi.className = "btn-secondary";
  });

  const scanHardwareWifi = async () => {
    const list = win.querySelector("#wifi-app-list");
    list.innerHTML = `<div style="padding:14px;color:#64748B">Scanning physical 802.11 wireless interfaces...</div>`;
    try {
      const res = await fetch("/api/wifi/scan").then((r) => r.json());
      state.hasWifiHardware = Boolean(res.has_wifi_hardware);
      state.isVirtualBox = Boolean(res.is_virtualbox);
      state.ethInterfaces = res.ethernet_interfaces || ["enp0s3"];
      state.wifiNetworks = res.networks || [];
    } catch {
      state.wifiNetworks = [];
    }

    list.innerHTML = "";
    if (state.wifiNetworks.length === 0) {
      const emptyBox = document.createElement("div");
      emptyBox.style.cssText = "padding:18px;border-radius:12px;background:rgba(239,68,68,0.1);border:1px solid rgba(239,68,68,0.35);line-height:1.45";
      emptyBox.innerHTML = `
        <div style="font-weight:700;color:#DC2626;font-size:14px">0 Wi-Fi Networks Found (No Fake Networks)</div>
        <div style="font-size:13px;margin-top:4px">
          No physical 802.11 Wi-Fi adapter is attached to this VirtualBox VM (only virtual Ethernet <b>${state.ethInterfaces.join(", ")}</b> is present).
          Click the <b>Ethernet</b> tab above to connect via VirtualBox NAT, or pass through a physical USB Wi-Fi adapter.
        </div>
      `;
      list.appendChild(emptyBox);
      return;
    }

    state.wifiNetworks.forEach((n) => {
      const row = document.createElement("div");
      row.className = "wifi-net-item";
      row.innerHTML = `
        <div>
          <b>${n.ssid}</b>
          <div style="font-size:12px;color:#64748B">${n.security}</div>
        </div>
        <span style="font-size:13px;font-weight:600">${n.signal}</span>
      `;
      row.addEventListener("click", () => {
        state.selectedSsid = n.ssid;
        win.querySelector("#wifi-app-ssid-input").value = n.ssid;
        win.querySelector("#wifi-app-pw-input").focus();
      });
      list.appendChild(row);
    });
  };

  scanHardwareWifi();
  win.querySelector("#wifi-app-scan").addEventListener("click", scanHardwareWifi);

  win.querySelector("#wifi-app-connect-btn").addEventListener("click", async () => {
    const ssid = win.querySelector("#wifi-app-ssid-input").value.trim();
    const pw = win.querySelector("#wifi-app-pw-input").value;
    const msg = win.querySelector("#wifi-app-msg");
    if (!state.hasWifiHardware && state.wifiNetworks.length === 0) {
      msg.style.color = "#DC2626";
      msg.textContent = "Cannot connect Wi-Fi: No physical 802.11 Wi-Fi adapter detected in VirtualBox. Please use the Ethernet tab.";
      return;
    }
    if (!ssid || !pw) {
      msg.style.color = "#DC2626";
      msg.textContent = "Please select a real Wi-Fi SSID and enter its WPA2-PSK password.";
      return;
    }
    state.netMode = "wifi";
    state.netConnected = true;
    state.wifiSsid = ssid;
    updateTrayNetwork();
    await fetch("/api/wifi/connect", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ mode: "wifi", ssid, password: pw }),
    }).catch(() => {});
    win.querySelector("#wifi-app-status-txt").textContent = `Connected (WIFI WPA2-PSK — ${ssid})`;
    msg.style.color = "#16A34A";
    msg.textContent = `Connected to ${ssid} via WPA2-PSK!`;
  });

  win.querySelector("#eth-connect-btn").addEventListener("click", async () => {
    const label = win.querySelector("#eth-profile-input").value.trim() || "enp0s3 (Ethernet)";
    state.netMode = "ethernet";
    state.netConnected = true;
    state.wifiSsid = label;
    updateTrayNetwork();
    await fetch("/api/wifi/connect", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ mode: "ethernet", adapter: label }),
    }).catch(() => {});
    win.querySelector("#wifi-app-status-txt").textContent = `Connected (ETHERNET — ${label})`;
    win.querySelector("#eth-app-msg").textContent = `Connected to ${label} (No password required)! Internet & .NOSP App Store ready.`;
  });

  win.querySelector("#net-disconnect-btn").addEventListener("click", async () => {
    state.netConnected = false;
    state.netMode = "none";
    updateTrayNetwork();
    await fetch("/api/wifi/disconnect", { method: "POST" }).catch(() => {});
    win.querySelector("#wifi-app-status-txt").textContent = "Disconnected";
    win.querySelector("#eth-app-msg").textContent = "";
  });
}

async function openWifiFlyout() {
  const fly = document.getElementById("wifi-flyout");
  fly.classList.remove("hidden");
  const status = document.getElementById("wifi-flyout-status");
  const list = document.getElementById("wifi-network-list");
  const pwPanel = document.getElementById("wifi-password-panel");
  pwPanel.classList.add("hidden");
  list.innerHTML = "";
  status.textContent = "Scanning physical 802.11 hardware...";

  try {
    const res = await fetch("/api/wifi/scan").then((r) => r.json());
    state.hasWifiHardware = Boolean(res.has_wifi_hardware);
    state.wifiNetworks = res.networks || [];
  } catch {
    state.wifiNetworks = [];
  }

  if (state.wifiNetworks.length === 0) {
    status.textContent = "0 physical Wi-Fi networks detected in VirtualBox:";
    list.innerHTML = `
      <div style="padding:12px;border-radius:10px;background:rgba(239,68,68,0.12);font-size:12px;line-height:1.4">
        <b>No physical 802.11 Wi-Fi card in VirtualBox VM.</b><br>
        Zero fake networks are shown. Open <b>WiFi/Ethernet</b> to connect via <b>Ethernet (enp0s3)</b>.
      </div>
    `;
    return;
  }

  status.textContent = "Select a real WPA2-PSK Wi-Fi network:";
  state.wifiNetworks.forEach((net) => {
    const item = document.createElement("div");
    item.className = "wifi-net-item";
    item.innerHTML = `<div><b>${net.ssid}</b><div style="font-size:12px;color:#64748B">${net.security}</div></div><span style="font-size:12px">${net.signal}</span>`;
    item.addEventListener("click", () => {
      state.selectedSsid = net.ssid;
      document.getElementById("wifi-selected-ssid").textContent = `Connect to ${net.ssid} (WPA2-PSK)`;
      document.getElementById("wifi-password-input").value = "";
      pwPanel.classList.remove("hidden");
      document.getElementById("wifi-password-input").focus();
    });
    list.appendChild(item);
  });
}

// ============================================================================
// 3. APP STORE (Downloads Real .NOSP Packages from Server — 8 Downloadable Apps)
// ============================================================================
function openAppStore(highlightAppId = null, forceDelayMs = null) {
  const win = createWindow("appstore", "Nova OS App Store (.NOSP Package Server)", 860, 560, 380, 90, `
    <div id="store-root" style="height:100%;display:flex;flex-direction:column"></div>
  `);

  const root = win.querySelector("#store-root");

  const loadStore = () => {
    // When offline: spin loading disk for 5 seconds (5000ms), then say "Please connect your device to the internet"
    const isOnline = state.netConnected;
    const waitTime = forceDelayMs !== null ? forceDelayMs : (isOnline ? 350 : 1200);

    root.innerHTML = `
      <div class="store-loading-wrap">
        <div class="store-disk-spinner"></div>
        <div style="font-size:18px;font-weight:600">Connecting to Nova OS .NOSP Package Server...</div>
        <div style="font-size:13px;color:#64748B">Verifying network connection & fetching remote .NOSP catalog</div>
      </div>
    `;

    setTimeout(async () => {
      if (!state.netConnected) {
        root.innerHTML = `
          <div class="store-loading-wrap">
            <svg viewBox="0 0 64 64" width="64" height="64" fill="none" stroke="#EF4444" stroke-width="4" stroke-linecap="round">
              <circle cx="32" cy="32" r="26" />
              <line x1="20" y1="20" x2="44" y2="44" />
            </svg>
            <div style="font-size:24px;font-weight:700">Please connect your device to the internet</div>
            <div style="font-size:14px;color:#64748B;max-width:460px">
              The Nova OS App Store requires an active network connection to download <b>.NOSP</b> packages (such as <b>Chrome.NOSP</b>, <b>VideoPlayer.NOSP</b>, and <b>DVDPlayer.NOSP</b>) from the server.
            </div>
            <div style="display:flex;gap:12px;margin-top:8px">
              <button id="store-open-wifi" class="btn-primary">Open WiFi/Ethernet App</button>
              <button id="store-retry-btn" class="btn-secondary">Retry Connection</button>
            </div>
          </div>
        `;
        root.querySelector("#store-open-wifi").addEventListener("click", () => openWifiApp());
        root.querySelector("#store-retry-btn").addEventListener("click", () => loadStore());
        return;
      }

      let catalog = [];
      let serverUrl = "http://10.0.2.2:8095/catalog.json";
      const fetchCatalog = async () => {
        try {
          const res = await fetch("/api/store/catalog").then((r) => r.json());
          if (res && res.catalog) {
            catalog = res.catalog;
            serverUrl = res.server || serverUrl;
            // Sync any new live-pushed apps into ALL_APPS so Start Menu & Desktop render them!
            catalog.forEach((item) => {
              if (!ALL_APPS.some((a) => a.id === item.id)) {
                ALL_APPS.push({
                  id: item.id,
                  label: item.name,
                  nosp: item.filename,
                  icon: ICONS[item.id] || ICONS.appstore,
                  core: false,
                  meta: item,
                });
              }
            });
          }
        } catch {}
      };
      await fetchCatalog();
      renderCatalogView(catalog, serverUrl);

      // Real-time live catalog polling while App Store is open
      if (win._livePoll) clearInterval(win._livePoll);
      win._livePoll = setInterval(async () => {
        if (!document.body.contains(win)) {
          clearInterval(win._livePoll);
          return;
        }
        const prevJson = JSON.stringify(catalog.map((c) => c.id + c.version));
        await fetchCatalog();
        const nextJson = JSON.stringify(catalog.map((c) => c.id + c.version));
        if (prevJson !== nextJson) {
          renderCatalogView(catalog, serverUrl);
        }
      }, 4000);
    }, waitTime);
  };

  const renderCatalogView = (catalog, serverUrl) => {
    root.innerHTML = `
      <div style="padding:16px 22px;border-bottom:1px solid rgba(148,163,184,0.28);display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="font-size:19px;font-weight:700">Nova OS .NOSP Package Server</div>
          <div style="font-size:12px;color:#16A34A">● Live Connected (${state.wifiSsid || "Ethernet"}) — ${serverUrl} (${catalog.length} apps)</div>
        </div>
        <div style="display:flex;gap:8px">
          <button id="store-refresh-live" class="btn-secondary">↻ Sync Live</button>
          <button id="store-install-all" class="btn-primary">Download All ${catalog.length} .NOSP Apps</button>
        </div>
      </div>
      <div id="store-items" style="flex:1;overflow-y:auto;padding:16px 22px;display:grid;grid-template-columns:repeat(2,1fr);gap:14px"></div>
    `;
    root.querySelector("#store-refresh-live").addEventListener("click", () => loadStore());

    const grid = root.querySelector("#store-items");
    catalog.forEach((item) => {
      const installed = isInstalled(item.id);
      const card = document.createElement("div");
      card.style.cssText = `padding:14px;border-radius:14px;background:rgba(148,163,184,0.12);border:2px solid ${highlightAppId === item.id ? "#2563EB" : "transparent"};display:flex;flex-direction:column;justify-content:space-between;gap:10px`;
      card.innerHTML = `
        <div style="display:flex;gap:12px;align-items:center">
          <div style="width:54px;height:54px;display:flex;align-items:center;justify-content:center">${ICONS[item.id] || ICONS.appstore}</div>
          <div>
            <div style="font-size:16px;font-weight:700">${item.full_name || item.name}</div>
            <div style="font-size:12px;color:#2563EB;font-weight:600">${item.filename || (item.name + ".NOSP")} • ${item.size}</div>
          </div>
        </div>
        <div style="font-size:12.5px;line-height:1.35">${item.description}</div>
        <div style="display:flex;gap:8px">
          <button class="store-act-btn ${installed ? "btn-secondary" : "btn-primary"}" style="flex:1">
            ${installed ? "Open App" : `Download ${item.filename || ".NOSP"}`}
          </button>
          ${installed ? `<button class="store-uninst-btn btn-small" title="Remove .NOSP">Uninstall</button>` : ""}
        </div>
      `;
      const btn = card.querySelector(".store-act-btn");
      btn.addEventListener("click", async () => {
        if (installed) {
          openApp(item.id);
          return;
        }
        btn.disabled = true;
        btn.textContent = `Fetching ${item.filename} from Server...`;
        try {
          await fetch("/api/store/install", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ app_id: item.id }),
          });
        } catch {}
        setTimeout(() => {
          if (!state.installedApps.includes(item.id)) state.installedApps.push(item.id);
          renderIcons();
          renderCatalogView(catalog, serverUrl);
        }, 500);
      });

      const uninstBtn = card.querySelector(".store-uninst-btn");
      if (uninstBtn) {
        uninstBtn.addEventListener("click", async () => {
          await fetch("/api/store/uninstall", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ app_id: item.id }),
          }).catch(() => {});
          state.installedApps = state.installedApps.filter((a) => a !== item.id);
          renderIcons();
          renderCatalogView(catalog, serverUrl);
        });
      }
      grid.appendChild(card);
    });

    root.querySelector("#store-install-all").addEventListener("click", async () => {
      const btn = root.querySelector("#store-install-all");
      btn.disabled = true;
      btn.textContent = "Downloading All .NOSP Packages...";
      try {
        await fetch("/api/store/install", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ app_id: "all" }),
        });
      } catch {}
      setTimeout(() => {
        ALL_APPS.forEach((a) => {
          if (!state.installedApps.includes(a.id)) state.installedApps.push(a.id);
        });
        renderIcons();
        renderCatalogView(catalog, serverUrl);
      }, 650);
    });
  };

  loadStore();
}

// ============================================================================
// 4. NEW APP #1: NOVA MP4 / MKV 1080p VIDEO PLAYER (VideoPlayer.NOSP)
// ============================================================================
function openVideoPlayer(initialVideoPath = "Videos/NovaOS_2.00_Showcase_1080p.mp4") {
  const win = createWindow("videoplayer", "Nova MP4 Video Player (1080p HD)", 860, 560, 320, 80, `
    <div style="display:flex;flex-direction:column;height:100%;background:#090D16;color:#F8FAFC">
      <div style="padding:10px 16px;background:#111827;border-bottom:1px solid #1E293B;display:flex;gap:10px;align-items:center;justify-content:space-between">
        <div style="display:flex;gap:8px;align-items:center">
          <span style="font-weight:700;color:#38BDF8">🎬 MP4 Video Player</span>
          <select id="vp-preset" style="padding:5px 10px;border-radius:6px;background:#1E293B;color:#FFF;border:1px solid #334155">
            <option value="Videos/NovaOS_2.00_Showcase_1080p.mp4">NovaOS_2.00_Showcase_1080p.mp4 (1080p H.264)</option>
            <option value="Videos/NovaOS_DVD_Feature_1080p.mp4">NovaOS_DVD_Feature_1080p.mp4 (1080p H.264)</option>
          </select>
        </div>
        <div style="display:flex;gap:8px">
          <button id="vp-open-local" class="dvd-btn">Open Local .MP4 / .WebM (&gt;1 GB OK)</button>
          <input id="vp-file-inp" type="file" accept="video/*,.mp4,.webm,.mkv,.ogg" class="hidden" />
        </div>
      </div>

      <div style="flex:1;position:relative;display:flex;align-items:center;justify-content:center;background:#000;overflow:hidden">
        <video id="vp-video" src="/api/fs/raw?path=${encodeURIComponent(initialVideoPath)}" style="max-width:100%;max-height:100%;width:100%;height:100%;object-fit:contain" controls autoplay></video>
      </div>

      <div class="dvd-remote-deck">
        <div style="display:flex;gap:8px;align-items:center">
          <button id="vp-play" class="dvd-btn">⏯ Play / Pause</button>
          <button id="vp-stop" class="dvd-btn">⏹ Stop</button>
          <button id="vp-rew" class="dvd-btn">⏪ -5s</button>
          <button id="vp-ff" class="dvd-btn">⏩ +5s</button>
        </div>
        <div style="display:flex;gap:10px;align-items:center">
          <span style="font-size:12px;color:#94A3B8">Speed:</span>
          <select id="vp-speed" style="padding:4px 8px;border-radius:6px;background:#1E293B;color:#FFF;border:1px solid #475569">
            <option value="0.5">0.5x</option>
            <option value="1" selected>1.0x (Normal)</option>
            <option value="1.5">1.5x</option>
            <option value="2">2.0x</option>
          </select>
          <button id="vp-fs" class="dvd-btn">⛶ Fullscreen</button>
        </div>
      </div>
    </div>
  `);

  const vid = win.querySelector("#vp-video");
  const preset = win.querySelector("#vp-preset");
  preset.value = initialVideoPath;

  preset.addEventListener("change", () => {
    vid.src = `/api/fs/raw?path=${encodeURIComponent(preset.value)}`;
    vid.play().catch(() => {});
  });

  win.querySelector("#vp-play").addEventListener("click", () => {
    if (vid.paused) vid.play();
    else vid.pause();
  });
  win.querySelector("#vp-stop").addEventListener("click", () => {
    vid.pause();
    vid.currentTime = 0;
  });
  win.querySelector("#vp-rew").addEventListener("click", () => {
    vid.currentTime = Math.max(0, vid.currentTime - 5);
  });
  win.querySelector("#vp-ff").addEventListener("click", () => {
    vid.currentTime = Math.min(vid.duration || 60, vid.currentTime + 5);
  });
  win.querySelector("#vp-speed").addEventListener("change", (e) => {
    vid.playbackRate = parseFloat(e.target.value) || 1.0;
  });
  win.querySelector("#vp-fs").addEventListener("click", () => {
    if (vid.requestFullscreen) vid.requestFullscreen();
  });
  win.querySelector("#vp-open-local").addEventListener("click", () => {
    const inp = win.querySelector("#vp-file-inp");
    inp.onchange = () => {
      const f = inp.files[0];
      if (!f) return;
      vid.src = URL.createObjectURL(f);
      vid.play().catch(() => {});
    };
    inp.click();
  });
}

// ============================================================================
// 5. NEW APP #2: NOVA DVD PLAYER PRO (DVDPlayer.NOSP — Menus, Chapters, Remote)
// ============================================================================
function openDVDPlayer(discVideo = "Videos/NovaOS_DVD_Feature_1080p.mp4") {
  const win = createWindow("dvdplayer", "Nova DVD Player Pro — Optical / ISO / VIDEO_TS", 880, 580, 300, 70, `
    <div style="display:flex;flex-direction:column;height:100%;background:#050811;color:#F8FAFC">
      <div style="padding:8px 16px;background:#0F172A;border-bottom:1px solid #1E293B;display:flex;justify-content:space-between;align-items:center;font-size:13px">
        <div>💿 <b>Disc Loaded:</b> <span id="dvd-disc-label" style="color:#38BDF8">NOVAOS_200_COLLECTORS_DVD (/dev/sr0)</span></div>
        <div id="dvd-osd-info" style="color:#A855F7;font-weight:700">Title 01 • Chapter 01 • Dolby Digital 5.1 • Subtitles: EN</div>
      </div>

      <div style="flex:1;position:relative;background:#000;display:flex;align-items:center;justify-content:center;overflow:hidden">
        <video id="dvd-video" src="/api/fs/raw?path=${encodeURIComponent(discVideo)}" style="width:100%;height:100%;object-fit:contain" loop></video>

        <!-- Interactive DVD Title Menu Overlay -->
        <div id="dvd-menu-overlay" style="position:absolute;inset:0;background:radial-gradient(circle at center, rgba(15,23,42,0.78), rgba(2,6,23,0.94));display:flex;flex-direction:column;align-items:center;justify-content:center;gap:16px">
          <div style="font-size:34px;font-weight:800;letter-spacing:1px;color:#38BDF8;text-shadow:0 2px 14px rgba(56,189,248,0.6)">NOVA OS 2.00 — OFFICIAL DVD VIDEO</div>
          <div style="font-size:14px;color:#CBD5E1">Interactive DVD-Video Main Menu • Select an Option:</div>
          <div style="display:grid;grid-template-columns:repeat(2,220px);gap:12px;margin-top:8px">
            <button id="dvd-play-movie" class="btn-primary" style="padding:12px;font-size:15px">▶ Play Main Feature</button>
            <button id="dvd-ch1" class="dvd-btn" style="padding:12px">📑 Ch 1: Nova Overture (0:00)</button>
            <button id="dvd-ch2" class="dvd-btn" style="padding:12px">📑 Ch 2: Light Beams (0:04)</button>
            <button id="dvd-ch3" class="dvd-btn" style="padding:12px">📑 Ch 3: Kernel &amp; UI (0:08)</button>
            <button id="dvd-ch4" class="dvd-btn" style="padding:12px">📑 Ch 4: 1080p Finale (0:12)</button>
            <button id="dvd-load-iso" class="dvd-btn" style="padding:12px">💿 Load DVD .ISO / .VOB / .MP4</button>
          </div>
          <input id="dvd-file-inp" type="file" accept="video/*,.iso,.vob,.mp4" class="hidden" />
        </div>

        <!-- On-Screen DVD Subtitle Track -->
        <div id="dvd-sub-box" style="position:absolute;bottom:22px;left:50%;transform:translateX(-50%);padding:6px 16px;border-radius:6px;background:rgba(0,0,0,0.72);color:#FEF08A;font-size:18px;font-weight:600;pointer-events:none">
          ♪ [Dolby Digital 5.1] Nova OS 2.00 Collector's Edition DVD Feature ♪
        </div>
      </div>

      <!-- Full Hardware-Style DVD Remote Control Deck -->
      <div class="dvd-remote-deck">
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          <button id="dvd-btn-menu" class="dvd-btn">📋 DVD Menu</button>
          <button id="dvd-btn-title" class="dvd-btn">🎬 Title</button>
          <button id="dvd-btn-prev" class="dvd-btn">⏮ Prev Ch</button>
          <button id="dvd-btn-rew" class="dvd-btn">⏪ Rew</button>
          <button id="dvd-btn-play" class="dvd-btn">⏯ Play/Pause</button>
          <button id="dvd-btn-ff" class="dvd-btn">⏩ FF</button>
          <button id="dvd-btn-next" class="dvd-btn">⏭ Next Ch</button>
        </div>
        <div style="display:flex;gap:6px">
          <button id="dvd-btn-audio" class="dvd-btn">🔊 Audio</button>
          <button id="dvd-btn-subs" class="dvd-btn">💬 Subtitles</button>
          <button id="dvd-btn-eject" class="dvd-btn">⏏ Eject</button>
        </div>
      </div>
    </div>
  `);

  const vid = win.querySelector("#dvd-video");
  const menu = win.querySelector("#dvd-menu-overlay");
  const subBox = win.querySelector("#dvd-sub-box");
  const osd = win.querySelector("#dvd-osd-info");
  let subsOn = true;
  let audioMode = "Dolby Digital 5.1";
  const chapters = [0, 4, 8, 12];
  let curCh = 0;

  const startAtChapter = (chIdx) => {
    curCh = chIdx;
    menu.classList.add("hidden");
    vid.currentTime = chapters[chIdx] || 0;
    vid.play().catch(() => {});
    osd.textContent = `Title 01 • Chapter 0${chIdx + 1} • ${audioMode} • Subtitles: ${subsOn ? "EN" : "OFF"}`;
    subBox.textContent = `Chapter ${chIdx + 1}: Nova OS 2.00 High-Definition DVD Playback (${audioMode})`;
  };

  win.querySelector("#dvd-play-movie").addEventListener("click", () => startAtChapter(0));
  win.querySelector("#dvd-ch1").addEventListener("click", () => startAtChapter(0));
  win.querySelector("#dvd-ch2").addEventListener("click", () => startAtChapter(1));
  win.querySelector("#dvd-ch3").addEventListener("click", () => startAtChapter(2));
  win.querySelector("#dvd-ch4").addEventListener("click", () => startAtChapter(3));

  win.querySelector("#dvd-btn-menu").addEventListener("click", () => {
    vid.pause();
    menu.classList.remove("hidden");
  });
  win.querySelector("#dvd-btn-title").addEventListener("click", () => {
    vid.pause();
    menu.classList.remove("hidden");
  });
  win.querySelector("#dvd-btn-play").addEventListener("click", () => {
    if (!menu.classList.contains("hidden")) {
      startAtChapter(curCh);
    } else if (vid.paused) {
      vid.play();
    } else {
      vid.pause();
    }
  });
  win.querySelector("#dvd-btn-prev").addEventListener("click", () => {
    startAtChapter((curCh + chapters.length - 1) % chapters.length);
  });
  win.querySelector("#dvd-btn-next").addEventListener("click", () => {
    startAtChapter((curCh + 1) % chapters.length);
  });
  win.querySelector("#dvd-btn-rew").addEventListener("click", () => {
    vid.currentTime = Math.max(0, vid.currentTime - 3);
  });
  win.querySelector("#dvd-btn-ff").addEventListener("click", () => {
    vid.currentTime = Math.min(vid.duration || 16, vid.currentTime + 3);
  });
  win.querySelector("#dvd-btn-subs").addEventListener("click", () => {
    subsOn = !subsOn;
    subBox.classList.toggle("hidden", !subsOn);
    osd.textContent = `Title 01 • Chapter 0${curCh + 1} • ${audioMode} • Subtitles: ${subsOn ? "EN" : "OFF"}`;
  });
  win.querySelector("#dvd-btn-audio").addEventListener("click", () => {
    audioMode = audioMode === "Dolby Digital 5.1" ? "PCM Stereo 2.0" : "Dolby Digital 5.1";
    osd.textContent = `Title 01 • Chapter 0${curCh + 1} • ${audioMode} • Subtitles: ${subsOn ? "EN" : "OFF"}`;
  });
  win.querySelector("#dvd-btn-eject").addEventListener("click", () => {
    vid.pause();
    menu.classList.remove("hidden");
    win.querySelector("#dvd-file-inp").click();
  });
  win.querySelector("#dvd-load-iso").addEventListener("click", () => {
    win.querySelector("#dvd-file-inp").click();
  });
  win.querySelector("#dvd-file-inp").addEventListener("change", (e) => {
    const f = e.target.files[0];
    if (!f) return;
    win.querySelector("#dvd-disc-label").textContent = f.name;
    vid.src = URL.createObjectURL(f);
    startAtChapter(0);
  });
}

// ============================================================================
// 6. NEW APP #3: NOVA MUSIC & EQUALIZER STUDIO (MusicStudio.NOSP)
// ============================================================================
function openMusicStudio() {
  const win = createWindow("musicstudio", "Nova Music & 16-Band EQ Studio", 700, 460, 360, 110, `
    <div style="display:flex;flex-direction:column;height:100%;background:#0F172A;color:#F8FAFC;padding:18px;gap:14px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="font-size:20px;font-weight:800;color:#C084FC">🎵 Nova Music &amp; Synthesizer Studio</div>
          <div id="ms-track-lbl" style="font-size:13px;color:#94A3B8">Track 01: Nova OS Ambient Horizon (WebAudio Synth + MP4 Audio)</div>
        </div>
        <button id="ms-open-file" class="dvd-btn">Open Local .MP3 / .WAV</button>
        <input id="ms-file-inp" type="file" accept="audio/*,video/*" class="hidden" />
      </div>

      <canvas id="ms-spec" width="640" height="160" style="width:100%;height:160px;background:#020617;border-radius:12px;border:1px solid #1E293B"></canvas>

      <audio id="ms-audio" src="/api/fs/raw?path=Videos%2FNovaOS_2.00_Showcase_1080p.mp4" controls style="width:100%"></audio>

      <div style="display:flex;gap:14px;align-items:center;justify-content:space-between;padding:10px 14px;border-radius:10px;background:#1E293B">
        <div style="display:flex;gap:8px">
          <button id="ms-synth-1" class="btn-primary">▶ Play Ambient Chord</button>
          <button id="ms-synth-2" class="dvd-btn">▶ Play Startup Chime</button>
        </div>
        <div style="font-size:12px;color:#38BDF8">16-Band Real-Time Spectrum Active</div>
      </div>
    </div>
  `);

  const canvas = win.querySelector("#ms-spec");
  const ctx2d = canvas.getContext("2d");
  const audioEl = win.querySelector("#ms-audio");
  let animTick = 0;

  const drawSpectrum = () => {
    if (!document.body.contains(canvas)) return;
    animTick += 0.12;
    ctx2d.fillStyle = "#020617";
    ctx2d.fillRect(0, 0, canvas.width, canvas.height);
    const playing = !audioEl.paused;
    const bars = 24;
    const bw = (canvas.width - 32) / bars;
    for (let i = 0; i < bars; i++) {
      const wave = playing
        ? Math.abs(Math.sin(animTick + i * 0.45) * Math.cos(animTick * 0.7 - i * 0.2)) * 120 + 18
        : 10 + Math.sin(animTick * 0.5 + i * 0.3) * 4;
      const grad = ctx2d.createLinearGradient(0, canvas.height, 0, 0);
      grad.addColorStop(0, "#3B82F6");
      grad.addColorStop(0.6, "#A855F7");
      grad.addColorStop(1, "#EC4899");
      ctx2d.fillStyle = grad;
      ctx2d.fillRect(16 + i * bw, canvas.height - wave, bw - 6, wave);
    }
    requestAnimationFrame(drawSpectrum);
  };
  drawSpectrum();

  const playChord = (freqs) => {
    try {
      const actx = new (window.AudioContext || window.webkitAudioContext)();
      freqs.forEach((f, idx) => {
        const osc = actx.createOscillator();
        const gain = actx.createGain();
        osc.type = "sine";
        osc.frequency.setValueAtTime(f, actx.currentTime + idx * 0.08);
        gain.gain.setValueAtTime(0.12, actx.currentTime);
        gain.gain.exponentialRampToValueAtTime(0.001, actx.currentTime + 1.4);
        osc.connect(gain);
        gain.connect(actx.destination);
        osc.start(actx.currentTime + idx * 0.08);
        osc.stop(actx.currentTime + 1.45);
      });
    } catch {}
  };

  win.querySelector("#ms-synth-1").addEventListener("click", () => playChord([261.63, 329.63, 392.0, 523.25]));
  win.querySelector("#ms-synth-2").addEventListener("click", () => playChord([440, 554.37, 659.25, 880]));
  win.querySelector("#ms-open-file").addEventListener("click", () => {
    const inp = win.querySelector("#ms-file-inp");
    inp.onchange = () => {
      const f = inp.files[0];
      if (!f) return;
      win.querySelector("#ms-track-lbl").textContent = `Playing Local File: ${f.name}`;
      audioEl.src = URL.createObjectURL(f);
      audioEl.play().catch(() => {});
    };
    inp.click();
  });
}

// ============================================================================
// 7. NEW APP #4: NOVA PAINT & PHOTO STUDIO (PaintStudio.NOSP)
// ============================================================================
function openPaintStudio() {
  const win = createWindow("paintstudio", "Nova Paint & Photo Studio", 820, 560, 320, 80, `
    <div style="display:flex;flex-direction:column;height:100%">
      <div style="padding:10px 14px;border-bottom:1px solid rgba(148,163,184,0.3);display:flex;gap:8px;align-items:center;flex-wrap:wrap">
        <label style="font-size:13px;font-weight:600">Color: <input id="ps-color" type="color" value="#2563EB" /></label>
        <label style="font-size:13px;font-weight:600">Size: <input id="ps-size" type="range" min="2" max="32" value="6" style="vertical-align:middle" /></label>
        <button id="ps-brush" class="btn-primary">✏ Brush</button>
        <button id="ps-line" class="btn-secondary">╱ Line</button>
        <button id="ps-rect" class="btn-secondary">▭ Rect</button>
        <button id="ps-circle" class="btn-secondary">◯ Circle</button>
        <button id="ps-eraser" class="btn-secondary">🧽 Eraser</button>
        <button id="ps-undo" class="btn-secondary">↩ Undo</button>
        <button id="ps-clear" class="btn-secondary">🗑 Clear</button>
        <input id="ps-fname" value="Pictures/NovaPaint_Artwork.png" style="padding:5px 8px;border:1px solid #94A3B8;border-radius:6px;width:190px;font-size:12.5px" />
        <button id="ps-save" class="btn-primary">💾 Save PNG</button>
        <span id="ps-status" style="font-size:12px;color:#16A34A;font-weight:600"></span>
      </div>
      <div style="flex:1;background:#E2E8F0;display:flex;align-items:center;justify-content:center;overflow:hidden;padding:12px">
        <canvas id="ps-canvas" width="760" height="420" style="background:#FFFFFF;border-radius:8px;box-shadow:0 4px 12px rgba(0,0,0,0.15);cursor:crosshair;max-width:100%;max-height:100%"></canvas>
      </div>
    </div>
  `);

  const canvas = win.querySelector("#ps-canvas");
  const ctx = canvas.getContext("2d");
  ctx.fillStyle = "#FFFFFF";
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  let drawing = false;
  let tool = "brush";
  let sx = 0, sy = 0;
  let snapImg = null;
  const undoStack = [];
  const pushUndo = () => {
    try {
      undoStack.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
      if (undoStack.length > 20) undoStack.shift();
    } catch {}
  };
  const canvasXY = (e) => {
    const r = canvas.getBoundingClientRect();
    return {
      x: (e.clientX - r.left) * (canvas.width / (r.width || canvas.width)),
      y: (e.clientY - r.top) * (canvas.height / (r.height || canvas.height)),
    };
  };
  const setTool = (t, activeId) => {
    tool = t;
    ["#ps-brush", "#ps-line", "#ps-rect", "#ps-circle", "#ps-eraser"].forEach((id) => {
      win.querySelector(id).className = id === activeId ? "btn-primary" : "btn-secondary";
    });
  };

  canvas.addEventListener("mousedown", (e) => {
    pushUndo();
    drawing = true;
    const pt = canvasXY(e);
    sx = pt.x; sy = pt.y;
    if (tool === "brush" || tool === "eraser") {
      ctx.beginPath();
      ctx.moveTo(pt.x, pt.y);
    } else {
      snapImg = ctx.getImageData(0, 0, canvas.width, canvas.height);
    }
  });
  canvas.addEventListener("mousemove", (e) => {
    if (!drawing) return;
    const pt = canvasXY(e);
    ctx.lineCap = "round";
    ctx.lineJoin = "round";
    ctx.lineWidth = parseInt(win.querySelector("#ps-size").value, 10) || 6;
    ctx.strokeStyle = tool === "eraser" ? "#FFFFFF" : win.querySelector("#ps-color").value;
    if (tool === "brush" || tool === "eraser") {
      ctx.lineTo(pt.x, pt.y);
      ctx.stroke();
    } else if (snapImg) {
      ctx.putImageData(snapImg, 0, 0);
      ctx.beginPath();
      if (tool === "line") {
        ctx.moveTo(sx, sy); ctx.lineTo(pt.x, pt.y);
      } else if (tool === "rect") {
        ctx.rect(sx, sy, pt.x - sx, pt.y - sy);
      } else if (tool === "circle") {
        const rad = Math.hypot(pt.x - sx, pt.y - sy);
        ctx.arc(sx, sy, rad, 0, Math.PI * 2);
      }
      ctx.stroke();
    }
  });
  const stopDraw = () => { drawing = false; snapImg = null; };
  window.addEventListener("mouseup", stopDraw);
  win._cleanup = () => window.removeEventListener("mouseup", stopDraw);

  win.querySelector("#ps-brush").addEventListener("click", () => setTool("brush", "#ps-brush"));
  win.querySelector("#ps-line").addEventListener("click", () => setTool("line", "#ps-line"));
  win.querySelector("#ps-rect").addEventListener("click", () => setTool("rect", "#ps-rect"));
  win.querySelector("#ps-circle").addEventListener("click", () => setTool("circle", "#ps-circle"));
  win.querySelector("#ps-eraser").addEventListener("click", () => setTool("eraser", "#ps-eraser"));
  win.querySelector("#ps-undo").addEventListener("click", () => {
    const prev = undoStack.pop();
    if (prev) ctx.putImageData(prev, 0, 0);
  });
  win.querySelector("#ps-clear").addEventListener("click", () => {
    pushUndo();
    ctx.fillStyle = "#FFFFFF";
    ctx.fillRect(0, 0, canvas.width, canvas.height);
  });
  win.querySelector("#ps-save").addEventListener("click", async () => {
    const targetPath = win.querySelector("#ps-fname").value.trim() || "Pictures/NovaPaint_Artwork.png";
    const dataUrl = canvas.toDataURL("image/png");
    const status = win.querySelector("#ps-status");
    await fetch("/api/fs/write_base64", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: targetPath, data: dataUrl }),
    }).catch(() => {});
    status.textContent = `Saved ${targetPath}!`;
    setTimeout(() => (status.textContent = ""), 2500);
  });
}

// ============================================================================
// 8. TERMINAL, NOTEPAD, FILE EXPLORER, CHROME, YOUTUBE
// ============================================================================
function openTerminal() {
  const win = createWindow("terminal", "Terminal", 760, 480, 260, 90, `
    <div class="term-app">
      <div id="term-out" class="term-output">${escapeHtml(state.sysinfo.version.replace("\n", " "))} Terminal\nType 'help' for built-in or Linux commands (uname -a, free -h, df -h, ip addr).\n\n</div>
      <div class="term-input-row">
        <span style="color:#38BDF8">nova&gt;</span>
        <input id="term-in" type="text" autofocus />
      </div>
    </div>
  `);
  const out = win.querySelector("#term-out");
  const inp = win.querySelector("#term-in");
  const history = [];
  let histIdx = 0;
  const print = (txt) => {
    out.textContent += txt + "\n";
    out.scrollTop = out.scrollHeight;
  };
  inp.addEventListener("keydown", async (e) => {
    if (e.key === "ArrowUp") {
      if (histIdx > 0) inp.value = history[--histIdx] || "";
      e.preventDefault();
      return;
    }
    if (e.key === "ArrowDown") {
      if (histIdx < history.length) inp.value = history[++histIdx] || "";
      e.preventDefault();
      return;
    }
    if (e.key !== "Enter") return;
    const cmd = inp.value.trim();
    inp.value = "";
    if (cmd) { history.push(cmd); histIdx = history.length; }
    print(`nova> ${cmd}`);
    const lower = cmd.toLowerCase();
    if (lower === "help") {
      print("Built-in: help, ver, about, ls, clear, switch newbootspin.fnt for oldbootspin.fnt, switch oldbootspin.fnt for newbootspin.fnt");
      print("OS Tools: uname -a, free -h, df -h, uptime, date, ip addr, lsblk, ps, whoami, cat <file>");
    } else if (lower === "ver") {
      print(state.sysinfo.version);
    } else if (lower === "about") {
      print(`CPU: ${state.sysinfo.cpu}\nRAM: ${state.sysinfo.ram}\nGPU: ${state.sysinfo.gpu}\nVersion: ${state.sysinfo.version}`);
    } else if (lower === "clear") {
      out.textContent = "";
    } else if (lower === "ls" || lower === "dir") {
      const res = await fetch("/api/fs/list?path=").then((r) => r.json());
      res.items.forEach((it) => print(`  ${it.is_dir ? "<DIR>" : it.size + " B"}  ${it.name}`));
    } else if (lower === "switch newbootspin.fnt for oldbootspin.fnt") {
      state.spinnerMode = "old";
      fetch("/api/boot_spinner", { method: "POST", body: JSON.stringify({ spinner: "oldbootspin.fnt" }) }).catch(() => {});
      print("[OK] Switched loading spinner to oldbootspin.fnt (E052-E0CB) on all loading screens.");
    } else if (lower === "switch oldbootspin.fnt for newbootspin.fnt") {
      state.spinnerMode = "new";
      fetch("/api/boot_spinner", { method: "POST", body: JSON.stringify({ spinner: "newbootspin.fnt" }) }).catch(() => {});
      print("[OK] Switched loading spinner to newbootspin.fnt (E100-E176) on all loading screens.");
    } else if (cmd) {
      try {
        const res = await fetch("/api/terminal/exec", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ cmd }),
        }).then((r) => r.json());
        print(res.output || (res.ok ? "" : `Unknown command: ${cmd}`));
      } catch {
        print(`Unknown command: ${cmd}`);
      }
    }
  });
}

function openNotepad(filename = "Documents/Welcome_to_NovaOS_2.00.txt") {
  const fontOpts = (state.fonts || ["Segoe UI"]).map((f) =>
    `<option value="${f}" style="font-family:'${f}',sans-serif">${f}</option>`
  ).join("");
  const win = createWindow("notepad", `Notepad - ${filename}`, 720, 480, 300, 120, `
    <div style="display:flex;flex-direction:column;height:100%">
      <div style="padding:10px 14px;border-bottom:1px solid rgba(148,163,184,0.25);display:flex;gap:8px;align-items:center;flex-wrap:wrap">
        <input id="np-fname" value="${filename}" style="padding:6px 10px;border:1px solid #94A3B8;border-radius:6px;width:210px" />
        <select id="np-font" title="100+ Fonts" style="padding:6px 8px;border:1px solid #94A3B8;border-radius:6px;max-width:170px">${fontOpts}</select>
        <button id="np-save" class="btn-primary">Save</button>
        <button id="np-load" class="btn-secondary">Load</button>
        <span id="np-status" style="font-size:13px;color:#16A34A;font-weight:600"></span>
      </div>
      <textarea id="np-text" style="flex:1;padding:16px;border:none;outline:none;resize:none;font-family:inherit;font-size:15px;background:transparent;color:inherit"></textarea>
    </div>
  `);
  const area = win.querySelector("#np-text");
  const fnameEl = win.querySelector("#np-fname");
  const fontEl = win.querySelector("#np-font");
  const statusEl = win.querySelector("#np-status");
  fontEl.addEventListener("change", () => {
    area.style.fontFamily = `'${fontEl.value}', sans-serif`;
  });
  const loadFile = async () => {
    const r = await fetch(`/api/fs/read?path=${encodeURIComponent(fnameEl.value)}`);
    if (r.ok) {
      const d = await r.json();
      area.value = d.content;
    }
  };
  loadFile();
  win.querySelector("#np-load").addEventListener("click", loadFile);
  win.querySelector("#np-save").addEventListener("click", async () => {
    await fetch("/api/fs/write", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: fnameEl.value, content: area.value }),
    });
    statusEl.textContent = "Saved to disk!";
    setTimeout(() => (statusEl.textContent = ""), 1800);
  });
}

function openExplorer(initialPath = "", initialDrive = "C") {
  if (initialPath) {
    state.explorerPath = initialPath;
    state.explorerDrive = initialDrive || "C";
  } else if (!state.explorerDrive) {
    state.explorerDrive = "ThisPC";
  }
  let viewMode = "grid";
  let drivesList = [{ letter: "C:", code: "C", name: "Local Disk (C:)", type: "Fixed Local Disk", total_gb: 20, free_gb: 15 }];
  const win = createWindow("files", "File Explorer", 940, 580, 230, 75, `
    <div class="win-exp-wrap">
      <div class="win-exp-ribbon">
        <button id="exp-up" class="btn-small">↑ Up</button>
        <button id="exp-refresh" class="btn-small">⟳</button>
        <input id="exp-path" readonly style="flex:1;padding:6px 12px;border:1px solid #94A3B8;border-radius:6px;background:transparent;color:inherit;font-size:13.5px" />
        <button id="exp-view-toggle" class="btn-small">☰ List / Grid</button>
        <button id="exp-mkdir" class="btn-secondary">New Folder</button>
        <button id="exp-dl-url" class="btn-secondary" title="Download any file URL to Downloads">⬇ Download URL</button>
        <button id="exp-upload" class="btn-primary">Upload (&gt;1 GB OK)</button>
      </div>
      <div class="win-exp-body">
        <div class="win-exp-sidebar">
          <div class="win-exp-nav-hdr">Quick access</div>
          <div class="win-exp-nav-item" data-drive="C" data-nav="Desktop">🖥 Desktop</div>
          <div class="win-exp-nav-item" data-drive="C" data-nav="Downloads">⬇ Downloads</div>
          <div class="win-exp-nav-item" data-drive="C" data-nav="Documents">📄 Documents</div>
          <div class="win-exp-nav-item" data-drive="C" data-nav="Pictures">🖼 Pictures</div>
          <div class="win-exp-nav-item" data-drive="C" data-nav="Videos">🎬 Videos</div>
          <div class="win-exp-nav-item" data-drive="C" data-nav="Music">🎵 Music</div>
          <div class="win-exp-nav-item" data-drive="C" data-nav="Packages">📦 Packages (.NOSP)</div>
          <div class="win-exp-nav-hdr">This PC</div>
          <div id="exp-drives-nav"></div>
        </div>
        <div class="win-exp-main">
          <div id="exp-list" class="win-exp-grid"></div>
        </div>
      </div>
    </div>
  `);

  const getFileIcon = (it) => {
    if (it.is_dir) return "📁";
    const n = it.name.toLowerCase();
    if (n.endsWith(".mp4") || n.endsWith(".mov") || n.endsWith(".webm") || n.endsWith(".mkv")) return "🎬";
    if (n.endsWith(".mp3") || n.endsWith(".wav") || n.endsWith(".ogg")) return "🎵";
    if (n.endsWith(".png") || n.endsWith(".jpg") || n.endsWith(".jpeg") || n.endsWith(".webp") || n.endsWith(".gif") || n.endsWith(".bmp")) return "🖼";
    if (n.endsWith(".exe")) return "🪟";
    if (n.endsWith(".nosp")) return "📦";
    return "📄";
  };

  const openFileItem = (it) => {
    const drv = state.explorerDrive === "ThisPC" ? "C" : state.explorerDrive;
    if (it.is_dir) {
      state.explorerDrive = drv;
      state.explorerPath = it.rel;
      refresh();
      return;
    }
    const n = it.name.toLowerCase();
    if (n.endsWith(".mp4") || n.endsWith(".mov") || n.endsWith(".webm") || n.endsWith(".mkv")) {
      return openVideoPlayer(it.rel);
    }
    if (n.endsWith(".mp3") || n.endsWith(".wav") || n.endsWith(".ogg")) {
      return openMusicStudio(it.rel);
    }
    if (n.endsWith(".png") || n.endsWith(".jpg") || n.endsWith(".jpeg") || n.endsWith(".webp") || n.endsWith(".gif") || n.endsWith(".bmp")) {
      return openImageViewer(it.rel, drv);
    }
    if (n.endsWith(".exe")) {
      return openExeToNosp(it.rel);
    }
    return openNotepad(it.rel);
  };

  const renderDrivesSidebar = () => {
    const navWrap = win.querySelector("#exp-drives-nav");
    navWrap.innerHTML = `<div class="win-exp-nav-item ${state.explorerDrive === "ThisPC" ? "active" : ""}" data-drive="ThisPC" data-nav="">🖥 This PC</div>`;
    drivesList.forEach((d) => {
      const ico = (d.code === "A" || d.code === "B") ? "💾" : (d.code === "D" ? "💿" : "🗄");
      const active = state.explorerDrive === d.code && !state.explorerPath;
      navWrap.innerHTML += `<div class="win-exp-nav-item ${active ? "active" : ""}" data-drive="${d.code}" data-nav="">${ico} ${escapeHtml(d.name)}</div>`;
    });
    navWrap.querySelectorAll(".win-exp-nav-item").forEach((el) => {
      el.addEventListener("click", () => {
        state.explorerDrive = el.dataset.drive;
        state.explorerPath = "";
        refresh();
      });
    });
  };

  const refresh = async () => {
    try {
      const dr = await fetch("/api/fs/drives").then((r) => r.json());
      if (dr && dr.drives) drivesList = dr.drives;
    } catch {}
    renderDrivesSidebar();

    win.querySelectorAll(".win-exp-sidebar > .win-exp-nav-item").forEach((el) => {
      el.classList.toggle("active", state.explorerDrive === el.dataset.drive && el.dataset.nav === state.explorerPath);
    });

    const list = win.querySelector("#exp-list");
    if (state.explorerDrive === "ThisPC") {
      win.querySelector("#exp-path").value = "This PC";
      list.className = "";
      list.innerHTML = `<div style="font-size:15px;font-weight:700;margin-bottom:8px">Devices and drives (${drivesList.length})</div><div class="drive-card-grid"></div>`;
      const grid = list.querySelector(".drive-card-grid");
      drivesList.forEach((d) => {
        const ico = (d.code === "A" || d.code === "B") ? "💾" : (d.code === "D" ? "💿" : "🗄");
        const pct = d.total_gb > 0 ? Math.min(100, Math.max(4, Math.round(((d.total_gb - d.free_gb) / d.total_gb) * 100))) : 100;
        const card = document.createElement("div");
        card.className = "drive-card";
        card.innerHTML = `
          <div style="display:flex;align-items:center;gap:10px">
            <span style="font-size:30px">${ico}</span>
            <div>
              <div style="font-weight:700;font-size:14.5px">${escapeHtml(d.name)}</div>
              <div style="font-size:11.5px;color:#64748B">${escapeHtml(d.type)}</div>
            </div>
          </div>
          <div class="drive-bar-track"><div class="drive-bar-fill" style="width:${pct}%"></div></div>
          <div style="font-size:12px;color:#64748B">${d.free_gb} GB free of ${d.total_gb} GB</div>
        `;
        card.addEventListener("dblclick", () => { state.explorerDrive = d.code; state.explorerPath = ""; refresh(); });
        card.addEventListener("click", () => { state.explorerDrive = d.code; state.explorerPath = ""; refresh(); });
        grid.appendChild(card);
      });
      return;
    }

    const drv = state.explorerDrive || "C";
    const drvMeta = drivesList.find((d) => d.code === drv) || { name: `Local Disk (${drv}:)` };
    const winPath = state.explorerPath ? state.explorerPath.replace(/\//g, "\\") : "";
    win.querySelector("#exp-path").value = `This PC > ${drvMeta.name} > ${winPath}`;

    const res = await fetch(`/api/fs/list?drive=${encodeURIComponent(drv)}&path=${encodeURIComponent(state.explorerPath)}`).then((r) => r.json()).catch(() => ({ items: [] }));
    list.className = viewMode === "grid" ? "win-exp-grid" : "";
    list.innerHTML = "";
    if (!res.items || res.items.length === 0) {
      list.innerHTML = `<div style="padding:24px;color:#64748B;font-size:14px">This folder is empty.</div>`;
      return;
    }
    res.items.forEach((it) => {
      const sizeStr = it.is_dir ? "File folder" : (it.size > 1024 * 1024 ? (it.size / (1024 * 1024)).toFixed(1) + " MB" : it.size + " B");
      const icon = getFileIcon(it);
      const row = document.createElement("div");
      if (viewMode === "grid") {
        row.className = "win-exp-tile";
        row.innerHTML = `<div style="font-size:40px;line-height:1">${icon}</div><div>${escapeHtml(it.name)}</div><div style="font-size:11px;color:#64748B">${sizeStr}</div>`;
      } else {
        row.className = "win-exp-list-row";
        row.innerHTML = `<span>${icon} ${escapeHtml(it.name)}</span><span style="font-size:12px;color:#64748B">${it.is_dir ? "Folder" : "File"}</span><span style="font-size:12px;color:#64748B;text-align:right">${sizeStr}</span>`;
      }
      row.addEventListener("dblclick", () => openFileItem(it));
      list.appendChild(row);
    });
  };

  win.querySelectorAll(".win-exp-sidebar > .win-exp-nav-item").forEach((nav) => {
    nav.addEventListener("click", () => {
      state.explorerDrive = nav.dataset.drive || "C";
      state.explorerPath = nav.dataset.nav;
      refresh();
    });
  });
  win.querySelector("#exp-view-toggle").addEventListener("click", () => {
    viewMode = viewMode === "grid" ? "list" : "grid";
    refresh();
  });
  win.querySelector("#exp-refresh").addEventListener("click", refresh);
  win.querySelector("#exp-up").addEventListener("click", () => {
    if (!state.explorerPath) {
      state.explorerDrive = "ThisPC";
      return refresh();
    }
    const parts = state.explorerPath.split("/").filter(Boolean);
    parts.pop();
    state.explorerPath = parts.join("/");
    refresh();
  });
  win.querySelector("#exp-mkdir").addEventListener("click", async () => {
    const name = prompt("Folder name:");
    if (!name) return;
    const drv = state.explorerDrive === "ThisPC" ? "C" : state.explorerDrive;
    await fetch("/api/fs/mkdir", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ drive: drv, path: (state.explorerPath ? state.explorerPath + "/" : "") + name }),
    });
    refresh();
  });
  win.querySelector("#exp-dl-url").addEventListener("click", async () => {
    const url = prompt("Enter URL to download into Downloads/:");
    if (!url) return;
    const fname = prompt("Save filename (leave blank for automatic):", "");
    const res = await fetch("/api/fs/download_url", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url, filename: fname || "" }),
    }).then((r) => r.json()).catch(() => ({ ok: false, error: "Network error" }));
    if (res.ok) {
      showDesktopToast("toast-dl", "Download Complete", `Saved ${res.rel} (${(res.size / 1024).toFixed(1)} KB)`, () => openExplorer("Downloads", "C"));
      state.explorerDrive = "C";
      state.explorerPath = "Downloads";
      refresh();
    } else {
      alert("Download failed: " + (res.error || "Unknown error"));
    }
  });
  win.querySelector("#exp-upload").addEventListener("click", () => {
    const inp = document.getElementById("explorer-file-input");
    inp.onchange = async () => {
      const file = inp.files[0];
      if (!file) return;
      const drv = state.explorerDrive === "ThisPC" ? "C" : state.explorerDrive;
      const rel = (state.explorerPath ? state.explorerPath + "/" : "") + file.name;
      await fetch(`/api/fs/upload?drive=${encodeURIComponent(drv)}&path=${encodeURIComponent(rel)}`, { method: "POST", body: file });
      refresh();
    };
    inp.click();
  });
  refresh();
}

function openChrome(url = "") {
  const win = createWindow("chrome", "Google Chrome (Chrome.NOSP)", 960, 610, 210, 55, `
    <div style="display:flex;flex-direction:column;height:100%">
      <div style="padding:8px 14px;display:flex;gap:8px;border-bottom:1px solid rgba(148,163,184,0.25);align-items:center;background:rgba(148,163,184,0.08)">
        <button id="ch-home" class="btn-small" title="Home">⌂</button>
        <button id="ch-rel" class="btn-small" title="Reload">⟳</button>
        <input id="ch-url" value="${escapeHtml(url || "https://www.google.com")}" placeholder="Enter URL or search query..." style="flex:1;padding:7px 14px;border-radius:18px;border:1px solid #94A3B8;font-size:14px" />
        <button id="ch-go" class="btn-primary">Go</button>
        <button id="ch-fast" class="btn-secondary">Fast.com</button>
        <button id="ch-dl-mp4" class="btn-secondary" title="Download File URL to Downloads">⬇ Download File</button>
        <button id="ch-native" class="btn-secondary" title="Open Full WebKit Browser Tab">Native Tab ↗</button>
      </div>
      <div id="ch-status" style="padding:5px 14px;font-size:12px;color:#2563EB;background:rgba(37,99,235,0.08);font-weight:600">
        ● Ethernet IPv4 Fast Browse Ready — Enter any URL or choose a quick bookmark below
      </div>
      <div id="ch-home-view" style="flex:1;overflow-y:auto;padding:28px 34px;display:flex;flex-direction:column;gap:20px;align-items:center;justify-content:center;background:var(--win-bg)">
        <div style="font-size:34px;font-weight:900;letter-spacing:-0.5px"><span style="color:#4285F4">G</span><span style="color:#EA4335">o</span><span style="color:#FBBC05">o</span><span style="color:#4285F4">g</span><span style="color:#34A853">l</span><span style="color:#EA4335">e</span> <span style="font-size:16px;color:#64748B;font-weight:600">• Nova Chrome IPv4</span></div>
        <div style="display:flex;gap:8px;width:100%;max-width:540px">
          <input id="ch-search-box" placeholder="Search the web or type a website (e.g. wikipedia.org)..." style="flex:1;padding:11px 16px;border-radius:24px;border:1px solid #94A3B8;font-size:15px" />
          <button id="ch-search-btn" class="btn-primary" style="border-radius:24px;padding:0 20px">Search</button>
        </div>
        <div style="display:grid;grid-template-columns:repeat(3,165px);gap:12px">
          <button class="btn-secondary ch-bm" data-u="https://www.google.com">🔍 Google</button>
          <button class="btn-secondary ch-bm" data-u="https://en.wikipedia.org">📚 Wikipedia</button>
          <button class="btn-secondary ch-bm" data-u="https://lite.duckduckgo.com/lite/">🦆 DuckDuckGo Lite</button>
          <button class="btn-secondary ch-bm" data-u="https://github.com">💻 GitHub</button>
          <button class="btn-secondary ch-bm" data-u="https://example.com">🌐 Example.com</button>
          <button class="btn-secondary ch-bm" data-u="https://fast.com">⚡ Fast.com</button>
        </div>
        <div id="ch-preview-card" class="hidden" style="width:100%;max-width:720px;padding:16px 20px;border-radius:14px;background:rgba(148,163,184,0.12);border:1px solid rgba(148,163,184,0.3);display:flex;flex-direction:column;gap:8px"></div>
      </div>
      <iframe id="ch-frame" class="hidden" style="flex:1;border:none;width:100%;height:100%;background:#FFF"></iframe>
    </div>
  `);
  const frame = win.querySelector("#ch-frame");
  const homeView = win.querySelector("#ch-home-view");
  const prevCard = win.querySelector("#ch-preview-card");
  const urlInp = win.querySelector("#ch-url");
  const chStatus = win.querySelector("#ch-status");

  const openNative = (target) => {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.novaos) {
      window.webkit.messageHandlers.novaos.postMessage({
        action: "open_browser",
        url: target,
        title: "Google Chrome (Chrome.NOSP)",
        theme: state.theme,
      });
      return true;
    }
    return false;
  };

  const showHome = () => {
    frame.classList.add("hidden");
    homeView.classList.remove("hidden");
    chStatus.textContent = "● Home — Enter any URL or pick a bookmark (IPv4 Fast DNS active)";
  };

  const navigate = async (raw) => {
    let target = (raw || "").trim();
    if (!target) return showHome();
    if (!/^https?:\/\//i.test(target)) {
      if (target.includes(".") && !target.includes(" ")) target = "https://" + target;
      else target = "https://www.google.com/search?q=" + encodeURIComponent(target);
    }
    urlInp.value = target;
    chStatus.textContent = `Loading ${target} (IPv4)...`;
    const probe = await fetch(`/api/web/fetch?url=${encodeURIComponent(target)}`).then((r) => r.json()).catch(() => null);
    if (probe && probe.ok && probe.embeddable) {
      homeView.classList.add("hidden");
      frame.classList.remove("hidden");
      frame.src = probe.url || target;
      chStatus.textContent = `✓ Loaded "${probe.title || target}" in ${probe.elapsed_ms} ms (IPv4 ${probe.ipv4 || "direct"})`;
      return;
    }
    frame.classList.add("hidden");
    homeView.classList.remove("hidden");
    prevCard.classList.remove("hidden");
    const launchedNative = openNative(target);
    if (probe && probe.ok) {
      chStatus.textContent = `✓ Resolved ${target} in ${probe.elapsed_ms} ms (${probe.ipv4 || "IPv4"}) ${launchedNative ? "— Opened in Native WebKit Tab!" : "— Site blocks iframe embedding"}`;
      prevCard.innerHTML = `
        <div style="display:flex;justify-content:space-between;align-items:center;gap:10px">
          <div>
            <div style="font-size:17px;font-weight:800">${escapeHtml(probe.title || target)}</div>
            <div style="font-size:12px;color:#16A34A;font-weight:600">HTTP ${probe.status} • ${probe.elapsed_ms} ms • IPv4 ${escapeHtml(probe.ipv4 || "OK")}</div>
          </div>
          <button id="ch-card-nat" class="btn-primary">Open Full Native Tab ↗</button>
        </div>
        <div style="font-size:13px;line-height:1.45;opacity:0.9">${escapeHtml(probe.snippet || "")}</div>
      `;
      prevCard.querySelector("#ch-card-nat").addEventListener("click", () => openNative(target));
    } else {
      chStatus.textContent = `Could not reach ${target} (${probe ? probe.error : "network error"})`;
      prevCard.innerHTML = `<div style="color:#DC2626;font-weight:700">Failed to reach ${escapeHtml(target)}</div><div style="font-size:12.5px">${escapeHtml(probe ? probe.error : "Check Ethernet connection in WiFi/Ethernet or NetTools.")}</div>`;
    }
  };

  win.querySelector("#ch-home").addEventListener("click", showHome);
  win.querySelector("#ch-go").addEventListener("click", () => navigate(urlInp.value));
  win.querySelector("#ch-rel").addEventListener("click", () => {
    if (!frame.classList.contains("hidden")) frame.src = frame.src;
    else navigate(urlInp.value);
  });
  win.querySelector("#ch-fast").addEventListener("click", () => navigate("https://fast.com"));
  win.querySelector("#ch-search-btn").addEventListener("click", () => navigate(win.querySelector("#ch-search-box").value));
  win.querySelector("#ch-search-box").addEventListener("keydown", (e) => { if (e.key === "Enter") navigate(e.target.value); });
  win.querySelectorAll(".ch-bm").forEach((b) => b.addEventListener("click", () => navigate(b.dataset.u)));
  win.querySelector("#ch-dl-mp4").addEventListener("click", async () => {
    const dlUrl = prompt("Enter file URL to download into Downloads/:", urlInp.value || "https://example.com");
    if (!dlUrl) return;
    chStatus.textContent = `Downloading ${dlUrl} into Downloads/...`;
    const res = await fetch("/api/fs/download_url", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ url: dlUrl }),
    }).then((r) => r.json()).catch(() => ({ ok: false, error: "Network error" }));
    chStatus.textContent = res.ok
      ? `✓ Saved ${res.rel} (${(res.size / 1024).toFixed(1)} KB)! Open File Explorer → Downloads.`
      : `Download failed (${res.error || "check internet connection"}).`;
    if (res.ok) {
      showDesktopToast("toast-dl", "Download Finished", `Saved ${res.rel} to Local Disk (C:)`, () => openExplorer("Downloads", "C"));
    }
  });
  win.querySelector("#ch-native").addEventListener("click", () => openNative(urlInp.value));
  urlInp.addEventListener("keydown", (e) => { if (e.key === "Enter") navigate(urlInp.value); });
  if (url) navigate(url);
}

function openYouTube() {
  const win = createWindow("youtube", "YouTube 1080p HD (YouTube.NOSP)", 900, 560, 240, 70, `
    <div style="display:flex;flex-direction:column;height:100%;background:#0F0F0F;color:#FFFFFF">
      <div style="padding:12px 18px;background:#212121;display:flex;justify-content:space-between;align-items:center">
        <div style="display:flex;align-items:center;gap:10px">
          <span style="font-size:22px;font-weight:800;color:#FF0000">▶ YouTube</span>
          <span style="font-size:12px;padding:2px 8px;border-radius:4px;background:#CC0000;color:#FFF;font-weight:700">1080p60 HD</span>
        </div>
        <div style="display:flex;gap:8px">
          <button id="yt-switch-1" class="dvd-btn">Nova OS 2.00 Official 1080p Showcase</button>
          <button id="yt-switch-2" class="dvd-btn">Nova OS Kernel &amp; UI Feature</button>
          <button id="yt-native-web" class="dvd-btn">Open youtube.com ↗</button>
        </div>
      </div>
      <div style="flex:1;display:flex;flex-direction:column;padding:16px;gap:12px;overflow:hidden">
        <video id="yt-player" src="/api/fs/raw?path=Videos%2FNovaOS_2.00_Showcase_1080p.mp4" style="width:100%;flex:1;background:#000;border-radius:12px;object-fit:contain" controls autoplay></video>
        <div style="display:flex;justify-content:space-between;align-items:center">
          <div>
            <div id="yt-vid-title" style="font-size:18px;font-weight:700">Nova OS 2.00 Beta 1 (27000) — Full 1080p60 Desktop Showcase</div>
            <div style="font-size:13px;color:#AAAAAA">@aidaninvents • Streaming in 1920x1080 HD (H.264 / AAC)</div>
          </div>
        </div>
      </div>
    </div>
  `);
  const player = win.querySelector("#yt-player");
  const titleEl = win.querySelector("#yt-vid-title");
  win.querySelector("#yt-switch-1").addEventListener("click", () => {
    player.src = "/api/fs/raw?path=Videos%2FNovaOS_2.00_Showcase_1080p.mp4";
    titleEl.textContent = "Nova OS 2.00 Beta 1 (27000) — Full 1080p60 Desktop Showcase";
    player.play().catch(() => {});
  });
  win.querySelector("#yt-switch-2").addEventListener("click", () => {
    player.src = "/api/fs/raw?path=Videos%2FNovaOS_DVD_Feature_1080p.mp4";
    titleEl.textContent = "Nova OS 2.00 — Kernel Architecture & Custom Window Manager (1080p60)";
    player.play().catch(() => {});
  });
  win.querySelector("#yt-native-web").addEventListener("click", () => {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.novaos) {
      window.webkit.messageHandlers.novaos.postMessage({
        action: "open_browser",
        url: "https://www.youtube.com",
        title: "YouTube 1080p HD (YouTube.NOSP)",
        theme: state.theme,
      });
    }
  });
}

// ============================================================================
// 9. EXE TO NOSP (Wine 10.0), CALCULATOR, PHOTOS, TASK MANAGER, LIVE APPS
// ============================================================================
function openExeToNosp(initialExe = "") {
  const win = createWindow("exetonosp", "EXE to NOSP — Windows .EXE Runner (Wine 10.0)", 780, 520, 260, 80, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:14px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div>
          <div style="font-size:21px;font-weight:800">🪟 EXE to NOSP Converter &amp; Wine 10.0 Runner</div>
          <div id="exe-wine-info" style="font-size:13px;color:#64748B">Run Windows .EXE apps (steam.exe, Roblox.exe) natively on Nova OS via Wine 10.0</div>
        </div>
        <div style="display:flex;gap:8px">
          <button id="exe-upload-btn" class="btn-primary">Upload .EXE</button>
          <input id="exe-file-inp" type="file" accept=".exe,.msi" class="hidden" />
        </div>
      </div>

      <div style="display:flex;gap:8px;align-items:center;padding:10px 14px;border-radius:10px;background:rgba(148,163,184,0.12)">
        <span style="font-size:13px;font-weight:600">Quick Package / Test:</span>
        <button id="exe-mk-steam" class="btn-secondary">Create steam.exe</button>
        <button id="exe-mk-roblox" class="btn-secondary">Create Roblox.exe</button>
        <button id="exe-refresh" class="btn-small">↻ Refresh</button>
      </div>

      <div id="exe-list" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:8px"></div>
      <div id="exe-log" style="padding:10px 14px;border-radius:8px;background:#0F172A;color:#38BDF8;font-family:monospace;font-size:12.5px;min-height:54px">Ready. Select or upload any .EXE file to convert to .NOSP and run via Wine.</div>
    </div>
  `);

  const listEl = win.querySelector("#exe-list");
  const logEl = win.querySelector("#exe-log");
  const refreshExes = async () => {
    const res = await fetch("/api/exe/list").then((r) => r.json()).catch(() => ({ exes: [] }));
    win.querySelector("#exe-wine-info").textContent = res.wine_available
      ? "Wine 10.0 Runtime Active — Ready to convert & run Windows .EXE binaries"
      : "Wine Runtime Bridge Active — Select .EXE to wrap as .NOSP & launch";
    listEl.innerHTML = "";
    const exes = res.exes || [];
    if (exes.length === 0) {
      listEl.innerHTML = `<div style="padding:18px;color:#64748B">No .EXE files found in storage yet. Upload an .EXE or click Create steam.exe / Roblox.exe above.</div>`;
      return;
    }
    exes.forEach((ex) => {
      const row = document.createElement("div");
      row.style.cssText = "display:flex;justify-content:space-between;align-items:center;padding:10px 14px;border-radius:10px;background:rgba(148,163,184,0.14)";
      row.innerHTML = `
        <div><b>🪟 ${ex.name}</b> <span style="font-size:12px;color:#64748B">(${ex.rel} • ${ex.size} B)</span></div>
        <div style="display:flex;gap:8px">
          <button class="exe-conv btn-secondary">Convert → .NOSP</button>
          <button class="exe-run btn-primary">▶ Run with Wine</button>
        </div>
      `;
      row.querySelector(".exe-conv").addEventListener("click", async () => {
        const r = await fetch("/api/exe/convert", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ exe_path: ex.rel }),
        }).then((x) => x.json());
        logEl.textContent = r.ok ? `[OK] Converted ${ex.name} → ${r.nosp} (Wine 10.0 NOSP Bundle)!` : r.error;
      });
      row.querySelector(".exe-run").addEventListener("click", async () => {
        logEl.textContent = `Launching ${ex.name} with Wine 10.0...`;
        const r = await fetch("/api/exe/run", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ exe_path: ex.rel }),
        }).then((x) => x.json());
        logEl.textContent = r.ok ? `[RUNNING] ${r.status}` : `[ERROR] ${r.error}`;
      });
      listEl.appendChild(row);
    });
  };

  win.querySelector("#exe-refresh").addEventListener("click", refreshExes);
  win.querySelector("#exe-mk-steam").addEventListener("click", async () => {
    await fetch("/api/exe/create_sample", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: "steam.exe" }) });
    refreshExes();
  });
  win.querySelector("#exe-mk-roblox").addEventListener("click", async () => {
    await fetch("/api/exe/create_sample", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: "Roblox.exe" }) });
    refreshExes();
  });
  win.querySelector("#exe-upload-btn").addEventListener("click", () => {
    const inp = win.querySelector("#exe-file-inp");
    inp.onchange = async () => {
      const f = inp.files[0];
      if (!f) return;
      await fetch(`/api/fs/upload?path=${encodeURIComponent("Downloads/" + f.name)}`, { method: "POST", body: f });
      refreshExes();
    };
    inp.click();
  });
  refreshExes();
  if (initialExe) logEl.textContent = `Loaded ${initialExe}. Click "Convert → .NOSP" or "▶ Run with Wine".`;
}

function openCalculator() {
  const win = createWindow("calculator", "Calculator (Scientific & Standard)", 470, 580, 420, 80, `
    <div style="display:flex;flex-direction:column;height:100%;padding:16px;gap:10px" tabindex="0">
      <div id="calc-hist" style="font-size:12px;color:#64748B;text-align:right;min-height:18px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"></div>
      <div id="calc-disp" style="padding:16px;border-radius:12px;background:rgba(148,163,184,0.14);font-size:32px;font-weight:700;text-align:right;overflow:hidden">0</div>
      <div class="calc-grid">
        <button class="calc-btn" data-k="SQRT">√</button><button class="calc-btn" data-k="SQ">x²</button><button class="calc-btn" data-k="PCT">%</button><button class="calc-btn" data-k="SIGN">±</button>
        <button class="calc-btn" data-k="C">C</button><button class="calc-btn" data-k="(">(</button><button class="calc-btn" data-k=")">)</button><button class="calc-btn op" data-k="/">÷</button>
        <button class="calc-btn" data-k="7">7</button><button class="calc-btn" data-k="8">8</button><button class="calc-btn" data-k="9">9</button><button class="calc-btn op" data-k="*">×</button>
        <button class="calc-btn" data-k="4">4</button><button class="calc-btn" data-k="5">5</button><button class="calc-btn" data-k="6">6</button><button class="calc-btn op" data-k="-">−</button>
        <button class="calc-btn" data-k="1">1</button><button class="calc-btn" data-k="2">2</button><button class="calc-btn" data-k="3">3</button><button class="calc-btn op" data-k="+">+</button>
        <button class="calc-btn" data-k="0">0</button><button class="calc-btn" data-k=".">.</button><button class="calc-btn" data-k="DEL">⌫</button><button class="calc-btn op" data-k="=">=</button>
      </div>
    </div>
  `);
  const disp = win.querySelector("#calc-disp");
  const histEl = win.querySelector("#calc-hist");
  let expr = "";
  const evalSafe = (raw) => {
    const cleaned = String(raw || "0").trim();
    if (!/^[0-9+\-*/().\s]+$/.test(cleaned)) throw new Error("Invalid");
    const val = Function(`"use strict"; return (${cleaned})`)();
    if (!isFinite(val)) throw new Error("Div0");
    return Number(val.toPrecision(12));
  };
  const applyKey = (k) => {
    if (k === "C") { expr = ""; disp.textContent = "0"; histEl.textContent = ""; return; }
    if (k === "DEL") { expr = expr.slice(0, -1); disp.textContent = expr || "0"; return; }
    if (k === "=") {
      try {
        const res = evalSafe(expr);
        histEl.textContent = `${expr || "0"} =`;
        expr = String(res);
      } catch { expr = "Error"; }
      disp.textContent = expr;
      return;
    }
    if (k === "SQRT" || k === "SQ" || k === "PCT" || k === "SIGN") {
      try {
        const v = evalSafe(expr);
        const res = k === "SQRT" ? Math.sqrt(v) : k === "SQ" ? v * v : k === "PCT" ? v / 100 : -v;
        if (isNaN(res) || !isFinite(res)) throw new Error("Err");
        expr = String(Number(res.toPrecision(12)));
      } catch { expr = "Error"; }
      disp.textContent = expr;
      return;
    }
    if (expr === "Error") expr = "";
    expr += k;
    disp.textContent = expr;
  };
  win.querySelectorAll(".calc-btn").forEach((b) => b.addEventListener("click", () => applyKey(b.dataset.k)));
  const rootEl = win.querySelector("[tabindex]");
  rootEl.addEventListener("keydown", (e) => {
    if (/^[0-9+\-*/().]$/.test(e.key)) applyKey(e.key);
    else if (e.key === "Enter" || e.key === "=") { e.preventDefault(); applyKey("="); }
    else if (e.key === "Backspace") applyKey("DEL");
    else if (e.key === "Escape") applyKey("C");
  });
}

function openImageViewer(imgRel = "", drive = "C") {
  const srcUrl = imgRel ? `/api/fs/raw?drive=${encodeURIComponent(drive)}&path=${encodeURIComponent(imgRel)}` : "assets/wp_light.jpg";
  let currentRel = imgRel;
  const win = createWindow("imageviewer", `Photos — ${escapeHtml(imgRel || "Nova OS Wallpaper")}`, 780, 540, 320, 80, `
    <div style="display:flex;flex-direction:column;height:100%;background:#0B1120;color:#FFF">
      <div style="padding:10px 16px;background:#111827;display:flex;justify-content:space-between;align-items:center;gap:8px;flex-wrap:wrap">
        <span id="iv-title" style="font-weight:700">🖼 ${escapeHtml(imgRel || "wp_light.jpg")}</span>
        <div style="display:flex;gap:6px;flex-wrap:wrap">
          <button id="iv-zoom-out" class="btn-small">－</button>
          <button id="iv-zoom-in" class="btn-small">＋</button>
          <button id="iv-rot" class="btn-small">↻ 90°</button>
          <button id="iv-reset" class="btn-small">Reset</button>
          <button id="iv-set-bg" class="btn-primary">Set Wallpaper</button>
          <button id="iv-open-local" class="btn-secondary">Open File</button>
          <input id="iv-inp" type="file" accept="image/*" class="hidden" />
        </div>
      </div>
      <div style="flex:1;display:flex;align-items:center;justify-content:center;padding:16px;overflow:auto">
        <img id="iv-img" src="${srcUrl}" style="max-width:100%;max-height:100%;object-fit:contain;border-radius:8px;transition:transform 0.15s ease" />
      </div>
    </div>
  `);
  const img = win.querySelector("#iv-img");
  let scale = 1, deg = 0;
  const applyXf = () => { img.style.transform = `scale(${scale}) rotate(${deg}deg)`; };
  win.querySelector("#iv-zoom-in").addEventListener("click", () => { scale = Math.min(3, scale + 0.25); applyXf(); });
  win.querySelector("#iv-zoom-out").addEventListener("click", () => { scale = Math.max(0.25, scale - 0.25); applyXf(); });
  win.querySelector("#iv-rot").addEventListener("click", () => { deg = (deg + 90) % 360; applyXf(); });
  win.querySelector("#iv-reset").addEventListener("click", () => { scale = 1; deg = 0; applyXf(); });
  win.querySelector("#iv-set-bg").addEventListener("click", () => {
    const wp = currentRel || img.src;
    applyWallpaper(wp);
    fetch("/api/wallpaper", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ wallpaper: wp }),
    }).catch(() => {});
  });
  win.querySelector("#iv-open-local").addEventListener("click", () => {
    const inp = win.querySelector("#iv-inp");
    inp.onchange = async () => {
      const f = inp.files[0];
      if (!f) return;
      const rel = `Pictures/${f.name}`;
      await fetch(`/api/fs/upload?path=${encodeURIComponent(rel)}`, { method: "POST", body: f }).catch(() => {});
      currentRel = rel;
      img.src = `/api/fs/raw?path=${encodeURIComponent(rel)}&t=${Date.now()}`;
      win.querySelector("#iv-title").textContent = `🖼 ${f.name}`;
      scale = 1; deg = 0; applyXf();
    };
    inp.click();
  });
}

function openSysMonitor() {
  const win = createWindow("sysmonitor", "Task Manager — Nova OS 2.00", 720, 500, 340, 90, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:14px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div style="font-size:20px;font-weight:800">📊 System Performance &amp; Open Windows</div>
        <span id="tm-uptime" style="font-size:12.5px;color:#64748B">Live Refresh (2s)</span>
      </div>
      <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px">
        <div style="padding:12px;border-radius:10px;background:rgba(37,99,235,0.12)"><b>CPU &amp; Load</b><div id="tm-cpu" style="font-size:13px;margin-top:4px">${escapeHtml(state.sysinfo.cpu)}</div></div>
        <div style="padding:12px;border-radius:10px;background:rgba(16,185,129,0.12)"><b>Memory &amp; ZRAM Swap</b><div id="tm-mem" style="font-size:13px;margin-top:4px">${escapeHtml(state.sysinfo.ram)}</div></div>
        <div style="padding:12px;border-radius:10px;background:rgba(168,85,247,0.12)"><b>Disk &amp; Network</b><div id="tm-net" style="font-size:13px;margin-top:4px">${state.netConnected ? escapeHtml(state.wifiSsid) : "Disconnected"}</div></div>
      </div>
      <div style="font-weight:700">Running Applications / Windows:</div>
      <div id="tm-list" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:6px"></div>
    </div>
  `);
  const renderStats = async () => {
    if (!document.body.contains(win)) return;
    try {
      const m = await fetch("/api/sysmonitor").then((r) => r.json());
      if (m && m.ok) {
        win.querySelector("#tm-uptime").textContent = `Uptime: ${Math.floor(m.uptime_sec)}s • ${m.cpu_cores} Cores`;
        win.querySelector("#tm-cpu").textContent = `${state.sysinfo.cpu} (Load: ${m.load_avg})`;
        win.querySelector("#tm-mem").textContent = `RAM: ${m.mem_used_mb} / ${m.mem_total_mb} MB • Swap: ${m.swap_used_mb} / ${m.swap_total_mb} MB`;
        win.querySelector("#tm-net").textContent = `Free Disk: ${m.disk_free_gb} GB • Net: ${state.netConnected ? state.wifiSsid : "Offline"}`;
      }
    } catch {}
  };
  const renderProcs = () => {
    const list = win.querySelector("#tm-list");
    if (!list) return;
    list.innerHTML = "";
    Object.values(state.windows).forEach((w) => {
      const row = document.createElement("div");
      row.style.cssText = "display:flex;justify-content:space-between;align-items:center;padding:8px 12px;border-radius:8px;background:rgba(148,163,184,0.14)";
      row.innerHTML = `<span><b>${escapeHtml(w.title)}</b> (${escapeHtml(w.id)}.NOSP)</span><button class="btn-small">End Task</button>`;
      row.querySelector("button").addEventListener("click", () => {
        if (w.el._cleanup) try { w.el._cleanup(); } catch {}
        w.el.remove();
        delete state.windows[w.id];
        renderTaskbarApps();
        renderProcs();
      });
      list.appendChild(row);
    });
  };
  renderStats();
  renderProcs();
  const tmTimer = setInterval(() => {
    if (!document.body.contains(win)) { clearInterval(tmTimer); return; }
    renderStats();
    renderProcs();
  }, 2000);
  win._cleanup = () => clearInterval(tmTimer);
}

function openLiveCustomApp(appId) {
  const app = ALL_APPS.find((a) => a.id === appId) || { id: appId, label: appId, meta: {} };
  const meta = app.meta || {};
  createWindow(appId, meta.full_name || app.label, 640, 420, 320, 120, `
    <div style="padding:24px;display:flex;flex-direction:column;gap:12px">
      <div style="font-size:24px;font-weight:800">${meta.full_name || app.label}</div>
      <div style="font-size:13px;color:#2563EB;font-weight:600">${meta.filename || (appId + ".NOSP")} • Version ${meta.version || "1.0.0"} • Live Server App</div>
      <div style="font-size:15px;line-height:1.5">${meta.description || "Dynamically installed from the Nova OS Live .NOSP Package Server."}</div>
    </div>
  `);
}

// ============================================================================
// 10. WINDOWS 10-STYLE ISO INSTALLER WIZARD (Language, Product Key, Edition, Disk)
// ============================================================================
const SETUP_I18N = {
  "en-US": {
    langTitle: "Language to install:",
    installNow: "Install Now",
    tryLive: "Try Live Desktop",
    keyTitle: "Activate Nova OS",
    keySub: "Enter the product key from your disc sleeve, or bypass activation for now.",
    noKey: "I don't have a product key",
    edTitle: "Select the edition of Nova OS you want to install",
    diskTitle: "Where do you want to install Nova OS?",
    next: "Next",
    back: "Back",
    installing: "Installing Nova OS",
  },
  "es-ES": {
    langTitle: "Idioma que va a instalar:",
    installNow: "Instalar ahora",
    tryLive: "Probar escritorio en vivo",
    keyTitle: "Activar Nova OS",
    keySub: "Escribe la clave de producto del disco o omítela por ahora.",
    noKey: "No tengo clave de producto",
    edTitle: "Selecciona la edición de Nova OS que quieres instalar",
    diskTitle: "¿Dónde quieres instalar Nova OS?",
    next: "Siguiente",
    back: "Atrás",
    installing: "Instalando Nova OS",
  },
  "it-IT": {
    langTitle: "Lingua da installare:",
    installNow: "Installa ora",
    tryLive: "Prova desktop Live",
    keyTitle: "Attiva Nova OS",
    keySub: "Inserisci il codice Product Key del disco oppure ignora questo passaggio.",
    noKey: "Non ho un codice Product Key",
    edTitle: "Seleziona l'edizione di Nova OS da installare",
    diskTitle: "Dove vuoi installare Nova OS?",
    next: "Avanti",
    back: "Indietro",
    installing: "Installazione di Nova OS",
  },
  "fr-FR": {
    langTitle: "Langue à installer :",
    installNow: "Installer maintenant",
    tryLive: "Essayer le bureau Live",
    keyTitle: "Activer Nova OS",
    keySub: "Entrez la clé de produit du disque ou ignorez cette étape.",
    noKey: "Je n'ai pas de clé de produit",
    edTitle: "Sélectionnez l'édition de Nova OS à installer",
    diskTitle: "Où souhaitez-vous installer Nova OS ?",
    next: "Suivant",
    back: "Précédent",
    installing: "Installation de Nova OS",
  },
  "de-DE": {
    langTitle: "Installationssprache:",
    installNow: "Jetzt installieren",
    tryLive: "Live-Desktop testen",
    keyTitle: "Nova OS aktivieren",
    keySub: "Geben Sie den Product Key von Ihrer Disc ein oder überspringen Sie diesen Schritt.",
    noKey: "Ich habe keinen Product Key",
    edTitle: "Wählen Sie die zu installierende Nova OS-Edition",
    diskTitle: "Wo möchten Sie Nova OS installieren?",
    next: "Weiter",
    back: "Zurück",
    installing: "Nova OS wird installiert",
  },
  "ja-JP": {
    langTitle: "インストールする言語:",
    installNow: "今すぐインストール",
    tryLive: "ライブデスクトップを試す",
    keyTitle: "Nova OS のライセンス認証",
    keySub: "ディスク付属のプロダクトキーを入力するか、スキップしてください。",
    noKey: "プロダクトキーがありません",
    edTitle: "インストールする Nova OS のエディションを選択してください",
    diskTitle: "Nova OS のインストール場所を選択してください",
    next: "次へ",
    back: "戻る",
    installing: "Nova OS をインストールしています",
  },
};

function initSetupWizard(discKeyHint = "NOVA2-8F4K-92PX-7QVM-2026", onTryLive, defaultLang = "en-US") {
  const scr = document.getElementById("setup-screen");
  const body = document.getElementById("setup-body");
  const footer = document.getElementById("setup-footer");
  document.getElementById("boot-screen").classList.add("hidden");
  scr.classList.remove("hidden");

  const wiz = { lang: defaultLang || "en-US", key: "", bypassed: false, edition: "Pro", disk: "/dev/sda", disks: [], liveMode: false, username: "", pin: "" };
  const t = () => SETUP_I18N[wiz.lang] || SETUP_I18N["en-US"];

  const bootStraightToDesktop = () => {
    state.language = wiz.lang;
    scr.classList.add("hidden");
    if (onTryLive) onTryLive();
  };

  const closeSetupBtn = document.getElementById("setup-close-btn");
  if (closeSetupBtn) {
    closeSetupBtn.onclick = bootStraightToDesktop;
  }

  const stepLang = () => {
    const tr = t();
    body.innerHTML = `
      <div class="setup-brand"><img src="assets/nova_n_transparent.png" width="38" height="38"/> Nova OS 2.00 Setup</div>
      <div style="margin-top:14px;display:flex;flex-direction:column;gap:12px;max-width:440px">
        <label style="font-weight:600;font-size:15px">${tr.langTitle}</label>
        <select id="su-lang" style="padding:10px;border:1px solid #9CA3AF;font-size:15px">
          <option value="en-US">English (United States)</option>
          <option value="es-ES">Español (España / Latinoamérica)</option>
          <option value="it-IT">Italiano (Italia)</option>
          <option value="fr-FR">Français (France)</option>
          <option value="de-DE">Deutsch (Deutschland)</option>
          <option value="ja-JP">日本語 (日本)</option>
        </select>
        <div style="font-size:13px;color:#4B5563">Time &amp; currency format: Match selected language • Keyboard: US / Auto</div>
      </div>
    `;
    const sel = body.querySelector("#su-lang");
    sel.value = wiz.lang;
    sel.addEventListener("change", () => { wiz.lang = sel.value; stepLang(); });
    footer.innerHTML = `
      <button id="su-live" class="setup-btn-secondary">${tr.tryLive}</button>
      <button id="su-next" class="setup-btn-primary">${tr.installNow}</button>
    `;
    footer.querySelector("#su-live").addEventListener("click", () => {
      wiz.liveMode = true;
      stepKey();
    });
    footer.querySelector("#su-next").addEventListener("click", () => {
      wiz.liveMode = false;
      stepKey();
    });
    setTimeout(() => { try { footer.querySelector("#su-next").focus(); } catch {} }, 40);
  };

  const stepKey = () => {
    const tr = t();
    body.innerHTML = `
      <div style="font-size:24px;font-weight:400;color:#0067B8">${tr.keyTitle}</div>
      <div style="font-size:14px;color:#374151">${tr.keySub}</div>
      <div style="font-size:12.5px;color:#6B7280">Product Key Format: <b>Nova2-xxxxx-xxxxx-xxxxx-xxxxx</b> (Case-insensitive) or Disc Key <code>${discKeyHint}</code></div>
      <input id="su-key-inp" value="${escapeHtml(wiz.key)}" placeholder="Nova2-xxxxx-xxxxx-xxxxx-xxxxx" style="padding:10px 12px;font-size:16px;border:1px solid #0067B8;max-width:420px;letter-spacing:0.8px" />
      <div id="su-key-err" style="color:#DC2626;font-size:13px"></div>
    `;
    footer.innerHTML = `
      <div style="display:flex;gap:14px;align-items:center">
        <button id="su-back" class="setup-btn-secondary">${tr.back}</button>
        <button id="su-nokey" class="setup-link-btn">${tr.noKey}</button>
      </div>
      <button id="su-next" class="setup-btn-primary">${tr.next}</button>
    `;
    footer.querySelector("#su-back").addEventListener("click", stepLang);
    footer.querySelector("#su-nokey").addEventListener("click", () => {
      wiz.bypassed = true;
      wiz.key = "";
      state.activated = false;
      state.activationBypassed = true;
      fetch("/api/installer/validate_key", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ bypass: true }),
      }).catch(() => {});
      stepEdition();
    });
    footer.querySelector("#su-next").addEventListener("click", async () => {
      const k = body.querySelector("#su-key-inp").value.trim();
      const res = await fetch("/api/installer/validate_key", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ key: k, bypass: false }),
      }).then((r) => r.json());
      if (!res.ok) {
        body.querySelector("#su-key-err").textContent = res.error || "Invalid key.";
        return;
      }
      wiz.key = k;
      wiz.bypassed = false;
      state.activated = true;
      state.activationBypassed = false;
      state.activationKey = res.activation_key || k;
      if (res.edition) wiz.edition = res.edition;
      if (res.installed_apps) state.installedApps = res.installed_apps;
      if (res.sysinfo) state.sysinfo = res.sysinfo;
      renderIcons();
      stepAccount();
    });
  };

  const stepEdition = () => {
    const tr = t();
    body.innerHTML = `
      <div style="font-size:22px;font-weight:400;color:#0067B8">${tr.edTitle}</div>
      <table class="setup-table">
        <thead><tr><th>Operating System</th><th>Architecture</th><th>Apps Included</th></tr></thead>
        <tbody>
          <tr data-ed="Home" class="${wiz.edition === "Home" ? "selected" : ""}" style="cursor:pointer"><td>Nova OS 2.00 Home</td><td>x64</td><td>15 Apps (incl. 5 New Home Apps)</td></tr>
          <tr data-ed="Pro" class="${wiz.edition === "Pro" ? "selected" : ""}" style="cursor:pointer"><td>Nova OS 2.00 Pro</td><td>x64</td><td>25 Apps (Home + 10 Pro Bonus Apps)</td></tr>
        </tbody>
      </table>
    `;
    body.querySelectorAll("tr[data-ed]").forEach((row) => {
      row.addEventListener("click", () => {
        wiz.edition = row.dataset.ed;
        state.installedApps = wiz.edition === "Home" ? [...HOME_DEFAULT_APPS] : [...PRO_DEFAULT_APPS];
        state.sysinfo.edition_short = wiz.edition;
        state.sysinfo.edition = `Nova OS 2.00 ${wiz.edition}`;
        renderIcons();
        stepEdition();
      });
    });
    footer.innerHTML = `
      <button id="su-back" class="setup-btn-secondary">${tr.back}</button>
      <button id="su-next" class="setup-btn-primary">${tr.next}</button>
    `;
    footer.querySelector("#su-back").addEventListener("click", stepKey);
    footer.querySelector("#su-next").addEventListener("click", stepAccount);
  };

  const stepAccount = () => {
    const tr = t();
    body.innerHTML = `
      <div style="font-size:24px;font-weight:400;color:#0067B8">Set up an account</div>
      <div style="font-size:14px;color:#374151">Sign in with a local username and PIN, or click "No thanks" below to boot straight to desktop.</div>
      <div style="display:flex;flex-direction:column;gap:10px;max-width:380px;margin-top:6px">
        <label style="font-size:14px;font-weight:600">Username:</label>
        <input id="su-acct-user" value="${escapeHtml(wiz.username)}" placeholder="Enter username..." style="padding:10px 12px;font-size:15px;border:1px solid #0067B8" />
        <label style="font-size:14px;font-weight:600">PIN:</label>
        <input id="su-acct-pin" type="password" value="${escapeHtml(wiz.pin)}" placeholder="Enter PIN (optional)..." style="padding:10px 12px;font-size:15px;border:1px solid #0067B8" />
        <div id="su-acct-err" style="color:#DC2626;font-size:13px"></div>
      </div>
    `;
    footer.innerHTML = `
      <div style="display:flex;gap:14px;align-items:center">
        <button id="su-back" class="setup-btn-secondary">${tr.back}</button>
        <button id="su-nothanks" class="setup-link-btn" style="font-weight:600">No thanks</button>
      </div>
      <button id="su-next" class="setup-btn-primary">${wiz.liveMode ? "Finish &amp; Start" : tr.next}</button>
    `;
    footer.querySelector("#su-back").addEventListener("click", wiz.bypassed ? stepEdition : stepKey);
    footer.querySelector("#su-nothanks").addEventListener("click", () => {
      state.userAccount = { username: "User", has_pin: false };
      updateStartUserBadge();
      fetch("/api/account/setup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ skip: true }),
      }).catch(() => {});
      bootStraightToDesktop();
    });
    footer.querySelector("#su-next").addEventListener("click", async () => {
      const u = body.querySelector("#su-acct-user").value.trim() || "User";
      const p = body.querySelector("#su-acct-pin").value.trim();
      wiz.username = u;
      wiz.pin = p;
      const res = await fetch("/api/account/setup", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ username: u, pin: p, skip: false }),
      }).then((r) => r.json()).catch(() => ({ ok: true }));
      if (res && res.account) state.userAccount = res.account;
      else state.userAccount = { username: u, has_pin: Boolean(p) };
      updateStartUserBadge();
      if (wiz.liveMode) bootStraightToDesktop();
      else stepDisk();
    });
  };

  const stepDisk = async () => {
    const tr = t();
    if (wiz.disks.length === 0) {
      const res = await fetch("/api/installer/disks").then((r) => r.json()).catch(() => ({ disks: [] }));
      wiz.disks = res.disks || [];
      if (wiz.disks[0]) wiz.disk = wiz.disks[0].device;
    }
    const rows = wiz.disks.map((d) =>
      `<tr data-dev="${d.device}" class="${wiz.disk === d.device ? "selected" : ""}" style="cursor:pointer">
        <td>${d.device} (${d.model})</td><td>${d.size_gb} GB</td><td>${d.tran}</td>
      </tr>`
    ).join("");
    body.innerHTML = `
      <div style="font-size:22px;font-weight:400;color:#0067B8">${tr.diskTitle}</div>
      <table class="setup-table">
        <thead><tr><th>Drive</th><th>Total Size</th><th>Bus</th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
      <div style="font-size:12.5px;color:#6B7280">Edition: <b>Nova OS 2.00 ${wiz.edition}</b> • Account: <b>${escapeHtml(wiz.username || "User")}</b> • Language: <b>${wiz.lang}</b></div>
    `;
    body.querySelectorAll("tr[data-dev]").forEach((r) => {
      r.addEventListener("click", () => { wiz.disk = r.dataset.dev; stepDisk(); });
    });
    footer.innerHTML = `
      <button id="su-back" class="setup-btn-secondary">${tr.back}</button>
      <button id="su-next" class="setup-btn-primary">${tr.installNow}</button>
    `;
    footer.querySelector("#su-back").addEventListener("click", stepAccount);
    footer.querySelector("#su-next").addEventListener("click", stepProgress);
  };

  const stepProgress = async () => {
    const tr = t();
    body.innerHTML = `
      <div style="font-size:24px;font-weight:400;color:#0067B8">${tr.installing} (${wiz.edition})</div>
      <div style="font-size:14px;color:#4B5563">Your PC will restart several times. This might take a few minutes.</div>
      <div style="display:flex;flex-direction:column;gap:12px;margin-top:16px;font-size:15px">
        <div id="su-st-copy">○ Copying Nova OS files...</div>
        <div id="su-st-prep" style="font-weight:700;color:#0067B8">▶ Getting files ready for installation (<span id="su-pct">0</span>%)</div>
        <div id="su-st-feat">○ Installing features and 100+ fonts...</div>
        <div id="su-st-grub">○ Installing BIOS + UEFI bootloader...</div>
        <div id="su-st-fin">○ Finishing up...</div>
      </div>
      <div style="height:10px;background:#E5E7EB;border-radius:6px;overflow:hidden;margin-top:12px">
        <div id="su-bar" style="height:100%;width:4%;background:#0067B8"></div>
      </div>
      <div id="su-msg" style="font-size:13px;color:#374151"></div>
    `;
    footer.innerHTML = `<span style="font-size:13px;color:#6B7280">Installing to ${wiz.disk}...</span><span></span>`;

    await fetch("/api/installer/start", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ device: wiz.disk, edition: wiz.edition, language: wiz.lang, product_key: wiz.key }),
    });

    const poll = setInterval(async () => {
      const st = await fetch("/api/installer/status").then((r) => r.json()).catch(() => ({}));
      const pct = st.percent || 0;
      body.querySelector("#su-pct").textContent = pct;
      body.querySelector("#su-bar").style.width = `${pct}%`;
      body.querySelector("#su-msg").textContent = st.stage || "";
      if (pct >= 15) body.querySelector("#su-st-copy").textContent = "✓ Copying Nova OS files";
      if (pct >= 70) body.querySelector("#su-st-feat").textContent = "✓ Installing features and 100+ fonts";
      if (pct >= 88) body.querySelector("#su-st-grub").textContent = "✓ Installing BIOS + UEFI bootloader";
      if (st.done) {
        clearInterval(poll);
        body.querySelector("#su-st-fin").textContent = "✓ Finishing up — Ready to boot from Hard Disk!";
        footer.innerHTML = `<span></span><button id="su-reboot" class="setup-btn-primary">Restart Now</button>`;
        footer.querySelector("#su-reboot").addEventListener("click", () => {
          fetch("/api/power", { method: "POST", body: JSON.stringify({ action: "restart" }) }).catch(() => {});
          bootStraightToDesktop();
        });
      }
    }, 1000);
  };

  stepLang();
}

// ============================================================================
// INIT & URL STATE HANDLERS
// ============================================================================
window.addEventListener("DOMContentLoaded", async () => {
  startSpinnerEngine();
  updateClock();
  setInterval(updateClock, 1000);

  const params = new URLSearchParams(location.search);
  const scr = params.get("screen");
  const th = params.get("theme");
  if (th === "dark") setTheme("dark");

  const enterDesktop = () => {
    document.getElementById("boot-screen").classList.add("hidden");
    document.getElementById("desktop").classList.remove("hidden");
    updateStartUserBadge();
    if (!state.activated) {
      setTimeout(showActivationNotification, 180);
    }
  };

  if (scr && scr !== "boot") {
    enterDesktop();
  }

  let st = null;
  let info = null;
  let instInfo = { boot_mode: "installed_disk", disc_key: "NOVA2-8F4K-92PX-7QVM-2026" };

  try {
    const [stRes, infoRes, instRes] = await Promise.all([
      fetch("/api/state").then((r) => r.json()).catch(() => null),
      fetch("/api/sysinfo").then((r) => r.json()).catch(() => null),
      fetch("/api/installer/info").then((r) => r.json()).catch(() => null),
    ]);
    st = stRes;
    info = infoRes;
    if (instRes) instInfo = instRes;
  } catch {}

  if (st) {
    if (st.installed_apps) state.installedApps = st.installed_apps;
    if (st.app_usage) state.appUsage = st.app_usage;
    state.activated = Boolean(st.activated);
    state.activationBypassed = Boolean(st.activation_bypassed);
    state.activationKey = st.activation_key || "";
    if (st.account) state.userAccount = st.account;
    if (st.wallpaper) applyWallpaper(st.wallpaper);
    if (st.theme && !th) setTheme(st.theme);
    if (st.datetime) {
      state.datetime = Object.assign(state.datetime, st.datetime);
      updateClock();
    }
    if (st.network) {
      state.netConnected = st.network.connected;
      state.netMode = st.network.mode || "none";
      state.wifiSsid = st.network.ssid || "";
    }
  }
  if (info && info.cpu) state.sysinfo = info;

  // Fetch font catalog asynchronously so cold boot into Setup never waits on fc-list
  fetch("/api/fonts").then((r) => r.json()).then((fRes) => {
    if (fRes && fRes.fonts) state.fonts = fRes.fonts;
  }).catch(() => {});

  if (params.get("all_apps") === "1") {
    state.installedApps = ALL_APPS.map((a) => a.id);
  } else if (params.get("six_apps") === "1") {
    state.installedApps = ["notepad", "files", "youtube", "wifi", "chrome", "terminal", "settings", "appstore"];
  } else if (params.get("fresh") === "1") {
    state.installedApps = ["wifi", "settings", "files", "appstore"];
  }

  if (params.get("mru_demo") === "1") {
    state.appUsage = {
      videoplayer: { count: 5, last_used: 5000 },
      dvdplayer: { count: 3, last_used: 4000 },
      chrome: { count: 2, last_used: 3000 },
      youtube: { count: 1, last_used: 2000 },
    };
  }

  if (params.get("connected") === "1") {
    state.netMode = "ethernet";
    state.netConnected = true;
    state.wifiSsid = "enp0s3 (Ethernet)";
  } else if (params.get("connected") === "0") {
    state.netMode = "none";
    state.netConnected = false;
  }

  renderIcons();
  updateTrayNetwork();

  const searchInp = document.getElementById("start-search-input");
  if (searchInp) {
    searchInp.addEventListener("input", (e) => {
      state.startSearchQuery = e.target.value;
      renderStartMenuGrid();
    });
  }

  document.getElementById("start-btn").addEventListener("click", () => {
    document.getElementById("wifi-flyout").classList.add("hidden");
    document.getElementById("start-menu").classList.toggle("hidden");
  });

  document.getElementById("tray-net-btn").addEventListener("click", () => {
    document.getElementById("start-menu").classList.add("hidden");
    if (state.netMode === "wifi") {
      const fly = document.getElementById("wifi-flyout");
      if (fly.classList.contains("hidden")) openWifiFlyout();
      else fly.classList.add("hidden");
    } else {
      openWifiApp();
    }
  });

  document.getElementById("wifi-rescan-btn").addEventListener("click", openWifiFlyout);
  document.getElementById("wifi-cancel-btn").addEventListener("click", () =>
    document.getElementById("wifi-password-panel").classList.add("hidden")
  );
  document.getElementById("wifi-connect-btn").addEventListener("click", async () => {
    const pw = document.getElementById("wifi-password-input").value;
    if (!pw || !state.selectedSsid) return;
    state.netMode = "wifi";
    state.netConnected = true;
    state.wifiSsid = state.selectedSsid;
    updateTrayNetwork();
    document.getElementById("wifi-flyout").classList.add("hidden");
    await fetch("/api/wifi/connect", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ mode: "wifi", ssid: state.wifiSsid, password: pw }),
    }).catch(() => {});
  });

  document.getElementById("btn-shutdown").addEventListener("click", () => {
    fetch("/api/power", { method: "POST", body: JSON.stringify({ action: "shutdown" }) }).catch(() => {});
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.novaos) {
      window.webkit.messageHandlers.novaos.postMessage({ action: "poweroff" });
    }
    document.getElementById("desktop").classList.add("hidden");
    document.getElementById("shutdown-screen").classList.remove("hidden");
  });
  document.getElementById("btn-restart").addEventListener("click", () => {
    fetch("/api/power", { method: "POST", body: JSON.stringify({ action: "restart" }) }).catch(() => {});
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.novaos) {
      window.webkit.messageHandlers.novaos.postMessage({ action: "reboot" });
    }
    location.reload();
  });
  document.getElementById("power-on-btn").addEventListener("click", () => location.reload());

  document.getElementById("bg-file-input").addEventListener("change", async (e) => {
    const f = e.target.files[0];
    if (!f) return;
    const reader = new FileReader();
    reader.onload = () => { applyWallpaper(reader.result); };
    reader.readAsDataURL(f);
    const rel = `Pictures/${f.name}`;
    try {
      await fetch(`/api/fs/upload?path=${encodeURIComponent(rel)}`, { method: "POST", body: f });
      await fetch("/api/wallpaper", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ wallpaper: rel }),
      });
      applyWallpaper(rel);
    } catch {}
  });

  if (scr === "boot") {
    return;
  } else if (scr) {
    enterDesktop();
    if (scr === "startmenu") document.getElementById("start-menu").classList.remove("hidden");
    else if (scr === "wifi_app") openWifiApp();
    else if (scr === "wifi_flyout") {
      state.netMode = "wifi";
      updateTrayNetwork();
      openWifiFlyout();
    } else if (scr === "store_loading") {
      state.netConnected = false;
      openAppStore(null, 60000);
    } else if (scr === "store_offline") {
      state.netConnected = false;
      openAppStore(null, 50);
    } else if (scr === "store_online") {
      state.netMode = "ethernet";
      state.netConnected = true;
      state.wifiSsid = "enp0s3 (Ethernet)";
      updateTrayNetwork();
      openAppStore(null, 50);
    } else if (scr === "videoplayer") openVideoPlayer();
    else if (scr === "dvdplayer") openDVDPlayer();
    else if (scr === "musicstudio") openMusicStudio();
    else if (scr === "paintstudio") openPaintStudio();
    else if (scr === "chrome") openChrome("https://www.wikipedia.org");
    else if (scr === "youtube") openYouTube();
    else if (scr === "settings_about") openSettings("about");
    else if (scr === "settings_pers") openSettings("personalization");
    else if (scr === "settings_activation") openSettings("activation");
    else if (scr === "settings_datetime") openSettings("datetime");
    else if (scr === "files") openExplorer("", "ThisPC");
    else if (scr === "settings_upd_initial") { state.updateStage = "initial"; openSettings("update"); }
    else if (scr === "settings_upd_looking") { state.updateStage = "looking"; openSettings("update"); }
    else if (scr === "settings_upd_found") { state.updateStage = "found"; openSettings("update"); }
    else if (scr === "settings_upd_none") { state.updateStage = "up_to_date"; openSettings("update"); }
    else if (scr === "installing") {
      document.getElementById("install-screen").classList.remove("hidden");
    } else if (scr === "setup") {
      initSetupWizard(instInfo.disc_key, enterDesktop, instInfo.default_lang || "en-US");
    }
  } else if (instInfo.boot_mode === "live_iso") {
    setTimeout(() => initSetupWizard(instInfo.disc_key, enterDesktop, instInfo.default_lang || "en-US"), 150);
  } else {
    setTimeout(enterDesktop, 450);
  }
});


// ============================================================================
// 11. BETA 2 NEW APPS (Clock, Calendar, Tasks, Code Studio, Disk, Net, Games)
// ============================================================================
function openClockApp() {
  const win = createWindow("clock", "Nova Clock, World Time & Timers", 640, 480, 340, 90, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:14px">
      <div style="display:flex;gap:8px;border-bottom:1px solid rgba(148,163,184,0.28);padding-bottom:10px">
        <button class="btn-primary clk-tab" data-t="world">🕒 World Clock</button>
        <button class="btn-secondary clk-tab" data-t="sw">⏱ Stopwatch</button>
        <button class="btn-secondary clk-tab" data-t="timer">⏲ Timer</button>
      </div>
      <div id="clk-pane-world" style="display:flex;flex-direction:column;gap:12px;flex:1">
        <div id="clk-big-time" style="font-size:44px;font-weight:800;color:#2563EB"></div>
        <div id="clk-big-date" style="font-size:15px;color:#64748B"></div>
        <div id="clk-zones" style="display:grid;grid-template-columns:repeat(2,1fr);gap:10px;margin-top:6px"></div>
      </div>
      <div id="clk-pane-sw" class="hidden" style="display:flex;flex-direction:column;gap:12px;flex:1">
        <div id="sw-readout" style="font-size:46px;font-weight:800;font-family:monospace;text-align:center;padding:16px;background:rgba(148,163,184,0.12);border-radius:12px">00:00.0</div>
        <div style="display:flex;gap:10px;justify-content:center">
          <button id="sw-toggle" class="btn-primary">▶ Start</button>
          <button id="sw-lap" class="btn-secondary">🏁 Lap</button>
          <button id="sw-reset" class="btn-secondary">↺ Reset</button>
        </div>
        <div id="sw-laps" style="flex:1;overflow-y:auto;font-family:monospace;font-size:13px"></div>
      </div>
      <div id="clk-pane-timer" class="hidden" style="display:flex;flex-direction:column;gap:14px;flex:1;align-items:center;justify-content:center">
        <div id="tmr-readout" style="font-size:50px;font-weight:800;font-family:monospace">01:00</div>
        <div style="display:flex;gap:8px;align-items:center">
          <input id="tmr-mins" type="number" min="0" max="120" value="1" style="width:70px;padding:8px;border-radius:8px;border:1px solid #94A3B8" /> min
          <input id="tmr-secs" type="number" min="0" max="59" value="0" style="width:70px;padding:8px;border-radius:8px;border:1px solid #94A3B8" /> sec
          <button id="tmr-set" class="btn-secondary">Set</button>
        </div>
        <div style="display:flex;gap:10px">
          <button id="tmr-start" class="btn-primary">▶ Start Timer</button>
          <button id="tmr-reset" class="btn-secondary">⏹ Reset</button>
        </div>
        <div id="tmr-status" style="font-size:13px;font-weight:700;color:#16A34A"></div>
      </div>
    </div>
  `);

  const zones = [
    ["Chicago (Local)", state.datetime.timezone || "America/Chicago"],
    ["New York", "America/New_York"],
    ["London", "Europe/London"],
    ["Rome", "Europe/Rome"],
    ["Madrid", "Europe/Madrid"],
    ["Tokyo", "Asia/Tokyo"],
  ];

  let swRunning = false, swElapsed = 0, swLast = 0;
  let tmrLeft = 60, tmrRunning = false, tmrLast = 0;

  const updateAll = () => {
    if (!document.body.contains(win)) return;
    const now = getAdjustedNow();
    const parts = formatClockParts(now);
    win.querySelector("#clk-big-time").textContent = parts.timeStr;
    win.querySelector("#clk-big-date").textContent = `${parts.dateStr}, ${parts.year} (${state.datetime.timezone})`;
    win.querySelector("#clk-zones").innerHTML = zones.map(([lbl, tz]) => {
      let s = "";
      try { s = new Intl.DateTimeFormat("en-US", { timeZone: tz, hour: "numeric", minute: "2-digit", second: "2-digit", hour12: !state.datetime.use_24h }).format(now); }
      catch { s = parts.timeStr; }
      return `<div style="padding:10px 12px;border-radius:10px;background:rgba(148,163,184,0.14)"><b>${lbl}</b><div style="font-size:18px;font-weight:700;color:#2563EB">${s}</div></div>`;
    }).join("");

    const ts = performance.now();
    if (swRunning) {
      swElapsed += ts - swLast;
      swLast = ts;
      const tot = Math.floor(swElapsed / 100);
      const mins = String(Math.floor(tot / 600)).padStart(2, "0");
      const secs = String(Math.floor((tot % 600) / 10)).padStart(2, "0");
      win.querySelector("#sw-readout").textContent = `${mins}:${secs}.${tot % 10}`;
    }
    if (tmrRunning) {
      const dt = (ts - tmrLast) / 1000;
      tmrLast = ts;
      tmrLeft = Math.max(0, tmrLeft - dt);
      const sInt = Math.ceil(tmrLeft);
      win.querySelector("#tmr-readout").textContent = `${String(Math.floor(sInt / 60)).padStart(2, "0")}:${String(sInt % 60).padStart(2, "0")}`;
      if (tmrLeft <= 0) {
        tmrRunning = false;
        win.querySelector("#tmr-start").textContent = "▶ Start Timer";
        win.querySelector("#tmr-status").textContent = "⏰ Time is up!";
      }
    }
  };

  win.querySelectorAll(".clk-tab").forEach((b) => {
    b.addEventListener("click", () => {
      win.querySelectorAll(".clk-tab").forEach((x) => (x.className = "btn-secondary clk-tab"));
      b.className = "btn-primary clk-tab";
      ["world", "sw", "timer"].forEach((k) => {
        win.querySelector(`#clk-pane-${k}`).classList.toggle("hidden", k !== b.dataset.t);
      });
    });
  });

  win.querySelector("#sw-toggle").addEventListener("click", (e) => {
    swRunning = !swRunning;
    swLast = performance.now();
    e.target.textContent = swRunning ? "⏸ Pause" : "▶ Start";
  });
  win.querySelector("#sw-lap").addEventListener("click", () => {
    const d = document.createElement("div");
    d.textContent = `Lap ${win.querySelector("#sw-laps").children.length + 1}: ${win.querySelector("#sw-readout").textContent}`;
    win.querySelector("#sw-laps").prepend(d);
  });
  win.querySelector("#sw-reset").addEventListener("click", () => {
    swRunning = false; swElapsed = 0;
    win.querySelector("#sw-toggle").textContent = "▶ Start";
    win.querySelector("#sw-readout").textContent = "00:00.0";
    win.querySelector("#sw-laps").innerHTML = "";
  });

  win.querySelector("#tmr-set").addEventListener("click", () => {
    tmrRunning = false;
    const m = Math.max(0, parseInt(win.querySelector("#tmr-mins").value, 10) || 0);
    const s = Math.max(0, Math.min(59, parseInt(win.querySelector("#tmr-secs").value, 10) || 0));
    tmrLeft = m * 60 + s;
    win.querySelector("#tmr-readout").textContent = `${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
    win.querySelector("#tmr-status").textContent = "";
  });
  win.querySelector("#tmr-start").addEventListener("click", (e) => {
    tmrRunning = !tmrRunning;
    tmrLast = performance.now();
    e.target.textContent = tmrRunning ? "⏸ Pause" : "▶ Start Timer";
    win.querySelector("#tmr-status").textContent = "";
  });
  win.querySelector("#tmr-reset").addEventListener("click", () => {
    tmrRunning = false; tmrLeft = 60;
    win.querySelector("#tmr-start").textContent = "▶ Start Timer";
    win.querySelector("#tmr-readout").textContent = "01:00";
    win.querySelector("#tmr-status").textContent = "";
  });

  updateAll();
  const clkInt = setInterval(updateAll, 150);
  win._cleanup = () => clearInterval(clkInt);
}

function openCalendarApp() {
  const now = getAdjustedNow();
  let viewY = now.getFullYear(), viewM = now.getMonth();
  let selKey = `${viewY}-${String(viewM + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
  let events = {};

  const win = createWindow("calendar", "Nova Calendar & Planner", 760, 560, 300, 75, `
    <div style="display:flex;height:100%">
      <div style="flex:1;padding:16px;display:flex;flex-direction:column;gap:12px">
        <div style="display:flex;justify-content:space-between;align-items:center">
          <div id="cal-title" style="font-size:22px;font-weight:800"></div>
          <div style="display:flex;gap:6px">
            <button id="cal-prev" class="btn-secondary">◀</button>
            <button id="cal-today" class="btn-primary">Today</button>
            <button id="cal-next" class="btn-secondary">▶</button>
          </div>
        </div>
        <div style="display:grid;grid-template-columns:repeat(7,1fr);text-align:center;font-size:12px;font-weight:700;color:#64748B">
          <div>Sun</div><div>Mon</div><div>Tue</div><div>Wed</div><div>Thu</div><div>Fri</div><div>Sat</div>
        </div>
        <div id="cal-grid" class="cal-grid" style="flex:1"></div>
      </div>
      <div style="width:240px;border-left:1px solid rgba(148,163,184,0.28);padding:16px;display:flex;flex-direction:column;gap:10px">
        <div id="cal-sel-hdr" style="font-weight:800;font-size:15px"></div>
        <div style="display:flex;gap:6px">
          <input id="cal-ev-inp" placeholder="Add event..." style="flex:1;padding:7px;border:1px solid #94A3B8;border-radius:6px" />
          <button id="cal-ev-add" class="btn-primary">+</button>
        </div>
        <div id="cal-ev-list" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:6px;font-size:13px"></div>
      </div>
    </div>
  `);

  const saveEvents = () => fetch("/api/fs/write", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path: "Documents/calendar_events.json", content: JSON.stringify(events, null, 2) }),
  }).catch(() => {});

  const renderEvents = () => {
    win.querySelector("#cal-sel-hdr").textContent = `Events: ${selKey}`;
    const list = win.querySelector("#cal-ev-list");
    const items = events[selKey] || [];
    list.innerHTML = items.length ? "" : `<div style="color:#64748B">No events for ${selKey}.</div>`;
    items.forEach((txt, idx) => {
      const r = document.createElement("div");
      r.style.cssText = "display:flex;justify-content:space-between;align-items:center;padding:6px 8px;border-radius:6px;background:rgba(37,99,235,0.12)";
      r.innerHTML = `<span>${escapeHtml(txt)}</span><button class="btn-small">✕</button>`;
      r.querySelector("button").addEventListener("click", () => {
        events[selKey].splice(idx, 1);
        saveEvents(); render();
      });
      list.appendChild(r);
    });
  };

  const render = () => {
    const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    win.querySelector("#cal-title").textContent = `${months[viewM]} ${viewY}`;
    const grid = win.querySelector("#cal-grid");
    grid.innerHTML = "";
    const firstDay = new Date(viewY, viewM, 1).getDay();
    const daysInMonth = new Date(viewY, viewM + 1, 0).getDate();
    const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;

    for (let i = 0; i < firstDay; i++) grid.appendChild(document.createElement("div"));
    for (let d = 1; d <= daysInMonth; d++) {
      const key = `${viewY}-${String(viewM + 1).padStart(2, "0")}-${String(d).padStart(2, "0")}`;
      const cell = document.createElement("div");
      cell.className = "cal-cell" + (key === todayStr ? " today" : "") + (key === selKey ? " selected" : "");
      const cnt = (events[key] || []).length;
      cell.innerHTML = `<span>${d}</span>${cnt ? `<span style="font-size:10px;opacity:0.85">● ${cnt}</span>` : ""}`;
      cell.addEventListener("click", () => { selKey = key; render(); });
      grid.appendChild(cell);
    }
    renderEvents();
  };

  fetch("/api/fs/read?path=Documents%2Fcalendar_events.json").then((r) => r.ok ? r.json() : null).then((d) => {
    if (d && d.content) try { events = JSON.parse(d.content) || {}; } catch {}
    render();
  }).catch(render);

  win.querySelector("#cal-prev").addEventListener("click", () => { if (--viewM < 0) { viewM = 11; viewY--; } render(); });
  win.querySelector("#cal-next").addEventListener("click", () => { if (++viewM > 11) { viewM = 0; viewY++; } render(); });
  win.querySelector("#cal-today").addEventListener("click", () => { viewY = now.getFullYear(); viewM = now.getMonth(); render(); });
  win.querySelector("#cal-ev-add").addEventListener("click", () => {
    const inp = win.querySelector("#cal-ev-inp");
    const v = inp.value.trim();
    if (!v) return;
    events[selKey] = events[selKey] || [];
    events[selKey].push(v);
    inp.value = "";
    saveEvents(); render();
  });
}

function openTasksApp() {
  let tasks = [{ text: "Explore Nova OS 2.00 Beta 2 new apps", priority: "High", done: false }];
  let filter = "all";
  const win = createWindow("tasks", "Nova Tasks & Reminders", 600, 500, 350, 95, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:12px">
      <div style="font-size:20px;font-weight:800">✅ Tasks &amp; Reminders</div>
      <div style="display:flex;gap:8px">
        <input id="tk-inp" placeholder="Add a new task..." style="flex:1;padding:9px 12px;border:1px solid #94A3B8;border-radius:8px" />
        <select id="tk-pri" style="padding:8px;border:1px solid #94A3B8;border-radius:8px"><option>Normal</option><option>High</option></select>
        <button id="tk-add" class="btn-primary">Add</button>
      </div>
      <div style="display:flex;gap:8px">
        <button class="btn-primary tk-f" data-f="all">All</button>
        <button class="btn-secondary tk-f" data-f="active">Active</button>
        <button class="btn-secondary tk-f" data-f="done">Completed</button>
      </div>
      <div id="tk-list" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:8px"></div>
    </div>
  `);
  const saveTasks = () => fetch("/api/fs/write", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ path: "Documents/tasks.json", content: JSON.stringify(tasks, null, 2) }),
  }).catch(() => {});

  const render = () => {
    const list = win.querySelector("#tk-list");
    list.innerHTML = "";
    tasks.forEach((tk, idx) => {
      if (filter === "active" && tk.done) return;
      if (filter === "done" && !tk.done) return;
      const row = document.createElement("div");
      row.style.cssText = "display:flex;justify-content:space-between;align-items:center;padding:10px 12px;border-radius:10px;background:rgba(148,163,184,0.14)";
      row.innerHTML = `
        <label style="display:flex;align-items:center;gap:10px;cursor:pointer;flex:1">
          <input type="checkbox" ${tk.done ? "checked" : ""} />
          <span style="${tk.done ? "text-decoration:line-through;opacity:0.6" : ""}">${escapeHtml(tk.text)}</span>
          <span style="font-size:11px;padding:2px 6px;border-radius:4px;background:${tk.priority === "High" ? "#FEE2E2;color:#B91C1C" : "#E0F2FE;color:#0369A1"}">${escapeHtml(tk.priority)}</span>
        </label>
        <button class="btn-small">🗑</button>
      `;
      row.querySelector("input").addEventListener("change", () => { tk.done = !tk.done; saveTasks(); render(); });
      row.querySelector("button").addEventListener("click", () => { tasks.splice(idx, 1); saveTasks(); render(); });
      list.appendChild(row);
    });
  };

  fetch("/api/fs/read?path=Documents%2Ftasks.json").then((r) => r.ok ? r.json() : null).then((d) => {
    if (d && d.content) try { tasks = JSON.parse(d.content) || tasks; } catch {}
    render();
  }).catch(render);

  win.querySelector("#tk-add").addEventListener("click", () => {
    const v = win.querySelector("#tk-inp").value.trim();
    if (!v) return;
    tasks.unshift({ text: v, priority: win.querySelector("#tk-pri").value, done: false });
    win.querySelector("#tk-inp").value = "";
    saveTasks(); render();
  });
  win.querySelectorAll(".tk-f").forEach((b) => b.addEventListener("click", () => {
    filter = b.dataset.f;
    win.querySelectorAll(".tk-f").forEach((x) => (x.className = "btn-secondary tk-f"));
    b.className = "btn-primary tk-f";
    render();
  }));
}

function openCodeStudio(initialFile = "Documents/hello_nova.html") {
  const sampleHtml = "<h1>Hello Nova OS 2.00 Beta 2!</h1>\n<p>Edit HTML/CSS/JS here and click <b>Run Preview</b>.</p>\n<button onclick=\"document.body.style.background='#DBEAFE'\">Test Click</button>";
  const win = createWindow("codeide", "Nova Code Studio", 900, 560, 260, 75, `
    <div style="display:flex;flex-direction:column;height:100%">
      <div style="padding:8px 14px;border-bottom:1px solid rgba(148,163,184,0.28);display:flex;gap:8px;align-items:center">
        <input id="cs-fname" value="${escapeHtml(initialFile || "Documents/hello_nova.html")}" style="width:240px;padding:6px 10px;border:1px solid #94A3B8;border-radius:6px" />
        <button id="cs-load" class="btn-secondary">Load</button>
        <button id="cs-save" class="btn-secondary">Save</button>
        <button id="cs-run" class="btn-primary">▶ Run Preview</button>
        <span id="cs-msg" style="font-size:12.5px;color:#16A34A;font-weight:600"></span>
      </div>
      <div style="flex:1;display:grid;grid-template-columns:1fr 1fr;overflow:hidden">
        <textarea id="cs-ed" spellcheck="false" style="border:none;border-right:1px solid rgba(148,163,184,0.28);padding:14px;font-family:monospace;font-size:14px;background:#0F172A;color:#E2E8F0;outline:none;resize:none">${sampleHtml}</textarea>
        <iframe id="cs-prev" sandbox="allow-scripts" style="border:none;width:100%;height:100%;background:#FFFFFF"></iframe>
      </div>
    </div>
  `);
  const ed = win.querySelector("#cs-ed");
  const prev = win.querySelector("#cs-prev");
  const runPreview = () => { prev.srcdoc = ed.value; };
  runPreview();
  win.querySelector("#cs-run").addEventListener("click", runPreview);
  win.querySelector("#cs-load").addEventListener("click", async () => {
    const r = await fetch(`/api/fs/read?path=${encodeURIComponent(win.querySelector("#cs-fname").value)}`);
    if (r.ok) { const d = await r.json(); ed.value = d.content; runPreview(); }
  });
  win.querySelector("#cs-save").addEventListener("click", async () => {
    await fetch("/api/fs/write", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ path: win.querySelector("#cs-fname").value, content: ed.value }),
    });
    win.querySelector("#cs-msg").textContent = "Saved!";
    setTimeout(() => (win.querySelector("#cs-msg").textContent = ""), 1800);
  });
}

function openDiskManager() {
  const win = createWindow("diskutil", "Nova Disk & Memory Manager", 720, 500, 300, 85, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:14px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div style="font-size:20px;font-weight:800">💾 Storage, RAM &amp; ZRAM Swap Manager</div>
        <div style="display:flex;gap:8px">
          <button id="dm-clean" class="btn-secondary">🧹 Clean .NOSP Cache</button>
          <button id="dm-refresh" class="btn-primary">↻ Refresh</button>
        </div>
      </div>
      <div id="dm-summary" style="display:grid;grid-template-columns:repeat(3,1fr);gap:12px"></div>
      <div style="font-weight:700">Detected Physical / Virtual Block Disks:</div>
      <div id="dm-disks" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:8px"></div>
      <div id="dm-status" style="font-size:13px;color:#16A34A;font-weight:600"></div>
    </div>
  `);
  const load = async () => {
    const m = await fetch("/api/sysmonitor").then((r) => r.json()).catch(() => null);
    if (!m) return;
    win.querySelector("#dm-summary").innerHTML = `
      <div style="padding:12px;border-radius:10px;background:rgba(37,99,235,0.12)"><b>RAM Usage</b><div style="margin-top:4px">${m.mem_used_mb} / ${m.mem_total_mb} MB</div></div>
      <div style="padding:12px;border-radius:10px;background:rgba(16,185,129,0.12)"><b>ZRAM Swap</b><div style="margin-top:4px">${m.swap_used_mb} / ${m.swap_total_mb} MB</div></div>
      <div style="padding:12px;border-radius:10px;background:rgba(245,158,11,0.12)"><b>Filesystem (/)</b><div style="margin-top:4px">${m.disk_free_gb} GB free / ${m.disk_total_gb} GB</div></div>
    `;
    win.querySelector("#dm-disks").innerHTML = (m.disks || []).map((d) =>
      `<div style="padding:10px 14px;border-radius:10px;background:rgba(148,163,184,0.14);display:flex;justify-content:space-between">
        <span><b>${escapeHtml(d.device)}</b> — ${escapeHtml(d.model)}</span>
        <span>${d.size_gb} GB (${escapeHtml(d.tran)})</span>
      </div>`
    ).join("");
  };
  win.querySelector("#dm-refresh").addEventListener("click", load);
  win.querySelector("#dm-clean").addEventListener("click", async () => {
    const r = await fetch("/api/system/cleanup", { method: "POST" }).then((x) => x.json()).catch(() => ({}));
    win.querySelector("#dm-status").textContent = `Cleaned ${r.removed_files || 0} cached .NOSP bundles (${r.freed_bytes || 0} bytes freed).`;
    load();
  });
  load();
}

function openNetTools() {
  const win = createWindow("nettools", "Nova Network Diagnostics", 680, 480, 320, 90, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:12px">
      <div style="display:flex;justify-content:space-between;align-items:center">
        <div style="font-size:20px;font-weight:800">🌐 Network Interfaces, DNS &amp; Ping</div>
        <button id="nt-run" class="btn-primary">▶ Run Diagnostics</button>
      </div>
      <pre id="nt-out" style="flex:1;margin:0;padding:14px;border-radius:10px;background:#0F172A;color:#38BDF8;font-family:monospace;font-size:13px;overflow:auto">Click 'Run Diagnostics' to test real interface IPs, DNS resolution, and gateway ping...</pre>
    </div>
  `);
  const runDiag = async () => {
    const out = win.querySelector("#nt-out");
    out.textContent = "Running interface scan, DNS lookup (github.com), and gateway ping (10.0.2.2)...";
    const d = await fetch("/api/net/diag").then((r) => r.json()).catch(() => null);
    if (!d) { out.textContent = "Diagnostics failed."; return; }
    const sc = d.scan || {};
    out.textContent = [
      `Ethernet Interfaces : ${(sc.ethernet_interfaces || []).join(", ") || "none"}`,
      `Wi-Fi 802.11 Cards  : ${(sc.wifi_interfaces || []).join(", ") || "none"}`,
      `DNS Lookup (github) : ${d.dns_ip ? `${d.dns_ip} (${d.dns_ms} ms)` : d.dns_error}`,
      "",
      "Gateway Ping (10.0.2.2):",
      d.ping_gateway || "(no response)",
    ].join("\n");
  };
  win.querySelector("#nt-run").addEventListener("click", runDiag);
  runDiag();
}

function openSnakeGame() {
  const win = createWindow("snake", "Nova Snake Classic", 500, 560, 380, 75, `
    <div style="display:flex;flex-direction:column;height:100%;background:#0F172A;color:#FFF;padding:14px;gap:10px;align-items:center" tabindex="0">
      <div style="width:100%;display:flex;justify-content:space-between;align-items:center">
        <span style="font-weight:800;color:#4ADE80">🐍 Score: <span id="snk-score">0</span> • Best: <span id="snk-best">0</span></span>
        <div style="display:flex;gap:8px">
          <button id="snk-reset" class="dvd-btn">Restart</button>
        </div>
      </div>
      <canvas id="snk-cvs" width="440" height="440" style="background:#020617;border:2px solid #22C55E;border-radius:10px"></canvas>
      <div style="font-size:12px;color:#94A3B8">Use Arrow Keys or WASD to steer</div>
    </div>
  `);
  const cvs = win.querySelector("#snk-cvs"), ctx = cvs.getContext("2d");
  const cells = 22, sz = 20;
  let snake = [{ x: 11, y: 11 }, { x: 10, y: 11 }], dir = { x: 1, y: 0 }, food = { x: 15, y: 11 }, score = 0, best = 0;
  const placeFood = () => { food = { x: Math.floor(Math.random() * cells), y: Math.floor(Math.random() * cells) }; };
  const reset = () => { snake = [{ x: 11, y: 11 }, { x: 10, y: 11 }]; dir = { x: 1, y: 0 }; score = 0; placeFood(); win.querySelector("#snk-score").textContent = "0"; };
  const step = () => {
    if (!document.body.contains(win)) return;
    const head = { x: snake[0].x + dir.x, y: snake[0].y + dir.y };
    if (head.x < 0 || head.y < 0 || head.x >= cells || head.y >= cells || snake.some((s) => s.x === head.x && s.y === head.y)) {
      reset();
    } else {
      snake.unshift(head);
      if (head.x === food.x && head.y === food.y) {
        score += 10; best = Math.max(best, score);
        win.querySelector("#snk-score").textContent = score;
        win.querySelector("#snk-best").textContent = best;
        placeFood();
      } else snake.pop();
    }
    ctx.fillStyle = "#020617"; ctx.fillRect(0, 0, 440, 440);
    ctx.fillStyle = "#EF4444"; ctx.fillRect(food.x * sz + 2, food.y * sz + 2, sz - 4, sz - 4);
    snake.forEach((s, i) => { ctx.fillStyle = i === 0 ? "#4ADE80" : "#22C55E"; ctx.fillRect(s.x * sz + 1, s.y * sz + 1, sz - 2, sz - 2); });
  };
  win.querySelector("#snk-reset").addEventListener("click", reset);
  win.querySelector("[tabindex]").addEventListener("keydown", (e) => {
    if ((e.key === "ArrowUp" || e.key === "w") && dir.y === 0) dir = { x: 0, y: -1 };
    else if ((e.key === "ArrowDown" || e.key === "s") && dir.y === 0) dir = { x: 0, y: 1 };
    else if ((e.key === "ArrowLeft" || e.key === "a") && dir.x === 0) dir = { x: -1, y: 0 };
    else if ((e.key === "ArrowRight" || e.key === "d") && dir.x === 0) dir = { x: 1, y: 0 };
  });
  const t = setInterval(step, 120);
  win._cleanup = () => clearInterval(t);
  step();
}

function openMinesweeperGame() {
  const N = 10, MINES = 12;
  const win = createWindow("mines", "Nova Minesweeper (10x10)", 430, 500, 410, 80, `
    <div style="display:flex;flex-direction:column;height:100%;padding:14px;gap:10px;align-items:center">
      <div style="width:100%;display:flex;justify-content:space-between;align-items:center">
        <span id="msw-info" style="font-weight:800">💣 Mines: ${MINES}</span>
        <div style="display:flex;gap:8px">
          <button id="msw-flag-mode" class="btn-secondary">🚩 Flag Mode: OFF</button>
          <button id="msw-reset" class="btn-primary">New Game</button>
        </div>
      </div>
      <div id="msw-grid" class="mines-grid" style="grid-template-columns:repeat(${N}, 34px)"></div>
    </div>
  `);
  let board = [], flagMode = false, gameOver = false;
  const init = () => {
    gameOver = false;
    board = Array.from({ length: N * N }, () => ({ mine: false, rev: false, flag: false, adj: 0 }));
    let placed = 0;
    while (placed < MINES) {
      const i = Math.floor(Math.random() * N * N);
      if (!board[i].mine) { board[i].mine = true; placed++; }
    }
    const nbrs = (idx) => {
      const r = Math.floor(idx / N), c = idx % N, out = [];
      for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) {
        if (dr === 0 && dc === 0) continue;
        const nr = r + dr, nc = c + dc;
        if (nr >= 0 && nr < N && nc >= 0 && nc < N) out.push(nr * N + nc);
      }
      return out;
    };
    board.forEach((cell, i) => { cell.adj = nbrs(i).filter((j) => board[j].mine).length; });
    const reveal = (i) => {
      const cell = board[i];
      if (cell.rev || cell.flag) return;
      cell.rev = true;
      if (cell.mine) { gameOver = true; board.forEach((c) => { if (c.mine) c.rev = true; }); win.querySelector("#msw-info").textContent = "💥 Boom! Game Over"; return; }
      if (cell.adj === 0) nbrs(i).forEach(reveal);
    };
    const draw = () => {
      const g = win.querySelector("#msw-grid"); g.innerHTML = "";
      let safeLeft = 0;
      board.forEach((cell, i) => {
        if (!cell.mine && !cell.rev) safeLeft++;
        const btn = document.createElement("button");
        btn.className = "mine-cell" + (cell.rev ? " revealed" : "");
        btn.textContent = cell.rev ? (cell.mine ? "💣" : (cell.adj || "")) : (cell.flag ? "🚩" : "");
        btn.addEventListener("click", () => {
          if (gameOver) return;
          if (flagMode) cell.flag = !cell.flag;
          else reveal(i);
          draw();
        });
        g.appendChild(btn);
      });
      if (!gameOver && safeLeft === 0) { gameOver = true; win.querySelector("#msw-info").textContent = "🎉 Cleared! You Win!"; }
    };
    draw();
  };
  win.querySelector("#msw-flag-mode").addEventListener("click", (e) => {
    flagMode = !flagMode;
    e.target.textContent = `🚩 Flag Mode: ${flagMode ? "ON" : "OFF"}`;
    e.target.className = flagMode ? "btn-primary" : "btn-secondary";
  });
  win.querySelector("#msw-reset").addEventListener("click", () => { win.querySelector("#msw-info").textContent = `💣 Mines: ${MINES}`; init(); });
  init();
}

function open2048Game() {
  const win = createWindow("game2048", "Nova 2048 Puzzle", 420, 500, 400, 80, `
    <div style="display:flex;flex-direction:column;height:100%;padding:16px;gap:12px;align-items:center" tabindex="0">
      <div style="width:340px;display:flex;justify-content:space-between;align-items:center">
        <span style="font-size:20px;font-weight:800">2048 • Score: <span id="g2-score">0</span></span>
        <button id="g2-new" class="btn-primary">New Game</button>
      </div>
      <div id="g2-board" class="g2048-board"></div>
      <div style="display:flex;gap:8px">
        <button class="btn-secondary g2-mv" data-d="L">◀</button>
        <button class="btn-secondary g2-mv" data-d="U">▲</button>
        <button class="btn-secondary g2-mv" data-d="D">▼</button>
        <button class="btn-secondary g2-mv" data-d="R">▶</button>
      </div>
    </div>
  `);
  let grid = Array(16).fill(0), score = 0;
  const colors = { 0: "#334155", 2: "#E2E8F0", 4: "#FED7AA", 8: "#FB923C", 16: "#F97316", 32: "#EF4444", 64: "#DC2626", 128: "#FACC15", 256: "#EAB308", 512: "#22C55E", 1024: "#0EA5E9", 2048: "#A855F7" };
  const spawn = () => {
    const empty = grid.map((v, i) => v === 0 ? i : -1).filter((i) => i >= 0);
    if (empty.length) grid[empty[Math.floor(Math.random() * empty.length)]] = Math.random() < 0.9 ? 2 : 4;
  };
  const render = () => {
    win.querySelector("#g2-score").textContent = score;
    win.querySelector("#g2-board").innerHTML = grid.map((v) =>
      `<div class="g2048-tile" style="background:${colors[v] || "#7C3AED"};color:${v <= 4 ? "#0F172A" : "#FFF"}">${v || ""}</div>`
    ).join("");
  };
  const slideRow = (row) => {
    const arr = row.filter((x) => x > 0);
    for (let i = 0; i < arr.length - 1; i++) {
      if (arr[i] === arr[i + 1]) { arr[i] *= 2; score += arr[i]; arr.splice(i + 1, 1); }
    }
    while (arr.length < 4) arr.push(0);
    return arr;
  };
  const move = (d) => {
    const prev = grid.join(",");
    for (let i = 0; i < 4; i++) {
      let row = [0, 1, 2, 3].map((j) => d === "L" || d === "R" ? grid[i * 4 + j] : grid[j * 4 + i]);
      if (d === "R" || d === "D") row.reverse();
      row = slideRow(row);
      if (d === "R" || d === "D") row.reverse();
      [0, 1, 2, 3].forEach((j) => { if (d === "L" || d === "R") grid[i * 4 + j] = row[j]; else grid[j * 4 + i] = row[j]; });
    }
    if (grid.join(",") !== prev) spawn();
    render();
  };
  const reset = () => { grid = Array(16).fill(0); score = 0; spawn(); spawn(); render(); };
  win.querySelector("#g2-new").addEventListener("click", reset);
  win.querySelectorAll(".g2-mv").forEach((b) => b.addEventListener("click", () => move(b.dataset.d)));
  win.querySelector("[tabindex]").addEventListener("keydown", (e) => {
    if (e.key === "ArrowLeft") move("L");
    else if (e.key === "ArrowRight") move("R");
    else if (e.key === "ArrowUp") move("U");
    else if (e.key === "ArrowDown") move("D");
  });
  reset();
}


// ============================================================================
// 12. BETA 3 NEW APPS (Weather, Piano Synth, Pomodoro, Converter, TicTacToe, DevTools)
// ============================================================================
function openWeatherApp() {
  let unit = "F";
  let lastData = null;
  const win = createWindow("weather", "Nova Weather & Forecast", 700, 500, 320, 85, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:14px">
      <div style="display:flex;gap:8px;align-items:center">
        <input id="wx-city" value="Chicago" placeholder="Enter city name..." style="flex:1;padding:8px 12px;border:1px solid #94A3B8;border-radius:8px;font-size:14px" />
        <button id="wx-go" class="btn-primary">Search</button>
        <button id="wx-unit" class="btn-secondary">°F / °C</button>
      </div>
      <div style="display:flex;gap:6px;flex-wrap:wrap">
        <button class="btn-small wx-q" data-c="Chicago">Chicago</button>
        <button class="btn-small wx-q" data-c="New York">New York</button>
        <button class="btn-small wx-q" data-c="Madrid">Madrid</button>
        <button class="btn-small wx-q" data-c="Rome">Rome</button>
        <button class="btn-small wx-q" data-c="London">London</button>
        <button class="btn-small wx-q" data-c="Tokyo">Tokyo</button>
      </div>
      <div id="wx-card" style="padding:18px;border-radius:14px;background:linear-gradient(135deg,#0284C7,#1D4ED8);color:#FFFFFF;display:flex;justify-content:space-between;align-items:center">
        <div><div id="wx-loc" style="font-size:24px;font-weight:800">Loading Weather...</div><div id="wx-meta" style="font-size:13px;opacity:0.9;margin-top:4px"></div></div>
        <div id="wx-temp" style="font-size:48px;font-weight:900">--°</div>
      </div>
      <div style="font-weight:700">5-Day Forecast:</div>
      <div id="wx-days" style="display:grid;grid-template-columns:repeat(5,1fr);gap:10px;flex:1"></div>
    </div>
  `);
  const fmtT = (c) => unit === "F" ? `${Math.round(c * 9 / 5 + 32)}°F` : `${Math.round(c)}°C`;
  const wmoDesc = (code) => code === 0 ? "☀ Clear" : code <= 3 ? "⛅ Partly Cloudy" : code < 60 ? "🌫 Fog" : code < 70 ? "🌧 Rain" : "❄ Snow";
  const render = () => {
    if (!lastData) return;
    const cur = lastData.current || {};
    win.querySelector("#wx-loc").textContent = `${lastData.city} (${lastData.live ? "Live Ethernet" : "Cached Offline"})`;
    win.querySelector("#wx-temp").textContent = fmtT(cur.temperature_2m ?? 12);
    win.querySelector("#wx-meta").textContent = `${wmoDesc(cur.weather_code ?? 1)} • Humidity: ${cur.relative_humidity_2m ?? 55}% • Wind: ${cur.wind_speed_10m ?? 10} km/h`;
    const d = lastData.daily || {};
    const days = d.time || [];
    win.querySelector("#wx-days").innerHTML = days.slice(0, 5).map((dt, i) => `
      <div style="padding:12px;border-radius:12px;background:rgba(148,163,184,0.14);display:flex;flex-direction:column;justify-content:space-between;text-align:center">
        <div style="font-weight:700;font-size:12.5px">${escapeHtml(dt)}</div>
        <div style="font-size:14px">${wmoDesc((d.weather_code || [])[i] ?? 1)}</div>
        <div style="font-weight:800;color:#2563EB">${fmtT((d.temperature_2m_max || [])[i] ?? 12)} / ${fmtT((d.temperature_2m_min || [])[i] ?? 4)}</div>
      </div>
    `).join("");
  };
  const loadCity = async (c) => {
    win.querySelector("#wx-city").value = c;
    lastData = await fetch(`/api/weather?city=${encodeURIComponent(c)}`).then((r) => r.json()).catch(() => null);
    render();
  };
  win.querySelector("#wx-go").addEventListener("click", () => loadCity(win.querySelector("#wx-city").value));
  win.querySelector("#wx-city").addEventListener("keydown", (e) => { if (e.key === "Enter") loadCity(e.target.value); });
  win.querySelector("#wx-unit").addEventListener("click", () => { unit = unit === "F" ? "C" : "F"; render(); });
  win.querySelectorAll(".wx-q").forEach((b) => b.addEventListener("click", () => loadCity(b.dataset.c)));
  loadCity("Chicago");
}

function openPianoApp() {
  const win = createWindow("piano", "Nova Piano & Audio Synth", 760, 420, 300, 110, `
    <div style="display:flex;flex-direction:column;height:100%;background:#0F172A;color:#F8FAFC;padding:16px;gap:14px" tabindex="0">
      <div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px">
        <span style="font-size:18px;font-weight:800;color:#38BDF8">🎹 2-Octave Synthesizer</span>
        <div style="display:flex;gap:8px;align-items:center">
          <select id="pn-wave" style="padding:6px 10px;border-radius:6px;background:#1E293B;color:#FFF;border:1px solid #475569">
            <option value="triangle">Triangle (Warm)</option>
            <option value="sine">Sine (Pure)</option>
            <option value="sawtooth">Sawtooth (Lead)</option>
            <option value="square">Square (Retro 8-Bit)</option>
          </select>
          <button id="pn-oct-dn" class="dvd-btn">Oct −</button>
          <span id="pn-oct-lbl" style="font-weight:700">Octave 4</span>
          <button id="pn-oct-up" class="dvd-btn">Oct +</button>
          <button id="pn-demo" class="btn-primary">▶ Demo Tune</button>
        </div>
      </div>
      <div id="pn-keys" style="position:relative;flex:1;display:flex;gap:4px;background:#020617;padding:12px;border-radius:12px;user-select:none"></div>
      <div id="pn-note-info" style="font-size:12.5px;color:#94A3B8">Keys A S D F G H J K L or click piano keys to play</div>
    </div>
  `);
  let oct = 4, actx = null;
  const semitones = [
    ["C", 0, false, "a"], ["C#", 1, true], ["D", 2, false, "s"], ["D#", 3, true], ["E", 4, false, "d"],
    ["F", 5, false, "f"], ["F#", 6, true], ["G", 7, false, "g"], ["G#", 8, true], ["A", 9, false, "h"],
    ["A#", 10, true], ["B", 11, false, "j"], ["C5", 12, false, "k"], ["D5", 14, false, "l"], ["E5", 16, false],
  ];
  const playFreq = (semi, name) => {
    try {
      if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
      const freq = 440 * Math.pow(2, ((oct - 4) * 12 + semi - 9) / 12);
      const osc = actx.createOscillator(), g = actx.createGain();
      osc.type = win.querySelector("#pn-wave").value;
      osc.frequency.setValueAtTime(freq, actx.currentTime);
      g.gain.setValueAtTime(0.18, actx.currentTime);
      g.gain.exponentialRampToValueAtTime(0.001, actx.currentTime + 0.55);
      osc.connect(g); g.connect(actx.destination);
      osc.start(); osc.stop(actx.currentTime + 0.58);
      win.querySelector("#pn-note-info").textContent = `♪ Playing ${name} (${freq.toFixed(1)} Hz)`;
    } catch {}
  };
  const keysEl = win.querySelector("#pn-keys");
  semitones.filter((s) => !s[2]).forEach(([name, semi, , kb]) => {
    const k = document.createElement("button");
    k.style.cssText = "flex:1;height:100%;background:#F8FAFC;color:#0F172A;border:1px solid #94A3B8;border-radius:0 0 8px 8px;font-weight:800;display:flex;flex-direction:column;justify-content:flex-end;align-items:center;padding-bottom:10px;cursor:pointer";
    k.innerHTML = `<span>${name}</span>${kb ? `<span style="font-size:10px;color:#64748B">[${kb.toUpperCase()}]</span>` : ""}`;
    k.addEventListener("mousedown", () => { k.style.background = "#93C5FD"; playFreq(semi, name); });
    k.addEventListener("mouseup", () => { k.style.background = "#F8FAFC"; });
    keysEl.appendChild(k);
  });
  win.querySelector("#pn-oct-dn").addEventListener("click", () => { oct = Math.max(2, oct - 1); win.querySelector("#pn-oct-lbl").textContent = `Octave ${oct}`; });
  win.querySelector("#pn-oct-up").addEventListener("click", () => { oct = Math.min(6, oct + 1); win.querySelector("#pn-oct-lbl").textContent = `Octave ${oct}`; });
  win.querySelector("#pn-demo").addEventListener("click", () => {
    [[0, "C"], [4, "E"], [7, "G"], [12, "C5"], [7, "G"], [12, "C5"]].forEach(([s, n], idx) => {
      setTimeout(() => playFreq(s, n), idx * 210);
    });
  });
  win.querySelector("[tabindex]").addEventListener("keydown", (e) => {
    const found = semitones.find((x) => x[3] === e.key.toLowerCase());
    if (found) playFreq(found[1], found[0]);
  });
}

function openPomodoroApp() {
  const win = createWindow("pomodoro", "Nova Focus Pomodoro Timer", 480, 440, 390, 100, `
    <div style="display:flex;flex-direction:column;height:100%;padding:20px;gap:16px;align-items:center;justify-content:center">
      <div style="display:flex;gap:8px">
        <button class="btn-primary pm-mode" data-m="25">Focus (25m)</button>
        <button class="btn-secondary pm-mode" data-m="5">Short Break (5m)</button>
        <button class="btn-secondary pm-mode" data-m="15">Long Break (15m)</button>
      </div>
      <div id="pm-time" style="font-size:64px;font-weight:900;font-family:monospace;color:#EF4444">25:00</div>
      <div style="width:100%;height:12px;background:rgba(148,163,184,0.25);border-radius:8px;overflow:hidden">
        <div id="pm-bar" style="height:100%;width:100%;background:#EF4444"></div>
      </div>
      <div style="display:flex;gap:10px">
        <button id="pm-toggle" class="btn-primary">▶ Start Focus</button>
        <button id="pm-reset" class="btn-secondary">↺ Reset</button>
      </div>
      <div id="pm-sessions" style="font-size:13px;font-weight:700;color:#64748B">Completed Focus Sessions: 0</div>
    </div>
  `);
  let total = 25 * 60, left = 25 * 60, running = false, sessions = 0;
  const draw = () => {
    win.querySelector("#pm-time").textContent = `${String(Math.floor(left / 60)).padStart(2, "0")}:${String(left % 60).padStart(2, "0")}`;
    win.querySelector("#pm-bar").style.width = `${Math.max(0, (left / total) * 100)}%`;
  };
  win.querySelectorAll(".pm-mode").forEach((b) => b.addEventListener("click", () => {
    running = false;
    win.querySelector("#pm-toggle").textContent = "▶ Start Focus";
    win.querySelectorAll(".pm-mode").forEach((x) => (x.className = "btn-secondary pm-mode"));
    b.className = "btn-primary pm-mode";
    total = parseInt(b.dataset.m, 10) * 60; left = total; draw();
  }));
  win.querySelector("#pm-toggle").addEventListener("click", (e) => {
    running = !running;
    e.target.textContent = running ? "⏸ Pause" : "▶ Resume";
  });
  win.querySelector("#pm-reset").addEventListener("click", () => {
    running = false; left = total; win.querySelector("#pm-toggle").textContent = "▶ Start Focus"; draw();
  });
  const t = setInterval(() => {
    if (!document.body.contains(win)) { clearInterval(t); return; }
    if (!running) return;
    if (--left <= 0) {
      running = false; left = 0; sessions++;
      win.querySelector("#pm-toggle").textContent = "▶ Start Focus";
      win.querySelector("#pm-sessions").textContent = `Completed Focus Sessions: ${sessions}`;
    }
    draw();
  }, 1000);
  win._cleanup = () => clearInterval(t);
}

function openConverterApp() {
  const win = createWindow("converter", "Nova Unit & Base Converter", 600, 440, 340, 100, `
    <div style="display:flex;flex-direction:column;height:100%;padding:20px;gap:14px">
      <div style="font-size:20px;font-weight:800">⇄ Universal Unit &amp; Base Converter</div>
      <div style="display:flex;gap:10px">
        <select id="cv-cat" style="padding:8px 12px;border:1px solid #94A3B8;border-radius:8px;font-size:14px">
          <option value="len">Length (m / km / mi / ft)</option>
          <option value="data">Data Storage (B / KB / MB / GB / TB)</option>
          <option value="temp">Temperature (°C / °F / K)</option>
          <option value="base">Programmer Base (Dec / Hex / Bin)</option>
        </select>
        <input id="cv-val" value="100" style="flex:1;padding:8px 12px;border:1px solid #94A3B8;border-radius:8px;font-size:15px" />
      </div>
      <div id="cv-out" style="flex:1;display:grid;grid-template-columns:repeat(2,1fr);gap:10px;align-content:start"></div>
    </div>
  `);
  const update = () => {
    const cat = win.querySelector("#cv-cat").value;
    const raw = win.querySelector("#cv-val").value.trim();
    const n = parseFloat(raw) || 0;
    let rows = [];
    if (cat === "len") rows = [["Meters (m)", n], ["Kilometers (km)", (n / 1000).toFixed(4)], ["Miles (mi)", (n / 1609.344).toFixed(4)], ["Feet (ft)", (n * 3.28084).toFixed(3)]];
    else if (cat === "data") rows = [["Bytes", n * 1048576], ["Megabytes (MB)", n], ["Gigabytes (GB)", (n / 1024).toFixed(4)], ["Terabytes (TB)", (n / 1048576).toFixed(6)]];
    else if (cat === "temp") rows = [["Celsius (°C)", n], ["Fahrenheit (°F)", (n * 9 / 5 + 32).toFixed(2)], ["Kelvin (K)", (n + 273.15).toFixed(2)]];
    else {
      const iv = parseInt(raw, 10) || 0;
      rows = [["Decimal", iv.toString(10)], ["Hexadecimal", "0x" + iv.toString(16).toUpperCase()], ["Binary", "0b" + iv.toString(2)], ["Octal", "0o" + iv.toString(8)]];
    }
    win.querySelector("#cv-out").innerHTML = rows.map(([k, v]) => `<div style="padding:12px;border-radius:10px;background:rgba(148,163,184,0.14)"><div style="font-size:12px;color:#64748B">${k}</div><div style="font-size:18px;font-weight:800;margin-top:4px;word-break:break-all">${v}</div></div>`).join("");
  };
  win.querySelector("#cv-cat").addEventListener("change", update);
  win.querySelector("#cv-val").addEventListener("input", update);
  update();
}

function openTicTacToeApp() {
  const win = createWindow("tictactoe", "Nova Tic-Tac-Toe AI", 420, 490, 410, 85, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:12px;align-items:center">
      <div style="width:100%;display:flex;justify-content:space-between;align-items:center">
        <span id="ttt-msg" style="font-size:16px;font-weight:800">Your Turn (X)</span>
        <div style="display:flex;gap:8px">
          <button id="ttt-mode" class="btn-secondary">vs AI</button>
          <button id="ttt-rst" class="btn-primary">New Game</button>
        </div>
      </div>
      <div id="ttt-grid" style="display:grid;grid-template-columns:repeat(3,104px);gap:10px;margin-top:8px"></div>
    </div>
  `);
  let board = Array(9).fill(""), turn = "X", vsAi = true, done = false;
  const wins = [[0,1,2],[3,4,5],[6,7,8],[0,3,6],[1,4,7],[2,5,8],[0,4,8],[2,4,6]];
  const checkWin = (b) => { for (const [a,c,d] of wins) if (b[a] && b[a] === b[c] && b[a] === b[d]) return b[a]; return b.includes("") ? null : "Draw"; };
  const bestMove = (b) => {
    const mm = (cur, isMax) => {
      const w = checkWin(cur);
      if (w === "O") return 10; if (w === "X") return -10; if (w === "Draw") return 0;
      let best = isMax ? -99 : 99;
      for (let i = 0; i < 9; i++) if (!cur[i]) {
        cur[i] = isMax ? "O" : "X";
        const v = mm(cur, !isMax);
        cur[i] = "";
        best = isMax ? Math.max(best, v) : Math.min(best, v);
      }
      return best;
    };
    let bestV = -99, mv = -1;
    for (let i = 0; i < 9; i++) if (!b[i]) {
      b[i] = "O"; const v = mm(b, false); b[i] = "";
      if (v > bestV) { bestV = v; mv = i; }
    }
    return mv;
  };
  const render = () => {
    const g = win.querySelector("#ttt-grid"); g.innerHTML = "";
    const w = checkWin(board);
    if (w) { done = true; win.querySelector("#ttt-msg").textContent = w === "Draw" ? "🤝 Draw!" : `🏆 ${w} Wins!`; }
    else win.querySelector("#ttt-msg").textContent = vsAi ? "Your Turn (X)" : `Turn: ${turn}`;
    board.forEach((v, i) => {
      const btn = document.createElement("button");
      btn.style.cssText = "height:104px;border:none;border-radius:14px;font-size:42px;font-weight:900;cursor:pointer;background:rgba(148,163,184,0.18);color:" + (v === "X" ? "#2563EB" : "#EF4444");
      btn.textContent = v;
      btn.addEventListener("click", () => {
        if (done || board[i]) return;
        board[i] = turn;
        if (!checkWin(board)) {
          if (vsAi) { const ai = bestMove(board); if (ai >= 0) board[ai] = "O"; }
          else turn = turn === "X" ? "O" : "X";
        }
        render();
      });
      g.appendChild(btn);
    });
  };
  win.querySelector("#ttt-mode").addEventListener("click", (e) => { vsAi = !vsAi; e.target.textContent = vsAi ? "vs AI" : "2 Players"; board = Array(9).fill(""); turn = "X"; done = false; render(); });
  win.querySelector("#ttt-rst").addEventListener("click", () => { board = Array(9).fill(""); turn = "X"; done = false; render(); });
  render();
}

function openDevToolsApp() {
  const win = createWindow("devtools", "Nova JSON, Base64 & Hash Studio", 720, 520, 290, 80, `
    <div style="display:flex;flex-direction:column;height:100%;padding:16px;gap:10px">
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button id="dt-json-fmt" class="btn-primary">Format JSON</button>
        <button id="dt-json-min" class="btn-secondary">Minify JSON</button>
        <button id="dt-b64-enc" class="btn-secondary">Base64 Encode</button>
        <button id="dt-b64-dec" class="btn-secondary">Base64 Decode</button>
        <button id="dt-sha256" class="btn-secondary">SHA-256 Hash</button>
      </div>
      <textarea id="dt-in" style="flex:1;padding:12px;border:1px solid #94A3B8;border-radius:8px;font-family:monospace;font-size:13.5px" placeholder="Paste JSON or text here...">{"nova_os":"2.00 Beta 3","build":27200,"ethernet":"instant"}</textarea>
      <textarea id="dt-out" readonly style="flex:1;padding:12px;border:1px solid #94A3B8;border-radius:8px;font-family:monospace;font-size:13.5px;background:#0F172A;color:#38BDF8" placeholder="Output..."></textarea>
    </div>
  `);
  const inp = win.querySelector("#dt-in"), out = win.querySelector("#dt-out");
  win.querySelector("#dt-json-fmt").addEventListener("click", () => { try { out.value = JSON.stringify(JSON.parse(inp.value), null, 2); } catch (e) { out.value = "Invalid JSON: " + e.message; } });
  win.querySelector("#dt-json-min").addEventListener("click", () => { try { out.value = JSON.stringify(JSON.parse(inp.value)); } catch (e) { out.value = "Invalid JSON: " + e.message; } });
  win.querySelector("#dt-b64-enc").addEventListener("click", () => { try { out.value = btoa(unescape(encodeURIComponent(inp.value))); } catch (e) { out.value = e.message; } });
  win.querySelector("#dt-b64-dec").addEventListener("click", () => { try { out.value = decodeURIComponent(escape(atob(inp.value.trim()))); } catch (e) { out.value = "Invalid Base64: " + e.message; } });
  win.querySelector("#dt-sha256").addEventListener("click", async () => {
    try {
      const buf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(inp.value));
      out.value = Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, "0")).join("");
    } catch (e) { out.value = String(e); }
  });
}


// ============================================================================
// 13. BETA 4 NEW APPS (5 Home Apps + Markdown + Color Studio + QR Lab)
// ============================================================================
function openJournalApp() {
  const win = createWindow("journal", "Personal Journal", 680, 500, 310, 85, `
    <div style="display:flex;flex-direction:column;height:100%;padding:16px;gap:12px">
      <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
        <input id="jr-title" placeholder="Entry title..." style="flex:1;padding:8px 12px;border:1px solid #94A3B8;border-radius:8px;font-size:14px" />
        <select id="jr-mood" style="padding:8px;border:1px solid #94A3B8;border-radius:8px;font-size:14px">
          <option>😊 Happy</option><option>🚀 Productive</option><option>😌 Calm</option><option>💡 Inspired</option>
        </select>
        <button id="jr-add" class="btn-primary">Save Entry</button>
      </div>
      <textarea id="jr-body" placeholder="Write today's thoughts..." style="height:120px;padding:12px;border:1px solid #94A3B8;border-radius:8px;font-size:14px;resize:none"></textarea>
      <div id="jr-list" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:8px"></div>
    </div>
  `);
  let entries = [];
  const render = () => {
    const list = win.querySelector("#jr-list");
    list.innerHTML = entries.length ? "" : `<div style="color:#64748B;font-size:13.5px">No journal entries yet.</div>`;
    entries.forEach((en, idx) => {
      const row = document.createElement("div");
      row.style.cssText = "padding:12px 14px;border-radius:10px;background:rgba(148,163,184,0.14)";
      row.innerHTML = `<div style="display:flex;justify-content:space-between"><b>${escapeHtml(en.mood)} ${escapeHtml(en.title)}</b><span style="font-size:12px;color:#64748B">${escapeHtml(en.date)} <button data-del="${idx}" class="btn-small">✕</button></span></div><div style="font-size:13.5px;margin-top:6px;white-space:pre-wrap">${escapeHtml(en.text)}</div>`;
      row.querySelector(`[data-del="${idx}"]`).addEventListener("click", () => { entries.splice(idx, 1); save(); render(); });
      list.appendChild(row);
    });
  };
  const save = () => fetch("/api/fs/write", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ path: "Documents/journal.json", content: JSON.stringify(entries) }) }).catch(() => {});
  fetch("/api/fs/read?path=Documents/journal.json").then((r) => r.json()).then((d) => { if (d.content) { entries = JSON.parse(d.content); render(); } }).catch(render);
  win.querySelector("#jr-add").addEventListener("click", () => {
    const title = win.querySelector("#jr-title").value.trim() || "Daily Note";
    const text = win.querySelector("#jr-body").value.trim();
    if (!text) return;
    entries.unshift({ title, text, mood: win.querySelector("#jr-mood").value, date: new Date().toLocaleDateString() });
    win.querySelector("#jr-title").value = ""; win.querySelector("#jr-body").value = "";
    save(); render();
  });
  render();
}

function openRecorderApp() {
  const win = createWindow("recorder", "Voice & Tone Recorder", 560, 420, 360, 100, `
    <div style="display:flex;flex-direction:column;height:100%;padding:20px;gap:14px;align-items:center;justify-content:center">
      <div style="font-size:20px;font-weight:800">🎙 Nova Voice &amp; Tone Recorder</div>
      <div id="rec-timer" style="font-size:40px;font-weight:800;font-family:monospace;color:#E11D48">00:00</div>
      <div style="display:flex;gap:10px">
        <button id="rec-start" class="btn-primary">● Record Memo</button>
        <button id="rec-stop" class="btn-secondary" disabled>■ Stop</button>
        <button id="rec-play" class="btn-secondary">▶ Play Tone Clip</button>
      </div>
      <div id="rec-status" style="font-size:13px;color:#64748B">Ready (records via WebAudio / Microphone into Music/)</div>
    </div>
  `);
  let secs = 0, tmr = null, recorder = null, chunks = [];
  const fmt = (s) => `${String(Math.floor(s / 60)).padStart(2, "0")}:${String(s % 60).padStart(2, "0")}`;
  win.querySelector("#rec-start").addEventListener("click", async () => {
    secs = 0; win.querySelector("#rec-timer").textContent = "00:00";
    win.querySelector("#rec-start").disabled = true; win.querySelector("#rec-stop").disabled = false;
    tmr = setInterval(() => { secs++; win.querySelector("#rec-timer").textContent = fmt(secs); }, 1000);
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      chunks = []; recorder = new MediaRecorder(stream);
      recorder.ondataavailable = (e) => { if (e.data.size) chunks.push(e.data); };
      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: "audio/webm" });
        const fn = `VoiceMemo_${Date.now()}.webm`;
        fetch(`/api/fs/upload?path=${encodeURIComponent("Music/" + fn)}`, { method: "POST", body: blob }).catch(() => {});
        win.querySelector("#rec-status").textContent = `Saved Music/${fn} (${secs}s)!`;
      };
      recorder.start();
      win.querySelector("#rec-status").textContent = "Recording from microphone...";
    } catch {
      win.querySelector("#rec-status").textContent = "No mic hardware attached — timing virtual memo...";
    }
  });
  win.querySelector("#rec-stop").addEventListener("click", () => {
    clearInterval(tmr);
    win.querySelector("#rec-start").disabled = false; win.querySelector("#rec-stop").disabled = true;
    if (recorder && recorder.state !== "inactive") recorder.stop();
    else win.querySelector("#rec-status").textContent = `Captured ${secs}s memo session.`;
  });
  win.querySelector("#rec-play").addEventListener("click", () => {
    try {
      const ac = new (window.AudioContext || window.webkitAudioContext)();
      const o = ac.createOscillator(), g = ac.createGain();
      o.frequency.setValueAtTime(523.25, ac.currentTime);
      o.frequency.setValueAtTime(659.25, ac.currentTime + 0.15);
      g.gain.exponentialRampToValueAtTime(0.001, ac.currentTime + 0.4);
      o.connect(g); g.connect(ac.destination); o.start(); o.stop(ac.currentTime + 0.4);
    } catch {}
  });
  win._cleanup = () => clearInterval(tmr);
}

function openBudgetApp() {
  const win = createWindow("budget", "Home Budget Tracker", 680, 500, 320, 90, `
    <div style="display:flex;flex-direction:column;height:100%;padding:16px;gap:12px">
      <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:10px">
        <div style="padding:12px;border-radius:10px;background:rgba(22,163,74,0.14)"><b>Income</b><div id="bg-inc" style="font-size:20px;font-weight:800;color:#16A34A">$0.00</div></div>
        <div style="padding:12px;border-radius:10px;background:rgba(239,68,68,0.14)"><b>Expenses</b><div id="bg-exp" style="font-size:20px;font-weight:800;color:#DC2626">$0.00</div></div>
        <div style="padding:12px;border-radius:10px;background:rgba(37,99,235,0.14)"><b>Balance</b><div id="bg-bal" style="font-size:20px;font-weight:800;color:#2563EB">$0.00</div></div>
      </div>
      <div style="display:flex;gap:8px">
        <input id="bg-desc" placeholder="Item (e.g. Groceries, Paycheck)" style="flex:1;padding:8px 12px;border:1px solid #94A3B8;border-radius:8px" />
        <input id="bg-amt" type="number" step="0.01" placeholder="Amount" style="width:110px;padding:8px;border:1px solid #94A3B8;border-radius:8px" />
        <select id="bg-type" style="padding:8px;border:1px solid #94A3B8;border-radius:8px"><option value="exp">Expense (-)</option><option value="inc">Income (+)</option></select>
        <button id="bg-add" class="btn-primary">Add</button>
      </div>
      <div id="bg-list" style="flex:1;overflow-y:auto;display:flex;flex-direction:column;gap:6px"></div>
    </div>
  `);
  let rows = [{ desc: "Monthly Budget Start", amt: 2500, type: "inc" }];
  const save = () => fetch("/api/fs/write", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ path: "Documents/budget.json", content: JSON.stringify(rows) }) }).catch(() => {});
  const render = () => {
    let inc = 0, exp = 0;
    const list = win.querySelector("#bg-list"); list.innerHTML = "";
    rows.forEach((r, i) => {
      if (r.type === "inc") inc += r.amt; else exp += r.amt;
      const el = document.createElement("div");
      el.style.cssText = "display:flex;justify-content:space-between;align-items:center;padding:8px 12px;border-radius:8px;background:rgba(148,163,184,0.14)";
      el.innerHTML = `<span>${escapeHtml(r.desc)}</span><span style="font-weight:700;color:${r.type === "inc" ? "#16A34A" : "#DC2626"}">${r.type === "inc" ? "+" : "-"}$${r.amt.toFixed(2)} <button data-i="${i}" class="btn-small">✕</button></span>`;
      el.querySelector(`[data-i="${i}"]`).addEventListener("click", () => { rows.splice(i, 1); save(); render(); });
      list.appendChild(el);
    });
    win.querySelector("#bg-inc").textContent = `$${inc.toFixed(2)}`;
    win.querySelector("#bg-exp").textContent = `$${exp.toFixed(2)}`;
    win.querySelector("#bg-bal").textContent = `$${(inc - exp).toFixed(2)}`;
  };
  fetch("/api/fs/read?path=Documents/budget.json").then((r) => r.json()).then((d) => { if (d.content) { rows = JSON.parse(d.content); } }).finally(render);
  win.querySelector("#bg-add").addEventListener("click", () => {
    const desc = win.querySelector("#bg-desc").value.trim() || "Item";
    const amt = Math.abs(parseFloat(win.querySelector("#bg-amt").value) || 0);
    if (!amt) return;
    rows.unshift({ desc, amt, type: win.querySelector("#bg-type").value });
    win.querySelector("#bg-desc").value = ""; win.querySelector("#bg-amt").value = "";
    save(); render();
  });
}

function openStickyNotesApp() {
  const win = createWindow("sticky", "Sticky Notes", 620, 460, 350, 95, `
    <div style="display:flex;flex-direction:column;height:100%;padding:16px;gap:12px">
      <div style="display:flex;gap:8px;align-items:center">
        <button id="sn-add-y" class="btn-primary" style="background:#CA8A04">+ Yellow Note</button>
        <button id="sn-add-b" class="btn-primary">+ Blue Note</button>
        <button id="sn-add-g" class="btn-primary" style="background:#16A34A">+ Green Note</button>
      </div>
      <div id="sn-grid" style="flex:1;overflow-y:auto;display:grid;grid-template-columns:repeat(auto-fill,minmax(175px,1fr));gap:10px;align-content:start"></div>
    </div>
  `);
  let notes = [{ color: "#FEF08A", text: "Welcome to Nova OS 2 Home Sticky Notes!" }];
  const save = () => fetch("/api/fs/write", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ path: "Documents/sticky_notes.json", content: JSON.stringify(notes) }) }).catch(() => {});
  const render = () => {
    const g = win.querySelector("#sn-grid"); g.innerHTML = "";
    notes.forEach((n, i) => {
      const card = document.createElement("div");
      card.style.cssText = `background:${n.color};color:#0F172A;border-radius:10px;padding:10px;display:flex;flex-direction:column;gap:6px;min-height:130px`;
      card.innerHTML = `<div style="display:flex;justify-content:flex-end"><button data-i="${i}" style="border:none;background:transparent;cursor:pointer;font-weight:800">✕</button></div><textarea style="flex:1;border:none;background:transparent;resize:none;outline:none;font-size:13.5px;color:#0F172A">${escapeHtml(n.text)}</textarea>`;
      card.querySelector("textarea").addEventListener("input", (e) => { n.text = e.target.value; save(); });
      card.querySelector("button").addEventListener("click", () => { notes.splice(i, 1); save(); render(); });
      g.appendChild(card);
    });
  };
  fetch("/api/fs/read?path=Documents/sticky_notes.json").then((r) => r.json()).then((d) => { if (d.content) notes = JSON.parse(d.content); }).finally(render);
  win.querySelector("#sn-add-y").addEventListener("click", () => { notes.push({ color: "#FEF08A", text: "" }); save(); render(); });
  win.querySelector("#sn-add-b").addEventListener("click", () => { notes.push({ color: "#BFDBFE", text: "" }); save(); render(); });
  win.querySelector("#sn-add-g").addEventListener("click", () => { notes.push({ color: "#BBF7D0", text: "" }); save(); render(); });
}

function openMemoryGame() {
  const win = createWindow("memory", "Memory Match", 480, 520, 390, 80, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:12px;align-items:center">
      <div style="width:100%;display:flex;justify-content:space-between;align-items:center">
        <span id="mm-stats" style="font-weight:800;font-size:15px">Moves: 0 | Pairs: 0/8</span>
        <button id="mm-rst" class="btn-primary">New Game</button>
      </div>
      <div id="mm-grid" style="display:grid;grid-template-columns:repeat(4,86px);gap:10px;margin-top:6px"></div>
    </div>
  `);
  const syms = ["🚀","🌟","🎵","🔥","🦊","🍀","💎","🎮"];
  let cards = [], open = [], matched = new Set(), moves = 0, lock = false;
  const setup = () => {
    cards = [...syms, ...syms].sort(() => Math.random() - 0.5);
    open = []; matched = new Set(); moves = 0; lock = false; render();
  };
  const render = () => {
    win.querySelector("#mm-stats").textContent = matched.size === 16 ? `🏆 Won in ${moves} moves!` : `Moves: ${moves} | Pairs: ${matched.size / 2}/8`;
    const g = win.querySelector("#mm-grid"); g.innerHTML = "";
    cards.forEach((s, i) => {
      const flipped = open.includes(i) || matched.has(i);
      const b = document.createElement("button");
      b.style.cssText = `height:86px;border:none;border-radius:12px;font-size:34px;cursor:pointer;background:${flipped ? "#DBEAFE" : "#1E293B"};color:#FFF`;
      b.textContent = flipped ? s : "?";
      b.addEventListener("click", () => {
        if (lock || flipped) return;
        open.push(i); render();
        if (open.length === 2) {
          moves++; lock = true;
          const [a, c] = open;
          if (cards[a] === cards[c]) { matched.add(a); matched.add(c); open = []; lock = false; render(); }
          else setTimeout(() => { open = []; lock = false; render(); }, 650);
        }
      });
      g.appendChild(b);
    });
  };
  win.querySelector("#mm-rst").addEventListener("click", setup);
  setup();
}

function openMarkdownApp() {
  const win = createWindow("markdown", "Markdown Studio", 760, 520, 280, 80, `
    <div style="display:flex;flex-direction:column;height:100%">
      <div style="padding:8px 14px;display:flex;gap:8px;border-bottom:1px solid rgba(148,163,184,0.28)">
        <input id="md-file" value="Documents/README.md" style="flex:1;padding:6px 10px;border:1px solid #94A3B8;border-radius:6px" />
        <button id="md-save" class="btn-primary">Save</button>
      </div>
      <div style="flex:1;display:grid;grid-template-columns:1fr 1fr;overflow:hidden">
        <textarea id="md-in" style="padding:14px;border:none;border-right:1px solid rgba(148,163,184,0.28);resize:none;font-family:monospace;font-size:14px"># Nova OS 2.00 Beta 4\n\n- Instant IPv4 Ethernet\n- **5 New Home Apps** + 10 Pro Bonus Apps\n- Local Wallpaper & Activation Ready</textarea>
        <div id="md-out" style="padding:16px;overflow-y:auto;line-height:1.5"></div>
      </div>
    </div>
  `);
  const render = () => {
    const raw = win.querySelector("#md-in").value;
    win.querySelector("#md-out").innerHTML = escapeHtml(raw)
      .replace(/^### (.*)$/gm, "<h3>$1</h3>").replace(/^## (.*)$/gm, "<h2>$1</h2>").replace(/^# (.*)$/gm, "<h1>$1</h1>")
      .replace(/\*\*(.*?)\*\*/g, "<b>$1</b>").replace(/^- (.*)$/gm, "• $1<br>").replace(/\n/g, "<br>");
  };
  win.querySelector("#md-in").addEventListener("input", render);
  win.querySelector("#md-save").addEventListener("click", () => {
    fetch("/api/fs/write", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ path: win.querySelector("#md-file").value, content: win.querySelector("#md-in").value }) });
  });
  render();
}

function openColorStudioApp() {
  const win = createWindow("colorstudio", "Color & Gradient Studio", 560, 440, 350, 95, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:14px">
      <div id="cs-prev" style="height:140px;border-radius:14px;display:flex;align-items:center;justify-content:center;color:#FFF;font-weight:800;font-size:20px">Gradient Preview</div>
      <div style="display:flex;gap:12px;align-items:center">
        <label>Color 1 <input id="cs-c1" type="color" value="#2563eb" /></label>
        <label>Color 2 <input id="cs-c2" type="color" value="#7c3aed" /></label>
        <label>Angle <input id="cs-ang" type="range" min="0" max="360" value="135" /></label>
      </div>
      <input id="cs-css" readonly style="padding:10px;border:1px solid #94A3B8;border-radius:8px;font-family:monospace;font-size:13px" />
    </div>
  `);
  const upd = () => {
    const g = `linear-gradient(${win.querySelector("#cs-ang").value}deg, ${win.querySelector("#cs-c1").value}, ${win.querySelector("#cs-c2").value})`;
    win.querySelector("#cs-prev").style.background = g;
    win.querySelector("#cs-css").value = `background: ${g};`;
  };
  ["#cs-c1", "#cs-c2", "#cs-ang"].forEach((s) => win.querySelector(s).addEventListener("input", upd));
  upd();
}

function openQRLabApp() {
  const win = createWindow("qrlab", "QR / Matrix Lab", 480, 480, 380, 90, `
    <div style="display:flex;flex-direction:column;height:100%;padding:18px;gap:12px;align-items:center">
      <input id="qr-txt" value="https://github.com/aidaninvents/Nova-OS" style="width:100%;padding:8px 12px;border:1px solid #94A3B8;border-radius:8px" />
      <canvas id="qr-cv" width="260" height="260" style="background:#FFF;border:1px solid #CBD5E1;border-radius:10px"></canvas>
      <div style="font-size:12.5px;color:#64748B">Deterministic visual matrix generator</div>
    </div>
  `);
  const draw = () => {
    const s = win.querySelector("#qr-txt").value || "NovaOS";
    const cv = win.querySelector("#qr-cv"), ctx = cv.getContext("2d");
    ctx.fillStyle = "#FFF"; ctx.fillRect(0, 0, 260, 260);
    ctx.fillStyle = "#0F172A";
    const n = 21, cell = 10, off = 25;
    let h = 2166136261;
    for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
    const finder = (rx, ry) => {
      ctx.fillRect(off + rx * cell, off + ry * cell, 7 * cell, 7 * cell);
      ctx.fillStyle = "#FFF"; ctx.fillRect(off + (rx + 1) * cell, off + (ry + 1) * cell, 5 * cell, 5 * cell);
      ctx.fillStyle = "#0F172A"; ctx.fillRect(off + (rx + 2) * cell, off + (ry + 2) * cell, 3 * cell, 3 * cell);
    };
    finder(0, 0); finder(n - 7, 0); finder(0, n - 7);
    for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) {
      if ((x < 8 && y < 8) || (x >= n - 8 && y < 8) || (x < 8 && y >= n - 8)) continue;
      h = Math.imul(h ^ (x * 31 + y * 17), 16777619);
      if ((h >>> 24) & 1) ctx.fillRect(off + x * cell, off + y * cell, cell, cell);
    }
  };
  win.querySelector("#qr-txt").addEventListener("input", draw);
  draw();
}
