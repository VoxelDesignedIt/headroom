/** Fixed layout coordinates for 1920×1080 — keeps cursor aligned with menu bar icon */
export const LAYOUT = {
  width: 1920,
  height: 1080,
  menuBarHeight: 34,
  menuBarPaddingX: 18,
  /** Center of the status badge in the top-right menu bar */
  statusIconCenterX: 1874,
  statusIconCenterY: 16,
  /** Where the cursor starts before moving to the icon */
  cursorStartX: 960,
  cursorStartY: 420,
} as const;

/** macOS cursor tip offset — hotspot is top-left of the SVG */
export const CURSOR_HOTSPOT = { x: 0, y: 0 } as const;

export const statusIconPosition = () => ({
  x: LAYOUT.statusIconCenterX - CURSOR_HOTSPOT.x,
  y: LAYOUT.statusIconCenterY - CURSOR_HOTSPOT.y,
});
