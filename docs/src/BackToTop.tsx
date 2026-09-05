import { useEffect, useState } from "react";
import { SpActionButton, SpIconChevronUp } from "./spectrum";

const SHOW_AFTER_PX = 240;

export function BackToTop({ root }: { root: HTMLElement | null }) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const update = () => {
      setVisible((root?.scrollTop ?? 0) > SHOW_AFTER_PX || window.scrollY > SHOW_AFTER_PX);
    };
    update();
    root?.addEventListener("scroll", update, { passive: true });
    window.addEventListener("scroll", update, { passive: true });
    return () => {
      root?.removeEventListener("scroll", update);
      window.removeEventListener("scroll", update);
    };
  }, [root]);

  if (!visible) {
    return null;
  }

  return (
    <div className="docs-back-to-top">
      <SpActionButton
        emphasized
        size="l"
        label="Back to top"
        onClick={() => {
          root?.scrollTo({ top: 0, behavior: "smooth" });
          window.scrollTo({ top: 0, behavior: "smooth" });
          history.replaceState(null, "", "#overview");
        }}
      >
        <SpIconChevronUp slot="icon" label="Back to top" />
      </SpActionButton>
    </div>
  );
}
