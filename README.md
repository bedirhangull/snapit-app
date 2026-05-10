# Snap It

macOS menu-bar companion that drops a **Dynamic Island**–style panel from the notch. Capture what is on screen, chat about clothing with **Google Gemini**, and request try-on style videos.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- **Screen Recording** permission (System Settings → Privacy & Security)
- **Accessibility** permission for the global shortcut (optional but recommended)

## Setup

1. Open `SnapIt.xcodeproj` in Xcode.
2. Add your Gemini API key to the run environment:
   - Xcode → **Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables**
   - Name: `GEMINI_API_KEY` — Value: your key from [Google AI Studio](https://aistudio.google.com/apikey)

Without this variable the app runs, but AI features show an error until a key is set.

## Usage

- **Control + Shift + S**: toggle the island.
- Click the notch area to open when closed.
- Choose a **body photo** once (shirt/pants framing); it is stored locally for try-on prompts.
- When the island opens, Snap It grabs a **screenshot** of the selected display and asks Gemini what clothing is visible.

## Hackathon note

Commits are intentionally staged (scaffold → island shell → Gemini features → polish).

## License

See [LICENSE](LICENSE) if present.
