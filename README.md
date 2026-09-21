# jev-paste (Jev Paste for macOS)

<p align="center">
  <b>Inline, contextual clipboard decomposition for macOS. Powered by TypeSafe JEF.</b>
</p>

<p align="center">
  <a href="README.md">English</a> •
  <a href="README.zh-CN.md">简体中文</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2014%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Language-Swift%206-orange?style=flat-square" alt="Swift 6">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License">
  <img src="https://img.shields.io/badge/Engine-TypeSafe%20JEF-purple?style=flat-square" alt="TypeSafe JEF">
  <img src="https://img.shields.io/badge/Status-MenuBar%20Only-lightgrey?style=flat-square" alt="Menu Bar Only">
</p>

---

## What It Does

**jev-paste** brings intelligent, context-aware inline clipboard completion to macOS.

When you copy text—such as conference agendas, travel itineraries, bug reports, contact info, or multi-field messages—**jev-paste** decomposes the content into discrete semantic entities (event title, description, dates, venue/address, keynote speakers, deadlines, emails, and phone numbers).

Whenever you focus on an appropriate input field, **jev-paste** renders a clean, inline ghost hint with a `[Tab ⇥]` badge directly over the placeholder. Pressing **Tab** fills the field instantly and cleanly replaces any previous draft text. Your native system **⌘V** remains 100% untouched.

```
+-------------------------------------------------------------------------+
|  Copy text           -> JEF decomposes fields into history pool in memory|
|  Click relevant field-> Clean inline hint [Tab ⇥] covers placeholder    |
|  Press Tab           -> Commits matched text & replaces existing draft   |
|  Press ⌘V or Type    -> Native paste works untouched; typing hides hint  |
+-------------------------------------------------------------------------+
```

---

## Key Highlights

- **Full Clipboard History with Time-Decay Ranking**:
  Maintains all clipboard history records and uses an exponential half-life time-decay model ($T_{\text{half}} = 6\text{h}$) to rank candidates. Freshly copied content receives priority, while older relevant history remains accessible.
- **Configurable Retention Period**:
  Defaults to **1 Day (24 hours)**. Easily adjustable in Preferences: 1 Hour, 12 Hours, 1 Day, 3 Days, 7 Days, 30 Days, or Keep Forever. Stored atomically in Application Support.
- **Smart Recommendation Gating (Non-Intrusive)**:
  Recognizes whether it *should* suggest before showing anything. Automatically stays silent in search bars, browser URL bars, filter fields, password/PIN inputs, and untagged generic boxes. Never spams uncalled suggestions.
- **100% Underlying Placeholder Masking**:
  Features an adaptive, solid text background that completely conceals the underlying placeholder (e.g. *Search*, *Enter address*, *iMessage*), avoiding messy overlapping text.
- **Leftmost `[Tab ⇥]` Shortcut Badge**:
  A compact `[Tab ⇥]` badge stays pinned to the start of the field, just like IDE / Copilot completions.
- **Instant Dismissal & Mouse Click-Through**:
  Typing any character, backspacing, or pressing Escape dismisses the hint in 0ms. Mouse events pass straight through so you can click anywhere to position the cursor.
- **Interactive Web Demo Included**:
  Comes with a built-in *Schedule Q&A Information Extraction Workbench* in `demo/`, built with Vercel Geist design aesthetics to test entity extraction in a real browser DOM.
- **Menu Bar Resident (Zero Dock Clutter)**:
  Runs cleanly in the menu bar with `LSUIElement = true`. Does not occupy Dock space.
- **Stable Code Signature**:
  Uses stable designated requirement code signing (`identifier "ai.typesafe.jev-paste"`), so Accessibility permissions survive rebuilds and upgrades without prompting for passwords.

---

## How It Works

```
System Clipboard Copy (⌘C)
       │
       ▼
[ClipboardMonitor]
       │ (Persists to ClipboardHistoryManager & Disk)
       ├─────────────────────────────────┐
       ▼                                 ▼
[LocalHeuristicEngine]          [TypeSafe JEF Engine]
 (spans & field extraction)     (background AI calibration)
       │                                 │
       └──────────────┬──────────────────┘
                      ▼
            [Time-Decay Ranker]
                      │
   User focuses input in any Mac app / browser
                      │
                      ▼
              [AXFocusMonitor]
       (Filters non-text roles, checks isSettable)
                      │
                      ▼
             [shouldRecommend?]
       (Blocks search, password, & untagged fields)
                      │
                      ▼
           [GhostOverlayController]
       (Solid-backed [Tab ⇥] inline overlay)
                      │
           User presses Tab key
                      │
                      ▼
             [TabKeyInterceptor]
       (Replaces text cleanly via Accessibility)
```

---

## Installation & Quick Start

### Requirements
- macOS 14.0 or later (Apple Silicon & Intel)
- Xcode Command Line Tools (`xcode-select --install`)

### Build & Install to `/Applications`

```bash
# Clone the repository
git clone https://github.com/Anson-gzy/jev-paste.git
cd jev-paste

# Run automated test suite (42/42 tests)
make test

# Build and install directly to /Applications/jev-paste.app
make install
```

### Granting Accessibility Permission
On first launch, macOS will display a prompt asking for **Accessibility** permission:
1. Click **Open System Settings**.
2. Toggle the switch next to **jev-paste**.
3. Return to **jev-paste**—it detects the grant automatically without requiring an app restart.

---

## Preferences & Settings

Access the control panel from the menu bar item or press **⌘O**:

- **Clipboard History**: Configure retention period (1 Hour to Forever), inspect stored item count, or clear history with one click.
- **Language**: Toggle between **English** (default) and **简体中文** in real time.
- **TypeSafe JEF API**: Store your API key securely in macOS Keychain (`ai.typesafe.smartpaste`) for cloud-assisted semantic calibration.
- **Check Updates**: Click **Check Updates** in the sidebar to fetch latest GitHub releases.

---

## Interactive Web Demo

Launch the built-in Schedule Extraction Demo:
1. Open the **jev-paste** console -> switch to **Web Demo** in the sidebar.
2. Click **Open Demo in Browser** (launches `demo/index.html`).
3. Copy the sample schedule on the left and click the 4 question fields on the right to experience 0ms Tab-filling.

---

## License

This project is licensed under the [MIT License](LICENSE).
