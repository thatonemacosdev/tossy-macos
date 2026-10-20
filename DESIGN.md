---
version: alpha
name: Revolut-design-analysis
description: |
  Revolut's marketing surfaces pair a stark black canvas with the brand's
  cobalt-violet (`#494fdf`) and a wide accent palette of deep, fully-saturated
  product colours: teal, light-blue, deep pink, light-green, warning orange.
  The system reads as fintech-meets-product-brochure: oversized 80px-136px
  Aeonik Pro display headlines, generous whitespace, photography-led hero
  bands, and full-width product mockups (cards, phones, terminals) shown as
  hero objects inside near-black sections. Most surfaces are either black or
  off-white; pill-shaped buttons and rounded-12/20px content cards carry the
  consumer-financial-app feel without crossing into playful territory.

colors:
  primary: "#494fdf"
  primary-bright: "#4f55f1"
  primary-deep: "#3a40c4"
  on-primary: "#ffffff"
  ink: "#191c1f"
  body: "#1f2226"
  charcoal: "#3a3d40"
  mute: "#505a63"
  ash: "#5c5e60"
  stone: "#8d969e"
  faint: "#c9c9cd"
  on-dark: "#ffffff"
  on-dark-mute: "rgba(255,255,255,0.72)"
  canvas-light: "#ffffff"
  canvas-dark: "#000000"
  surface-soft: "#f4f4f4"
  surface-card: "#ffffff"
  surface-deep: "#0a0a0a"
  surface-elevated: "#16181a"
  hairline-light: "#e2e2e7"
  hairline-dark: "rgba(255,255,255,0.12)"
  hairline-strong: "#191c1f"
  divider-soft: "rgba(255,255,255,0.06)"
  accent-teal: "#00a87e"
  accent-blue-link: "#376cd5"
  accent-light-blue: "#007bc2"
  accent-light-green: "#428619"
  accent-green-text: "#006400"
  accent-yellow: "#b09000"
  accent-warning: "#ec7e00"
  accent-pink: "#e61e49"
  accent-danger: "#e23b4a"
  accent-deep-red: "#8b0000"
  accent-brown: "#936d62"
  link: "#376cd5"

typography:
  display-xxl:
    fontFamily: Aeonik Pro
    fontSize: 136px
    fontWeight: 500
    lineHeight: 1.0
    letterSpacing: -2.72px
  display-xl:
    fontFamily: Aeonik Pro
    fontSize: 80px
    fontWeight: 500
    lineHeight: 1.0
    letterSpacing: -0.8px
  display-lg:
    fontFamily: Aeonik Pro
    fontSize: 48px
    fontWeight: 500
    lineHeight: 1.21
    letterSpacing: -0.48px
  display-md:
    fontFamily: Aeonik Pro
    fontSize: 40px
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: -0.4px
  heading-lg:
    fontFamily: Aeonik Pro
    fontSize: 32px
    fontWeight: 500
    lineHeight: 1.19
    letterSpacing: -0.32px
  heading-md:
    fontFamily: Aeonik Pro
    fontSize: 24px
    fontWeight: 500
    lineHeight: 1.33
    letterSpacing: 0
  heading-sm:
    fontFamily: Aeonik Pro
    fontSize: 20px
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: 0
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: 400
    lineHeight: 1.56
    letterSpacing: -0.09px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: 0.24px
  body-md-bold:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: 0.16px
  body-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 400
    lineHeight: 1.43
  button-lg:
    fontFamily: Aeonik Pro
    fontSize: 20px
    fontWeight: 500
    lineHeight: 1.4
  button-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 600
    lineHeight: 1.5
    letterSpacing: 0.24px
  button-sm:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: 600
    lineHeight: 1.43
  caption:
    fontFamily: Inter
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
  link-emph:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: 700
    lineHeight: 1.5
    letterSpacing: 0.24px

rounded:
  none: 0px
  sm: 8px
  md: 12px
  lg: 20px
  xl: 28px
  full: 9999px

spacing:
  xxs: 4px
  xs: 6px
  sm: 8px
  md: 14px
  lg: 16px
  xl: 24px
  xxl: 32px
  xxxl: 48px
  block: 80px
  section: 88px
  band: 120px

