# Snap It

macOS menu-bar companion that drops a **Dynamic Island**–style panel from the notch. Capture what is on screen, chat about clothing with **Google Gemini**, and request try-on style videos.

**Landing page:** <https://various-department-527207.framer.app/>

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- **Screen Recording** permission (System Settings → Privacy & Security)
- **Accessibility** permission for the global shortcut (optional but recommended)

## Setup

1. Open `SnapIt.xcodeproj` in Xcode.
2. Add your API keys to the run environment:
   - Xcode → **Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables**
   - `GEMINI_API_KEY` — your key from [Google AI Studio](https://aistudio.google.com/apikey)
   - `SERPAPI_API_KEY` — your key from [SerpApi](https://serpapi.com/manage-api-key) (powers the alternative product cards + outfit‑combo search)

Without these variables the app runs, but AI features and shopping results show an error until keys are set.

**Video (Veo)** uses long‑running operations on the Gemini API. Access varies by account/billing and model availability—if generation fails, check Google AI Studio quotas and try again.

## Usage

- **Control + Shift + S**: toggle the island (requires Accessibility permission for global shortcuts). A short system sound plays on open/close when using this shortcut.
- **Closed island**: a small **t-shirt icon** + “Snap It” shows in the notch pill so you know the app is running.
- **First run onboarding**: if no body photo is saved yet, the app opens the island shortly after launch and asks for a **full-body** reference photo (plain background, standing straight). After you pick one, it is stored locally and reused for try-on and vision prompts until you change it from the menu (**Choose Body Photo…**).
- Click the notch area or use **Open Island** from the menu to expand the panel **without** capturing the screen or calling Gemini.
- **Analysis quota**: a new screenshot and Gemini request run **only** when you open the island with **⌃⇧S** (not on every display-parameter notification or passive open). Use ⌃⇧S again after closing to refresh the capture.
- **Shopping cards**: after the Gemini analysis, the app also queries Google Shopping (via SerpApi) for a better deal on the primary item plus 2–3 complementary pieces (pants/shoes/accessory). Cards appear as horizontal strips under the chat bubble; tapping one opens the merchant page in your default browser.
- While Gemini is working, a **Thinking…** indicator appears in the island header (and a compact spinner on the closed pill).
- Screen capture + Gemini require `GEMINI_API_KEY` and **Screen Recording** permission.

## Hackathon note

Commits are intentionally staged (scaffold → island shell → Gemini features → polish).

## License

See [LICENSE](LICENSE) if present.
