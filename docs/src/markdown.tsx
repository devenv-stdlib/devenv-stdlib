import { Children, isValidElement, type ReactNode } from "react";
import type { Components } from "react-markdown";
import { createHighlighterCoreSync } from "@shikijs/core";
import bash from "@shikijs/langs/bash";
import nix from "@shikijs/langs/nix";
import githubLight from "@shikijs/themes/github-light";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { createJavaScriptRegexEngine } from "shiki/engine/javascript";
import { headingText, slug } from "./slug";
import { SpLink } from "./spectrum";

const fenceLangs = ["bash", "nix"] as const;

function makeHighlighter() {
  try {
    return createHighlighterCoreSync({
      themes: [githubLight],
      langs: [bash, nix],
      engine: createJavaScriptRegexEngine(),
    });
  } catch (error) {
    console.error("docs: Shiki highlighter failed to start", error);
    return null;
  }
}

const highlighter = makeHighlighter();

function fenceLanguage(className: unknown): string | undefined {
  if (typeof className !== "string") {
    return undefined;
  }
  return /language-(\w+)/.exec(className)?.[1];
}

function HighlightedPre({ children }: { children?: ReactNode }) {
  const child = Children.toArray(children)[0];
  if (!isValidElement(child)) {
    return <pre>{children}</pre>;
  }
  const props = child.props as { className?: string; children?: ReactNode };
  const lang = fenceLanguage(props.className);
  if (
    !highlighter ||
    !lang ||
    !fenceLangs.includes(lang as (typeof fenceLangs)[number])
  ) {
    return <pre>{children}</pre>;
  }
  const code = String(props.children ?? "").replace(/\n$/, "");
  try {
    return (
      <div
        className="docs-code"
        dangerouslySetInnerHTML={{
          __html: highlighter.codeToHtml(code, { lang, theme: "github-light" }),
        }}
      />
    );
  } catch (error) {
    console.error("docs: Shiki failed to highlight", lang, error);
    return <pre>{children}</pre>;
  }
}

function headingId(sectionId: string, children: ReactNode): string {
  const text = headingText(children);
  return text ? `${sectionId}-${slug(text)}` : sectionId;
}

export function markdownComponents(sectionId: string): Components {
  return {
    h1: ({ children }) => <h1>{children}</h1>,
    h2: ({ children }) => (
      <h2 id={headingId(sectionId, children)}>{children}</h2>
    ),
    h3: ({ children }) => (
      <h3 id={headingId(sectionId, children)}>{children}</h3>
    ),
    a: ({ href, children }) => (
      <SpLink
        href={href}
        target={href?.startsWith("http") ? "_blank" : undefined}
      >
        {children}
      </SpLink>
    ),
    pre: ({ children }) => <HighlightedPre>{children}</HighlightedPre>,
  };
}

export function MarkdownSection({
  id,
  source,
}: {
  id: string;
  source: string;
}) {
  return (
    <section className="docs-section" id={id} data-section={id}>
      <Markdown remarkPlugins={[remarkGfm]} components={markdownComponents(id)}>
        {source}
      </Markdown>
    </section>
  );
}
