import { useEffect, useMemo, useState } from "react";
import { BackToTop } from "./BackToTop";
import { MarkdownSection } from "./markdown";
import { sections } from "./sections";
import { SpDivider, SpSidenav, SpSidenavHeading, SpSidenavItem, SpTheme } from "./spectrum";
import { useActiveSection } from "./useActiveSection";

function scrollToId(id: string, root: HTMLElement | null) {
  const el = document.getElementById(id);
  if (!el) {
    return;
  }
  if (root) {
    const offset =
      el.getBoundingClientRect().top - root.getBoundingClientRect().top + root.scrollTop;
    root.scrollTo({ top: Math.max(0, offset - 8), behavior: "smooth" });
  } else {
    el.scrollIntoView({ behavior: "smooth", block: "start" });
  }
  history.replaceState(null, "", `#${id}`);
}

function sidenavItemFromEvent(event: React.MouseEvent): HTMLElement | undefined {
  return event.nativeEvent.composedPath().find(
    (node): node is HTMLElement =>
      node instanceof HTMLElement && node.localName === "sp-sidenav-item",
  );
}

export function App() {
  const [scrollerEl, setScrollerEl] = useState<HTMLElement | null>(null);
  const [pending, setPending] = useState<string | null>(null);
  const navIds = useMemo(
    () => sections.flatMap((section) => [section.id, ...section.headings.map((h) => h.id)]),
    [],
  );
  const active = useActiveSection(navIds, scrollerEl);
  const highlight = pending ?? active;

  useEffect(() => {
    const id = window.location.hash.replace(/^#/, "");
    if (id && scrollerEl) {
      setPending(id);
      requestAnimationFrame(() => scrollToId(id, scrollerEl));
    }
  }, [scrollerEl]);

  useEffect(() => {
    if (!pending || !scrollerEl) {
      return;
    }
    const clear = () => setPending(null);
    scrollerEl.addEventListener("scrollend", clear);
    const timeout = window.setTimeout(clear, 800);
    return () => {
      scrollerEl.removeEventListener("scrollend", clear);
      window.clearTimeout(timeout);
    };
  }, [pending, scrollerEl]);

  const goTo = (id: string) => {
    setPending(id);
    scrollToId(id, scrollerEl);
  };

  return (
    <SpTheme system="spectrum-two" color="light" scale="medium">
      <div className="docs-app">
        <header className="docs-header">
          <strong>devenv4monorepo</strong>
          <span>Documentation</span>
        </header>
        <aside
          className="docs-sidebar"
          aria-label="On this page"
          onClick={(event) => {
            const item = sidenavItemFromEvent(event);
            const id = item && "value" in item ? String(item.value ?? "") : "";
            if (!id) {
              return;
            }
            event.preventDefault();
            goTo(id);
          }}
        >
          <SpSidenav label="On this page" variant="multilevel" value={highlight}>
            <SpSidenavHeading label="Contents">Contents</SpSidenavHeading>
            {sections.map((section) => (
              <SpSidenavItem
                key={section.id}
                value={section.id}
                label={section.title}
                href={`#${section.id}`}
                expanded
                selected={highlight === section.id}
              >
                {section.headings.map((heading) => (
                  <SpSidenavItem
                    key={heading.id}
                    value={heading.id}
                    label={heading.title}
                    href={`#${heading.id}`}
                    selected={highlight === heading.id}
                  />
                ))}
              </SpSidenavItem>
            ))}
          </SpSidenav>
          <SpDivider size="s" />
          <p className="docs-sidebar-note">
            Scroll the page. The left nav follows the section in view.
          </p>
        </aside>
        <main className="docs-main" ref={setScrollerEl}>
          {sections.map((section) => (
            <MarkdownSection key={section.id} id={section.id} source={section.source} />
          ))}
        </main>
        <BackToTop root={scrollerEl} />
      </div>
    </SpTheme>
  );
}
