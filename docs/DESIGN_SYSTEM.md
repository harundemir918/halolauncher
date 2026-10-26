# Halo design system

This is the source of truth for the Halo look, taken from `design/`. The PNGs in `design/screens/` are the visual reference. The `.dc.html` files in `design/source/` hold the exact numbers as inline styles. If this document and the source files disagree, the source files win. Fix this document when that happens.

All sizes are logical pixels on the 390 × 844 reference frame. The PNG exports are @2x.

## 1. Principles

The design language sheet (`language.png`) states three refusals and four rules.

**No grid · No glass · No dock.**

| # | Rule | What it means in code |
|---|---|---|
| 01 | **Arc, not grid** | Apps sit on an arc at the bottom of Home, in thumb reach. The top of the screen is for what matters now: the next event, an urgent message. Never build an icon grid. |
| 02 | **Stream, not stack** | Notifications form one timeline with time as the spine. Halo puts a summary card at the top ("3 need you."), and the user decides what to do. Never build stacked or grouped notification cards. |
| 03 | **Controls look like controls** | Use square-knob switches, ring dials and slats. Never build a grid of toggle tiles. |
| 04 | **Solid, with one signal** | No blur, no translucency and no backdrop filters. Volt is the only accent, and it means *on, active or yours*. |

## 2. Color

| Token | Hex | Role |
|---|---|---|
| `carbon` | `#0C0C0B` | Ground. Screen background and text on Volt. |
| `surface` | `#181816` | Solid cards, slats, buttons and dial plates |
| `bone` | `#F2F0E8` | Primary text and the "Yes" button fill |
| `boneDim` | `#D8D6CC` | Secondary body text (notification bodies) |
| `ash` | `#A09E94` | Mono labels, metadata, inactive text |
| `volt` | `#D6FF3F` | Signal: on, active, current, yours, primary action |
| `flare` | `#FF5B2E` | Unread and alert only |
| `voltLine` | `rgba(214,255,63,0.55)` | Border of the focused slat in Recents |

**Hairlines and borders** are white at low alpha. Use the named steps below instead of making up new ones:

| Token | Value | Typical use |
|---|---|---|
| `line05` | `rgba(255,255,255,0.05)` | Faintest decoration |
| `line07` | `rgba(255,255,255,0.07)` | Background concentric rings (Lock) |
| `line08` | `rgba(255,255,255,0.08)` | Card and slat borders |
| `line10` | `rgba(255,255,255,0.10)` | Row dividers, battery bar track, lock card borders |
| `line12` | `rgba(255,255,255,0.12)` | App circle borders |
| `line14` | `rgba(255,255,255,0.14)` | Media strip progress track |
| `line16` | `rgba(255,255,255,0.16)` | Arc guide ring (Home) |
| `line18` | `rgba(255,255,255,0.18)` | Slider track |
| `line22` | `rgba(255,255,255,0.22)` | Outline (secondary) button borders |
| `line35` | `rgba(255,255,255,0.35)` | Off switch track border |

Rules:
- Volt is used once per area with one meaning. If something is not on, active, current or primary, it must not be Volt.
- Flare is never decoration. It always stands for an unread or alert state.
- Text on Volt is always `carbon`.
- Dark is the default appearance. A light appearance is designed too: see §2b. How `Auto` chooses is still open (D-013).

## 2b. Light appearance

Source: `design/source/*Light.dc.html`, `design/source/Themes.dc.html` and `design/screens/*_light.png` (decided in D-013). The sheet's own summary: **same layout, same shapes, swapped tokens**, and still no blur, gradients or shadows. The light sources are the exact numbers; this section is the map.

**Tokens**

