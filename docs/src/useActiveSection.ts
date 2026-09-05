import { useEffect, useState } from "react";

export function useActiveSection(ids: string[], root: HTMLElement | null): string {
  const [active, setActive] = useState(ids[0] ?? "");

  useEffect(() => {
    if (!root || ids.length === 0) {
      return;
    }

    let frame = 0;
    const update = () => {
      const threshold = root.getBoundingClientRect().top + 64;
      let current = ids[0];
      for (const id of ids) {
        const el = document.getElementById(id);
        if (el && el.getBoundingClientRect().top <= threshold) {
          current = id;
        }
      }
      setActive(current);
    };

    const onScroll = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(update);
    };

    update();
    root.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll);
    return () => {
      cancelAnimationFrame(frame);
      root.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
    };
  }, [ids, root]);

  return active;
}
