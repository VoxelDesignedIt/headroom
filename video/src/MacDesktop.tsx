import { interpolate, useCurrentFrame } from "remotion";
import { LAYOUT } from "./layout";
import { MacDock } from "./MacDock";
import { MenuBarPopover } from "./MenuBarPopover";

type MacDesktopProps = {
  sessionPercent: number;
  weeklyPercent: number;
  popoverSessionPercent: number;
  popoverProgress: number;
  heroOpacity: number;
  iconHover: number;
};

export const MacDesktop: React.FC<MacDesktopProps> = ({
  sessionPercent,
  weeklyPercent,
  popoverSessionPercent,
  popoverProgress,
  heroOpacity,
  iconHover,
}) => {
  const frame = useCurrentFrame();
  const glow = interpolate(frame % 45, [0, 22, 45], [0.35, 0.9, 0.35]);

  const statusColor =
    sessionPercent >= 90
      ? "#ff5f57"
      : sessionPercent >= 75
        ? "#ff9f0a"
        : sessionPercent >= 50
          ? "#ffd60a"
          : "#30d158";

  const dot =
    sessionPercent >= 90
      ? "🔴"
      : sessionPercent >= 75
        ? "🟠"
        : sessionPercent >= 50
          ? "🟡"
          : "🟢";

  const hoverRing = interpolate(iconHover, [0, 1], [0, 1]);

  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        background:
          "radial-gradient(ellipse 120% 80% at 50% 0%, #2a2a38 0%, #12121a 45%, #08080c 100%)",
        position: "relative",
        overflow: "hidden",
        fontFamily:
          '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif',
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          background:
            "radial-gradient(circle at 78% 12%, rgba(124,131,255,0.22), transparent 28%), radial-gradient(circle at 18% 72%, rgba(52,211,153,0.14), transparent 32%), radial-gradient(circle at 50% 50%, rgba(255,255,255,0.03), transparent 50%)",
        }}
      />

      <div
        style={{
          position: "absolute",
          inset: 0,
          opacity: 0.04,
          backgroundImage:
            "url(\"data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E\")",
        }}
      />

      <div
        style={{
          height: LAYOUT.menuBarHeight,
          background: "rgba(22,22,28,0.72)",
          backdropFilter: "blur(30px) saturate(160%)",
          borderBottom: "1px solid rgba(255,255,255,0.08)",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          padding: `0 ${LAYOUT.menuBarPaddingX}px`,
          color: "rgba(255,255,255,0.92)",
          fontSize: 13,
          position: "relative",
          zIndex: 20,
        }}
      >
        <div style={{ display: "flex", gap: 18, alignItems: "center" }}>
          <span style={{ fontWeight: 600 }}>Finder</span>
          <span style={{ opacity: 0.5 }}>File</span>
          <span style={{ opacity: 0.5 }}>Edit</span>
          <span style={{ opacity: 0.5 }}>View</span>
        </div>

        <div
          style={{
            position: "absolute",
            right: LAYOUT.menuBarPaddingX,
            top: 0,
            height: LAYOUT.menuBarHeight,
            display: "flex",
            gap: 14,
            alignItems: "center",
          }}
        >
          <span style={{ opacity: 0.45, fontSize: 12 }}>Wi-Fi</span>
          <span style={{ opacity: 0.45, fontSize: 12 }}>Mon Jun 14  2:41 PM</span>
          <div
            style={{
              position: "relative",
              padding: "4px 11px",
              borderRadius: 7,
              background:
                hoverRing > 0.1
                  ? `rgba(255,255,255,${0.08 + hoverRing * 0.1})`
                  : "rgba(255,255,255,0.08)",
              boxShadow: [
                `0 0 0 1px rgba(255,255,255,${0.08 + hoverRing * 0.12})`,
                hoverRing > 0.1
                  ? `0 0 0 ${3 + hoverRing * 4}px ${statusColor}${Math.round(hoverRing * 40)
                      .toString(16)
                      .padStart(2, "0")}`
                  : "",
                `0 0 18px ${statusColor}${Math.round(glow * 80)
                  .toString(16)
                  .padStart(2, "0")}`,
              ]
                .filter(Boolean)
                .join(", "),
              fontWeight: 600,
              fontVariantNumeric: "tabular-nums",
              transform: `scale(${1 + hoverRing * 0.04})`,
            }}
          >
            {dot} {Math.round(sessionPercent)}%
          </div>
        </div>
      </div>

      <div
        style={{
          position: "absolute",
          top: 110,
          left: "50%",
          transform: "translateX(-50%)",
          color: "rgba(255,255,255,0.95)",
          textAlign: "center",
          opacity: heroOpacity,
        }}
      >
        <div
          style={{
            fontSize: 58,
            fontWeight: 700,
            letterSpacing: -2,
            textShadow: "0 8px 40px rgba(0,0,0,0.35)",
          }}
        >
          Your desktop. Your limits.
        </div>
        <div
          style={{
            marginTop: 14,
            fontSize: 22,
            color: "rgba(255,255,255,0.5)",
            fontWeight: 500,
          }}
        >
          Always visible in the menu bar
        </div>
      </div>

      {popoverProgress > 0.01 && (
        <div
          style={{
            position: "absolute",
            right: LAYOUT.menuBarPaddingX,
            top: LAYOUT.menuBarHeight + 6,
            zIndex: 30,
            transform: `translateY(${interpolate(popoverProgress, [0, 1], [-10, 0])}px) scale(${interpolate(popoverProgress, [0, 1], [0.95, 1])})`,
            opacity: popoverProgress,
            transformOrigin: "top right",
          }}
        >
          <MenuBarPopover
            sessionPercent={popoverSessionPercent}
            weeklyPercent={weeklyPercent}
            progress={popoverProgress}
          />
        </div>
      )}

      <MacDock />
    </div>
  );
};