| Role | Dark | Light |
|---|---|---|
| `ground` (was `carbon`) | `#0C0C0B` | `#F3F1E9` |
| `surface` | `#181816` | `#FBFAF5` |
| `well` (Recents focused slat) | `#121211` | `#EBE8DC` |
| `text` (was `bone`) | `#F2F0E8` | `#14140F` (ink) |
| `textDim` (was `boneDim`) | `#D8D6CC` | `#3D3C35` |
| `muted` (was `ash`) | `#A09E94` | `#6A685D` |
| `signalFill` (Volt) | `#D6FF3F` | `#D6FF3F` **plus a 1 px ink edge** |
| `signalLine` | `#D6FF3F` | `#5F8A00` (Moss) |
| `signalText` | `#D6FF3F` | `#4A6700` (Olive) |
| `flare` | `#FF5B2E` | `#E8481A` |
| text on a signal fill | `#0C0C0B` | `#14140F` |

**Signal splits in three.** In dark one color (Volt) does every job. In light, Volt is too bright to read on paper, so it stays only as a *fill* (with an ink edge), lines and strokes use Moss, and text uses Olive. "Volt means on, active or yours" still holds as a meaning; the three tokens are how it is drawn.

**Hairlines are ink at an alpha, and the alpha depends on the role**, not on one step per token. As measured in the sources:

| Role | Dark (white) | Light (ink `#14140F`) |
|---|---|---|
| Card, slat and toggle-row borders | 0.08 | 0.12 |
| Row dividers and rules | 0.10 | 0.12 |
| Battery-line track, dial track | 0.10 | 0.10 |
| Shortcut squares, command field | 0.10 | 0.14 |
| App circle borders | 0.12 | 0.16 |
| Outline buttons, avatar, Ask Halo, unselected segments | 0.22 / 0.20 | 0.30 |
| Off-switch border | 0.35 | 0.40 |
| Dial ticks | 0.20 | 0.28 |
| Empty battery cells | 0.12 | 0.12 |
| Media progress track | 0.14 | 0.14 |
| Slider track | 0.18 | 0.20 |
| Home arc guide ring | 0.16 | 0.18 |
| Home background rings | 0.05 | 0.07 |
| Lock background rings | 0.07 | 0.09 |
| Lock hold-ring track | 0.16 | 0.16 |

**Components that change shape or role, not just color**

| Component | Light |
|---|---|
| Volt fills: Lock time tile, primary button, selected segment, play button, Stream summary card, Maps "Start" | Volt fill, 1 px ink edge, ink text. The focused Home app has a 1.5 px edge. |
| Switch | Inverts. **On** is an ink track with a Volt knob; **off** is a 0.40 ink outline with a muted knob. |
| Slider | Ink fill; the knob is Volt with a 1 px ink edge. |
| Ring dial | Auto arc is Moss, manual arc is ink. |
| Media strip | Pause and play glyph ink; progress fill ink. |
| Battery line and cells, toggle-row left bar, Lock/Home arc segment, hold-ring arc, route line, timeline "current" dot, kicker square | Moss (`signalLine`). |
| Kicker label, agenda current time, REPLY (and its underline), accordion number and `OPEN`, command prompt | Olive (`signalText`). |
| `4 NEW` chip | Ink fill, Volt text. |
| Inline "Yes" button | Ink fill, ground text. |
| Hold-ring center dot | Ink. |
| Recents focused slat | 2 px ink border on the `well` fill. |
| Accordion open row | 2 px ink top rule. |
| Unread badge ring (on the focused app) | Ground color. |
| Maps destination pin | Flare with a ground-colored center. |

Flare is unchanged in meaning (unread or alert) and only shifts to `#E8481A`.

## 3. Typography

Two families, both SIL OFL, so they can be bundled in the system image:

- **Bricolage Grotesque** (400, 500, 700, 800) is the voice: headlines, titles and body text.
- **DM Mono** (400, 500) is for labels, counts and times. Labels are UPPERCASE with positive tracking.

