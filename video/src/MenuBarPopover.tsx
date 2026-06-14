import { interpolate } from "remotion";

type MenuBarPopoverProps = {
  sessionPercent: number;
  weeklyPercent: number;
  progress: number;
};

const UsageBar: React.FC<{
  title: string;
  percent: number;
  resetLabel: string;
  countdown: string;
}> = ({ title, percent, resetLabel, countdown }) => {
  const color =
    percent >= 90
      ? "#ff5f57"
      : percent >= 75
        ? "#ff9f0a"
        : percent >= 50
          ? "#ffd60a"
          : "#30d158";

  return (
    <div style={{ marginBottom: 14 }}>
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          marginBottom: 6,
          fontSize: 14,
          fontWeight: 600,
          color: "#f5f5f7",
        }}
      >
        <span>{title}</span>
        <span style={{ color, fontVariantNumeric: "tabular-nums" }}>
          {Math.round(percent)}%
        </span>
      </div>
      <div
        style={{
          height: 10,
          borderRadius: 4,
          background: "rgba(255,255,255,0.12)",
          overflow: "hidden",
        }}
      >
        <div
          style={{
            width: `${percent}%`,
            height: "100%",
            background: color,
            borderRadius: 4,
          }}
        />
      </div>
      <div
        style={{
          marginTop: 6,
          fontSize: 11,
          color: "rgba(255,255,255,0.45)",
          lineHeight: 1.4,
        }}
      >
        <div>Resets: {resetLabel}</div>
        <div style={{ fontVariantNumeric: "tabular-nums" }}>In {countdown}</div>
      </div>
    </div>
  );
};

export const MenuBarPopover: React.FC<MenuBarPopoverProps> = ({
  sessionPercent,
  weeklyPercent,
  progress,
}) => {
  const scale = interpolate(progress, [0, 1], [0.94, 1]);

  return (
    <div
      style={{
        width: 320,
        padding: 18,
        borderRadius: 14,
        background: "rgba(24,24,30,0.94)",
        border: "1px solid rgba(255,255,255,0.12)",
        boxShadow:
          "0 28px 70px rgba(0,0,0,0.55), inset 0 1px 0 rgba(255,255,255,0.08)",
        transform: `scale(${scale})`,
        transformOrigin: "top right",
        color: "#fff",
      }}
    >
      <div
        style={{
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          marginBottom: 14,
        }}
      >
        <div style={{ fontSize: 18, fontWeight: 700 }}>Headroom</div>
        <div
          style={{
            width: 8,
            height: 8,
            borderRadius: "50%",
            background: "#30d158",
            boxShadow: "0 0 10px rgba(48,209,88,0.8)",
          }}
        />
      </div>

      <UsageBar
        title="5-hour window"
        percent={sessionPercent}
        resetLabel="Jun 14, 2026 at 7:41 PM"
        countdown="1h 40m 12s"
      />
      <UsageBar
        title="Weekly limit"
        percent={weeklyPercent}
        resetLabel="Jun 18, 2026 at 2:41 PM"
        countdown="3d 12h 0m"
      />

      <div
        style={{
          borderTop: "1px solid rgba(255,255,255,0.08)",
          marginTop: 8,
          paddingTop: 10,
          fontSize: 11,
          color: "rgba(255,255,255,0.35)",
        }}
      >
        Exact reset times · macOS notifications
      </div>
    </div>
  );
};
