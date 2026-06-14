import { interpolate, useCurrentFrame } from "remotion";

const DOCK_ICONS = [
  { id: "finder", color: "#5AC8FA", label: "F" },
  { id: "safari", color: "#0A84FF", label: "S" },
  { id: "messages", color: "#30D158", label: "M" },
  { id: "mail", color: "#64D2FF", label: "@" },
  { id: "headroom", color: "#7C83FF", label: "H", active: true },
  { id: "notes", color: "#FFD60A", label: "N" },
  { id: "settings", color: "#8E8E93", label: "⚙" },
  { id: "trash", color: "#636366", label: "🗑" },
];

export const MacDock: React.FC = () => {
  const frame = useCurrentFrame();
  const breathe = interpolate(frame % 90, [0, 45, 90], [1, 1.02, 1]);

  return (
    <div
      style={{
        position: "absolute",
        bottom: 14,
        left: "50%",
        transform: `translateX(-50%) scale(${breathe})`,
        transformOrigin: "center bottom",
        zIndex: 25,
      }}
    >
      <div
        style={{
          display: "flex",
          alignItems: "flex-end",
          gap: 10,
          padding: "10px 18px 12px",
          borderRadius: 22,
          background: "rgba(255,255,255,0.14)",
          backdropFilter: "blur(40px) saturate(180%)",
          border: "1px solid rgba(255,255,255,0.22)",
          boxShadow:
            "0 18px 50px rgba(0,0,0,0.45), inset 0 1px 0 rgba(255,255,255,0.25)",
        }}
      >
        {DOCK_ICONS.map((icon) => {
          const lift = icon.active ? 14 : 0;
          const scale = icon.active ? 1.18 : 1;

          return (
            <div
              key={icon.id}
              style={{
                display: "flex",
                flexDirection: "column",
                alignItems: "center",
                transform: `translateY(-${lift}px) scale(${scale})`,
              }}
            >
              <div
                style={{
                  width: 52,
                  height: 52,
                  borderRadius: 13,
                  background: `linear-gradient(145deg, ${icon.color}, ${icon.color}88)`,
                  boxShadow: icon.active
                    ? `0 12px 28px ${icon.color}55, 0 0 0 1px rgba(255,255,255,0.15)`
                    : "0 6px 16px rgba(0,0,0,0.28), 0 0 0 1px rgba(255,255,255,0.08)",
                  display: "grid",
                  placeItems: "center",
                  fontSize: icon.id === "headroom" ? 22 : 18,
                  fontWeight: 700,
                  color: "white",
                  textShadow: "0 1px 2px rgba(0,0,0,0.35)",
                }}
              >
                {icon.label}
              </div>
              <div
                style={{
                  width: 4,
                  height: 4,
                  borderRadius: "50%",
                  background: icon.active ? "rgba(255,255,255,0.9)" : "transparent",
                  marginTop: 6,
                }}
              />
              <div
                style={{
                  width: 38,
                  height: 8,
                  marginTop: 2,
                  borderRadius: "50%",
                  background: "rgba(0,0,0,0.22)",
                  filter: "blur(4px)",
                  opacity: icon.active ? 0.55 : 0.3,
                }}
              />
            </div>
          );
        })}
      </div>
    </div>
  );
};