| Style | Family | Size | Weight | Tracking | Seen in |
|---|---|---|---|---|---|
| `clockHero` | Bricolage | 196 | 800 | -0.05em, line-height 0.8 | Lock clock (hours solid, minutes outlined) |
| `display` | Bricolage | 92 | 800 | -0.045em | Stream summary "3 need you." (scaled) |
| `screenTitle` | Bricolage | 36–44 | 800 | -0.04em | "Switchboard", "Stream", "System", "Recent" |
| `headline` | Bricolage | 34–42 | 800 | -0.04em | Home "Design review in 19 min" |
| `dialValue` | Bricolage | 38 | 800 | -0.04em | Switchboard 64 / 42 |
| `sectionTitle` | Bricolage | 24 | 700 | -0.03em | System rows "Connections", "Display" |
| `title` | Bricolage | 17–19 | 700 | -0.02em | Agenda rows, toggle row names |
| `body` | Bricolage | 16 | 500 | 0, line-height 1.3 | Notification text |
| `rowTitle` | Bricolage | 16 | 600 | 0 | Toggle row names |
| `button` | Bricolage | 15 | 700 (secondary 500) | 0 | Navigate, Open notes, Start. Small buttons: 13 |
| `label` | DM Mono | 11 | 400–500 | 0.08–0.16em, UPPERCASE | NOW, TODAY, ROOM 3, MAPS |
| `labelSmall` | DM Mono | 10–10.5 | 400 | 0.08–0.1em, UPPERCASE | Dial captions, tick legends |
| `monoValue` | DM Mono | 12–14 | 500 | 0.06em | Times "10:00", counts, status bar |
| `kicker` | DM Mono | 11 | 400 | 0.14em, UPPERCASE | NOW, TODAY |
| `caption` | DM Mono | 10.5 | 400 | 0.08em, UPPERCASE | Toggle row sub-labels (HOME-5G) |
| `segment` | DM Mono | 12 | 400 (selected 500) | 0.1em, UPPERCASE | Segmented options |

Rules:
- Times, counts, percentages and units are set in DM Mono.
- Headlines get negative tracking. Mono labels get positive tracking. Never the other way round.
- Hierarchy comes from weight and size. Don't add colors for hierarchy beyond `bone`, `boneDim` and `ash`.

## 4. Shape: "the notch"

> One big corner, three small. The notch marks the start of every block.

Blocks have a **large top-left radius** and small radii on the other three corners. The large corner grows with the block's size:

| Token | Radius (TL / TR / BR / BL) | Use |
|---|---|---|
| `notchXS` | 10 / 3 / 3 / 3 | Tiny chips |
| `notchS` | 12 / 4 / 4 / 4 | Small buttons ("Yes", "Later") |
| `notchSM` | 16 / 4 / 4 / 4 | Selected segment |
| `notchM` | 18 / 4 / 4 / 4 | Buttons, inputs, avatar |
| `notchML` | 20 / 6 / 6 / 6 | Lock shortcut squares |
| `notchL` | 22–26 / 4–6 | Medium cards |
| `notchAvatar` | 22 / 4 / 4 / 4 | Account avatar |
| `notchField` | 22 / 6 / 6 / 6 | Command field |
| `notchXL` | 28 / 6 / 6 / 6 | Large cards, dial plates, Recents slats, Stream summary, Lock time tile |
| `notchXXL` | 30 / 6 / 6 / 6 | Hero blocks (Stream summary card) |
| `radiusFlat` | 6 (all corners) | Plain rows, toggle rows |
| `radiusFlatS` | 4 (all corners) | Unselected segments, switch track |
| `radiusKnob` | 2 | Switch knobs, battery cells |

**Circles are for apps only.** App icons are 52 × 52 circles (radius 26) with a `line12` border on `surface`. The focused app grows (to about 68) and fills with Volt. Nothing else is round, except for status dots (8–9 px), the dials, and the lock "hold to open" ring.

## 5. Spacing and layout

