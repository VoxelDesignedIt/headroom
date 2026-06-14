import {
  AbsoluteFill,
  Easing,
  interpolate,
  Sequence,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { MacDesktop } from "./MacDesktop";
import { EndCard } from "./EndCard";
import { LAYOUT, statusIconPosition } from "./layout";

export const HeadroomPromo: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const clickStart = 2 * fps;
  const popoverOpenStart = 2.4 * fps;
  const fillStart = 2.8 * fps;
  const fillEnd = 5.8 * fps;
  const closeStart = 6.1 * fps;
  const closeEnd = 7 * fps;
  const holdEnd = 8.2 * fps;
  const fadeStart = holdEnd;
  const fadeEnd = 9.2 * fps;

  const target = statusIconPosition();

  const popoverOpenSpring = spring({
    frame: frame - popoverOpenStart,
    fps,
    config: { damping: 20, stiffness: 200 },
  });

  const popoverCloseProgress = interpolate(frame, [closeStart, closeEnd], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.4, 0, 0.2, 1),
  });

  let popoverProgress = 0;
  if (frame >= popoverOpenStart && frame < closeStart) {
    popoverProgress = popoverOpenSpring;
  } else if (frame >= closeStart && frame < closeEnd) {
    popoverProgress = 1 - popoverCloseProgress;
  }

  const sessionPercent = interpolate(frame, [fillStart, fillEnd], [10, 87], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.bezier(0.22, 1, 0.36, 1),
  });

  const menuBarPercent =
    frame < fillStart ? 10 : frame < fillEnd ? sessionPercent : 87;

  const weeklyPercent = 48;

  const heroOpacity = interpolate(
    frame,
    [popoverOpenStart, fillStart, closeStart],
    [1, 0.35, 0],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    },
  );

  const desktopOpacity = interpolate(frame, [fadeStart, fadeEnd], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  const blackOverlay = interpolate(frame, [fadeStart, fadeEnd], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.inOut(Easing.cubic),
  });

  const endOpacity = interpolate(frame, [fadeEnd - 6, fadeEnd + 24], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const moveStart = clickStart - 18;
  const moveEnd = clickStart + 4;

  const cursorX = interpolate(
    frame,
    [moveStart, moveEnd],
    [LAYOUT.cursorStartX, target.x],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: Easing.bezier(0.25, 0.1, 0.25, 1),
    },
  );

  const cursorY = interpolate(
    frame,
    [moveStart, moveEnd],
    [LAYOUT.cursorStartY, target.y],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
      easing: Easing.bezier(0.25, 0.1, 0.25, 1),
    },
  );

  const iconHover = interpolate(frame, [moveEnd - 6, moveEnd + 2], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
    easing: Easing.out(Easing.cubic),
  });

  const clickScale =
    frame >= clickStart + 1 && frame <= clickStart + 7 ? 0.88 : 1;

  const showCursor = frame >= moveStart && frame < popoverOpenStart + 16;

  return (
    <AbsoluteFill style={{ backgroundColor: "#000" }}>
      <AbsoluteFill style={{ opacity: desktopOpacity }}>
        <MacDesktop
          sessionPercent={menuBarPercent}
          weeklyPercent={weeklyPercent}
          popoverSessionPercent={sessionPercent}
          popoverProgress={popoverProgress}
          heroOpacity={heroOpacity}
          iconHover={showCursor ? iconHover : 0}
        />

        {showCursor && (
          <div
            style={{
              position: "absolute",
              left: cursorX,
              top: cursorY,
              transform: `scale(${clickScale})`,
              pointerEvents: "none",
              zIndex: 50,
              filter: "drop-shadow(0 2px 6px rgba(0,0,0,0.5))",
            }}
          >
            <MacCursor />
          </div>
        )}
      </AbsoluteFill>

      <AbsoluteFill
        style={{
          backgroundColor: "#000",
          opacity: blackOverlay,
        }}
      />

      <AbsoluteFill style={{ opacity: endOpacity }}>
        <Sequence from={Math.round(fadeEnd)} layout="none">
          <EndCard />
        </Sequence>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const MacCursor: React.FC = () => (
  <svg width="24" height="30" viewBox="0 0 22 28" fill="none">
    <path
      d="M1 1L1 22.5L6.8 17.8L10.5 26.5L13.5 25.2L9.8 16.5L17.5 16.5L1 1Z"
      fill="white"
      stroke="rgba(0,0,0,0.85)"
      strokeWidth="1.4"
      strokeLinejoin="round"
    />
  </svg>
);
