import type { ReactNode } from "react";
import type { Components } from "react-markdown";
import Markdown from "react-markdown";
import remarkGfm from "remark-gfm";
import { headingText, slug } from "./slug";
import { SpLink } from "./spectrum";

function headingId(sectionId: string, children: ReactNode): string {
  const text = headingText(children);
  return text ? `${sectionId}-${slug(text)}` : sectionId;
}

export function markdownComponents(sectionId: string): Components {
  return {
    h1: ({ children }) => <h1>{children}</h1>,
    h2: ({ children }) => <h2 id={headingId(sectionId, children)}>{children}</h2>,
    h3: ({ children }) => <h3 id={headingId(sectionId, children)}>{children}</h3>,
    a: ({ href, children }) => (
      <SpLink href={href} target={href?.startsWith("http") ? "_blank" : undefined}>
        {children}
      </SpLink>
    ),
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