- Reference frame: 390 × 844. Lay out for that frame and scale by width class. Don't hard-code absolute positions in production widgets.
- Screen gutter: **24 px** left and right.
- Status row: top 16 px, DM Mono 12–13. Time and date on the left (`09:41 FRI 23.10`, time in bone 500 and date in ash). Network and battery on the right (`5G · WI-FI · 82%`).
- **Battery line**: a 3 px bar across the very top of every screen. The `line10` track is filled with Volt to the battery percentage. This is Halo's battery indicator, so don't add a separate battery icon.
- List rows: 13–16 px vertical padding with `line10` hairline dividers.
- Common gaps: 4, 6, 8, 12, 14, 18 px.
- Touch targets are at least 44 × 44.

## 6. Components

| Component | Spec |
|---|---|
| **Switch** | 44 × 24 track, radius 4. **On**: Volt track with a 16 × 16 carbon square knob (radius 2) on the right. **Off**: transparent track with a `line35` border and an ash square knob on the left. |
| **Toggle row** | `surface` row, radius 6, height about 52, `line08` border. When on, a 3 px Volt bar runs down the left edge. Title in Bricolage 600 (`rowTitle`, 16), sub-label in DM Mono ash (`HOME-5G`, `2 DEVICES`, `WORK · UNTIL 11:00`). |
| **Ring dial** | Plate is `surface` with `notchXL`, 132 × 200 per half. A tick ring of short `line` ticks surrounds a track ring and a value arc. Volt means auto/active. Bone means a manual level. The value sits in the center in `dialValue` with a mono caption under it (`LIGHT`, `SOUND`), and a mono footer below (`AUTO · ON`, `MEDIA · RING`). The user drags around the ring to set the value. |
| **Slat** | Tall vertical card, `surface`, `notchXL`, `line08` border. Collapsed slats are 36 wide with the icon at the top and a rotated mono label. The focused slat expands and shows the app's live content with a `voltLine` border. Flick up to close. |
| **Segmented control** | Equal options, height about 40, radius 4. Selected: Volt fill with carbon mono text and `notchSM`. Others: `line22` outline. |
| **Slider** | 2 px track. Volt fill up to the value, `line18` after it. Knob is a Volt rounded rectangle 14 × 20, radius 3. Value in mono on the right of the label row. |
| **Primary button** | Volt fill, carbon text, `notchM`, height 44, 20 px side padding. The small inline buttons ("Yes" in bone, "Later" outlined) are 32 high, `notchS`, 13 px. |
| **Secondary button** | Transparent, `line22` border, bone text, `notchM`. |
| **Command field** | `surface`, `notchM`, `line10` border. A Volt `>` prompt and a mono placeholder ("find a setting") with a solid Volt block cursor. |
| **Time tile + event card** | Volt square tile (`notchML`) with the time in carbon mono, next to a `surface` card that has a mono kicker (`NEXT · IN 19 MIN`) and a Bricolage title. |
| **Inline action card** | `surface`, `notchM` or `notchL`. Flare dot, mono sender and age, Bricolage question, plus small "Yes" (bone fill) and "Later" (outline) buttons. |
| **Timeline item** | 1 px `line10` spine on the left. Node is a 9 px dot: Volt for current, Flare for alert, a hollow 1.5 px ash ring for read. Mono kicker (`MESSAGES · ELIF`) with the time on the right, body below. Text actions (`REPLY` in Volt, `LATER` in ash) are underlined with a 1 px bar. |
| **Battery cells** | 10 segments, 14 high, with 4 px gaps, radius 2. Volt when filled, `line12` when empty. Partial fill is allowed on the boundary cell. |
| **Media strip** | Volt notch square play/pause button with a `surface` card holding the title, mono artist and a 3 px progress bar (bone on `line10`). |
| **Section kicker** | 8 × 8 Volt square followed by a mono label (`NOW`, `COLOR`, `MESSAGES`). |

Icons: 24 × 24 grid, 1.6–1.8 px stroke, round caps and joins, outline only, colored `bone` (carbon on Volt). Source paths are in `Home.dc.html`.