components:
  button-primary:
    backgroundColor: "{colors.canvas-light}"
    textColor: "{colors.canvas-dark}"
    typography: "{typography.button-md}"
    rounded: "{rounded.full}"
    padding: 14px 28px
    height: 48px
  button-primary-pressed:
    backgroundColor: "{colors.faint}"
    textColor: "{colors.canvas-dark}"
    typography: "{typography.button-md}"
    rounded: "{rounded.full}"
  button-dark:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-dark}"
    typography: "{typography.button-md}"
    rounded: "{rounded.full}"
    padding: 14px 28px
    height: 48px
  button-soft:
    backgroundColor: "{colors.surface-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.button-md}"
    rounded: "{rounded.full}"
    padding: 14px 28px
    height: 48px
  button-outline-light:
    backgroundColor: "{colors.canvas-light}"
    textColor: "{colors.ink}"
    typography: "{typography.button-md}"
    rounded: "{rounded.full}"
    padding: 13px 27px
    height: 48px
  button-outline-dark:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-dark}"
    typography: "{typography.button-md}"
    rounded: "{rounded.full}"
    padding: 13px 27px
    height: 48px
  button-pill-sm:
    backgroundColor: "{colors.surface-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.full}"
    padding: 8px 16px
    height: 36px
  text-input:
    backgroundColor: "{colors.canvas-light}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.md}"
    padding: 14px 16px
    height: 56px
  hero-band-dark:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-dark}"
    typography: "{typography.display-xxl}"
    rounded: "{rounded.none}"
    padding: 88px 24px
  hero-band-photo:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-dark}"
    typography: "{typography.display-xl}"
    rounded: "{rounded.none}"
    padding: 0
  feature-card-light:
    backgroundColor: "{colors.canvas-light}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: 32px
  feature-card-dark:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-dark}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: 32px
  plan-card:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-dark}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: 32px
  plan-card-featured:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.body-md}"
    rounded: "{rounded.lg}"
    padding: 32px
  product-mockup:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-dark}"
    rounded: "{rounded.xl}"
    padding: 48px
  download-tile:
    backgroundColor: "{colors.surface-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.md}"
    padding: 12px 20px
    height: 56px
  badge-tag:
    backgroundColor: "{colors.surface-soft}"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: 4px 12px
  badge-feature:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    typography: "{typography.caption}"
    rounded: "{rounded.full}"
    padding: 4px 12px
  nav-bar:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-dark}"
    typography: "{typography.button-md}"
    rounded: "{rounded.none}"
    height: 64px
  sub-nav-pill:
    backgroundColor: "{colors.surface-elevated}"
    textColor: "{colors.on-dark}"
    typography: "{typography.button-sm}"
    rounded: "{rounded.full}"
    padding: 8px 16px
  footer:
    backgroundColor: "{colors.canvas-dark}"
    textColor: "{colors.on-dark-mute}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.none}"
    padding: 80px 24px
---

## Overview

Revolut's marketing canvas operates in a high-contrast two-mode system: a
**near-black storytelling canvas** (`{colors.canvas-dark}`: `#000000`)
that hosts hero bands, product mockups, and the planning section, alternating
with **white catalogue bands** (`{colors.canvas-light}`: `#ffffff`) that
host comparison tables, FAQ rows, and download tiles. The two modes switch
in full-bleed bands rather than soft transitions; sections transition boldly
against each other to create the magazine-spread rhythm the brand is known for.

The display typography is **Aeonik Pro at weight 500**, used at sizes from
20px to 136px. The flagship hero sits at 80-136px with `lineHeight: 1.0` and tight negative
letter-spacing. Body type is **Inter** at weight 400: open-source,
no-nonsense, paired with positive tracking (`0.24px`) on UI labels for
slightly more mechanical precision.

The brand accent is `{colors.primary}` (`#494fdf`): a saturated cobalt
violet, but it appears scarcely on marketing surfaces. The actual primary
CTA on the hero is the **white pill on black** ("Download v2.0.0"),
and the cobalt violet is reserved for featured plan cards, secondary CTAs in
white sections, and the brand glyph itself. A wide secondary palette of deep
teal, light-blue, deep-pink, light-green, warning orange, and yellow appears
inside product mockups and feature illustrations: never as button surfaces.

**Key Characteristics:**
- Two-mode canvas system: `{colors.canvas-dark}` (true black) for storytelling, `{colors.canvas-light}` (white) for browsing: switched in full-bleed bands.
- Display typography is **Aeonik Pro 500** at sizes 20-136px with tight `lineHeight: 1.0` and large negative letter-spacing on display sizes.
- The actual primary CTA is `{component.button-primary}`: a **white pill with black text**, sitting on the dark canvas as the brightest pixel. Cobalt-violet `{colors.primary}` is reserved for featured plan cards and secondary CTAs.
- Eight saturated accent colours live inside product mockups and illustrations only, never as button surfaces: teal, light-blue, deep-pink, light-green, warning orange, yellow, brown, danger red.
- All buttons are pill-shaped (`{rounded.full}`); content cards use `{rounded.lg}` (20px); inputs and small chips use `{rounded.md}` (12px).
- Photography is product-led: desktop mockups, canvas views, trimmer cards: shown full-bleed inside dark sections with no caption overlay.

