# Schedule Q&A · Information Extraction Workbench

An interactive demo workbench for schedule entity extraction, bidirectional source evidence inspection, and automated parsing—crafted in the **Vercel Geist Design System**.

## Highlights

- **Vercel Geist Minimalist Design**: High-contrast monochromatic palette (Dark by default, seamless Light mode), official Geist typography (`Geist Sans` & `Geist Mono`), 4px spatial rhythm, and sleek hairline borders.
- **Split-Screen Layout**:
  - **Left Pane**: Comprehensive schedule documents with chronological daily agendas (Tech Summit & Executive Delegation).
  - **Right Pane**: Targeted entity extraction fields (`Location`, `Date`, `Keynote Speaker`, `Deadline`).
- **Bidirectional Source Inspection**:
  - Focusing on an input or clicking "Locate Source" highlights the corresponding citation in the schedule text with an amber pulse glow and smoothly centers it into view.
  - Clicking any underlined entity in the document immediately focuses the corresponding form field.
- **Simulated AI Auto-Extraction**: One-click end-to-end extraction animation demonstrating streaming typewriter input and sequential evidence illumination.
- **Copy & Export**: Instant single-click formatted JSON export to clipboard.

## Quick Start

### Option 1: Direct Browser Launch
```bash
open sandboxes/schedule-qa-demo/index.html
```

### Option 2: Local HTTP Server
```bash
cd sandboxes/schedule-qa-demo
python3 -m http.server 3000
# Open http://localhost:3000
```

## Structure

```
sandboxes/schedule-qa-demo/
├── index.html   # Semantic HTML5 with Vercel Geist navigation and split workspace
├── style.css    # Vercel Geist design tokens, dark/light themes, focus rings
├── app.js       # Schedule registry, extraction logic, typewriter animations
└── README.md    # Documentation
```