## 7. Screens

| Screen | Source | Purpose and anatomy |
|---|---|---|
| **Lock** | `Main.dc.html` / `lock.png` | `LOCKED` status, giant clock (hours solid bone, minutes outlined), mono date, the next event as a time tile + card, two notification preview rows (Flare dot = unread, hollow = read). The background is concentric `line07` rings around a point at the bottom right, with one Volt arc segment. Bottom row: flashlight and camera notch squares on either side of the **hold-to-open** ring, which fills with Volt while you hold. |
| **Home ("Home Arc")** | `Home.dc.html` / `home.png` | `NOW` kicker, a headline about the most relevant thing, a context mono line, a primary and a secondary action, the `TODAY` agenda, and an inline action card for the top message. At the bottom are 7 app circles on an arc (center `195,900`, guide radius 190) with the focused app in the middle, enlarged and Volt, a short Volt arc segment, and a label (`● MESSAGES`). The **Ask Halo** button sits under the arc. Order left to right: Notes, Maps, Music, **Messages**, Camera, Web, Phone. |
| **Recents** | `Switcher.dc.html` / `recents.png` | Title `Recent` with a Volt mono count (`05`) and `CLEAR ALL`. Slats in a row: collapsed slats on either side, the focused slat in the middle showing a live app surface (Maps route with a "12 min / Start" card). Footer hint: `FLICK A SLAT UP TO CLOSE`. |
| **Switchboard** | `Control.dc.html` / `switchboard.png` | Quick controls. Two ring dials (Light 64 auto, Sound 42), toggle rows (Wi-Fi, Bluetooth, Cellular, Airplane, Focus), a media strip, and battery cells with `FULL BY 10:20`. |
| **Stream** | `Notifications.dc.html` / `stream.png` | Title with a `4 NEW` Volt chip. A Volt summary card ("HALO READ 11 THINGS FOR YOU / 3 need you." plus a numbered list), then the timeline in `NOW` and `EARLIER` sections. |
| **System** | `Settings.dc.html` / `system.png` | The Settings app. Title and avatar notch (`AS`), a command field, then numbered sections (01 Connections, 02 Display, 03 Sound, 04 Focus, 05 Privacy, 06 Battery) with a mono status on the right. The open section is marked by a Volt number, a Volt `OPEN` label and a Volt hairline, and shows its controls inline (an accordion, not a page push). |
| **Design language** | `Language.dc.html` / `language.png` | Reference sheet for tokens and rules |

## 8. Motion

The designs are static and no motion spec exists yet. Until one is written:
- Motion should feel physical and solid: no fades over blur, no parallax glass.
- Arc: apps rotate along the arc. The focused app scales up and turns Volt.
- Slats: horizontal pan changes focus. Vertical flick closes, with velocity-based dismissal.
- Dials and the hold-to-open ring: the value arc follows the finger 1:1.
- Default durations are 150–250 ms with standard easing. Respect a system "reduce motion" setting.

## 9. Implementation mapping

The design system ships as the Dart package `packages/halo_ui`:

- `HaloColors`, `HaloType`, `HaloRadii` (notch tokens), `HaloSpace` are generated or handwritten from this document.
- `HaloTheme` provides a `ThemeData` plus a `ThemeExtension` for the tokens that Material doesn't model.
- Widgets: `HaloSwitch`, `HaloToggleRow`, `HaloDial`, `HaloSlat`, `HaloSegmented`, `HaloSlider`, `HaloButton`, `HaloCommandField`, `HaloTimeline`, `HaloBatteryLine`, `HaloBatteryCells`, `HaloArc`, `HaloKicker`, `NotchBorder` (a `ShapeBorder` for the asymmetric radius).
- Fonts are bundled as assets in `halo_ui`. Don't use `google_fonts` (there is no network fetching at runtime on the device).
- Golden tests compare each shell screen with mock data against `design/screens/*.png` at 390 × 844 @2x.
