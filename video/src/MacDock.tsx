import { Img, interpolate, staticFile, useCurrentFrame } from "remotion";

type DockIcon = {
  id: string;
  src: string;
  active?: boolean;
  separator?: boolean;
};

/** Typical macOS dock lineup with real system icons */
const DOCK_ICONS: DockIcon[] = [
  { id: "finder", src: "dock/finder.png" },
  { id: "safari", src: "dock/safari.png" },
  { id: "messages", src: "dock/messages.png" },
  { id: "mail", src: "dock/mail.png" },
  { id: "maps", src: "dock/maps.png" },
  { id: "photos", src: "dock/photos.png" },
  { id: "facetime", src: "dock/facetime.png" },
  { id: "calendar", src: "dock/calendar.png" },
  { id: "contacts", src: "dock/contacts.png" },
  { id: "reminders", src: "dock/reminders.png" },
  { id: "notes", src: "dock/notes.png" },
  { id: "headroom", src: "dock/headroom.png", active: true },
  { id: "music", src: "dock/music.png" },
  { id: "podcasts", src: "dock/podcasts.png" },
  { id: "appstore", src: "dock/appstore.png" },
  { id: "settings", src: "dock/settings.png" },
  { id: "divider", src: "", separator: true },
  { id: "trash", src: "dock/trash.png" },
];

export const MacDock: React.FC = () => {
  const frame = useCurrentFrame();
  const breathe = interpolate(frame % 90, [0, 45, 90], [1, 1.01, 1]);

  return (
    <div
      style={{
        position: "absolute",
        bottom: 10,
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
          gap: 7,
          padding: "8px 14px 10px",
          borderRadius: 20,
          background: "rgba(245,245,247,0.18)",
          backdropFilter: "blur(42px) saturate(190%)",
          border: "1px solid rgba(255,255,255,0.28)",
          boxShadow:
            "0 20px 55px rgba(0,0,0,0.42), inset 0 1px 0 rgba(255,255,255,0.35)",
        }}
      >
        {DOCK_ICONS.map((icon) => {
          if (icon.separator) {
            return (
              <div
                key={icon.id}
                style={{
                  width: 1,
                  height: 44,
                  background: "rgba(255,255,255,0.18)",
                  margin: "0 4px 8px",
                  alignSelf: "center",
                }}
              />
            );
          }

          const lift = icon.active ? 12 : 0;
          const scale = icon.active ? 1.14 : 1;

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
              <Img
                src={staticFile(icon.src)}
                style={{
                  width: 50,
                  height: 50,
                  borderRadius: 11,
                  boxShadow: icon.active
                    ? "0 10px 24px rgba(0,0,0,0.35)"
                    : "0 4px 12px rgba(0,0,0,0.22)",
                }}
              />
              <div
                style={{
                  width: 4,
                  height: 4,
                  borderRadius: "50%",
                  background: icon.active
                    ? "rgba(255,255,255,0.92)"
                    : "transparent",
                  marginTop: 5,
                }}
              />
              <div
                style={{
                  width: 34,
                  height: 6,
                  marginTop: 2,
                  borderRadius: "50%",
                  background: "rgba(0,0,0,0.25)",
                  filter: "blur(3px)",
                  opacity: icon.active ? 0.5 : 0.28,
                }}
              />
            </div>
          );
        })}
      </div>
    </div>
  );
};