## Colors

### Brand & Accent
- **Cobalt Violet** (`{colors.primary}`: `#494fdf`): the brand accent. Reserved for featured cards (`{component.plan-card-featured}`), the brand wordmark icon, and secondary CTAs in white-canvas regions.
- **Cobalt Bright** (`{colors.primary-bright}`: `#4f55f1`): a one-step-up bright variant used in inline link colour and accent-photo headers.
- **Cobalt Deep** (`{colors.primary-deep}`: `#3a40c4`): the active/pressed state of cobalt elements.
- **On-Primary** (`{colors.on-primary}`: `#ffffff`): label colour on top of `{colors.primary}` surfaces.

### Surface
- **Canvas Light** (`{colors.canvas-light}`: `#ffffff`): the white catalogue mode for FAQ, download tiles, comparison tables.
- **Canvas Dark** (`{colors.canvas-dark}`: `#000000`): the storytelling canvas: true black, never near-black.
- **Surface Soft** (`{colors.surface-soft}`: `#f4f4f4`): a subtle off-white used on download tiles, soft buttons, and inset card groups inside white bands.
- **Surface Card** (`{colors.surface-card}`: `#ffffff`): pure white card surface, used for feature cards in white-canvas regions.
- **Surface Deep** (`{colors.surface-deep}`: `#0a0a0a`): a one-step-up dark surface for inset cards inside black-canvas regions.
- **Surface Elevated** (`{colors.surface-elevated}`: `#16181a`): the card background: slightly luminous, lifts cards off the black canvas.
- **Hairline Light** (`{colors.hairline-light}`: `#e2e2e7`): 1px dividers inside white bands.
- **Hairline Dark** (`{colors.hairline-dark}`: `rgba(255,255,255,0.12)`): the corresponding low-contrast divider in dark regions.
- **Hairline Strong** (`{colors.hairline-strong}`: `#191c1f`): structural full-strength dividers and the outline of light cards.

### Text
- **Ink** (`{colors.ink}`: `#191c1f`): primary text colour. Notably warmer than pure black, paired with the white canvas for body legibility.
- **Body** (`{colors.body}`: `#1f2226`): long-form body where `{colors.ink}` would feel slightly too sharp.
- **Charcoal** (`{colors.charcoal}`: `#3a3d40`): captions, secondary nav.
- **Mute** (`{colors.mute}`: `#505a63`): supporting text.
- **Ash** (`{colors.ash}`: `#5c5e60`): tertiary text, footer copy.
- **Stone** (`{colors.stone}`: `#8d969e`): metadata, subtle captions.
- **Faint** (`{colors.faint}`: `#c9c9cd`): disabled foreground, hairline replacements.
- **On-Dark** (`{colors.on-dark}`: `#ffffff`): primary text on `{colors.canvas-dark}`.
- **On-Dark Mute** (`{colors.on-dark-mute}`: `rgba(255,255,255,0.72)`): secondary text in dark regions.

### Semantic
- **Accent Teal** (`{colors.accent-teal}`: `#00a87e`): used in product mockup illustrations.
- **Accent Light Blue** (`{colors.accent-light-blue}`: `#007bc2`): inline link colour in dark photo headers.
- **Accent Blue Link** (`{colors.accent-blue-link}`: `#376cd5`): default inline link colour on white surfaces.
- **Accent Light Green** (`{colors.accent-light-green}`: `#428619`): success / positive product callouts.
- **Accent Green Text** (`{colors.accent-green-text}`: `#006400`): inline success text.
- **Accent Yellow** (`{colors.accent-yellow}`: `#b09000`): caution / pending state in product mockups.
- **Accent Warning** (`{colors.accent-warning}`: `#ec7e00`): full-saturation orange used in warning illustrations.
- **Accent Pink** (`{colors.accent-pink}`: `#e61e49`): deep pink: used inside product photography and category iconography.
- **Accent Danger** (`{colors.accent-danger}`: `#e23b4a`): destructive / error state.
- **Accent Deep Red** (`{colors.accent-deep-red}`: `#8b0000`): inline error text.
- **Accent Brown** (`{colors.accent-brown}`: `#936d62`): a single warm-neutral used in metals tier card chrome.
- **Link** (`{colors.link}`: `#376cd5`): default inline link colour. Same as `{colors.accent-blue-link}`.

## Typography

### Font Family
- **Aeonik Pro / Inter Display**: display sizes (20px+) at weight 500 with tight negative letter-spacing.
- **Inter**: body, button labels, captions, and metadata at weight 400 or 600, with positive tracking (`0.16-0.24px`) on UI labels.
