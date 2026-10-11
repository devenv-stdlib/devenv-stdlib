import apply from "../content/apply.md?raw";
import architecture from "../content/architecture.md?raw";
import stdlib from "../content/stdlib.md?raw";
import bootstrap from "../content/bootstrap.md?raw";
import ci from "../content/ci.md?raw";
import contributing from "../content/contributing.md?raw";
import hooks from "../content/hooks.md?raw";
import languages from "../content/languages.md?raw";
import overview from "../content/overview.md?raw";
import reference from "../content/reference.md?raw";
import skills from "../content/skills.md?raw";
import terminal from "../content/terminal.md?raw";
import tools from "../content/tools.md?raw";
import { slug } from "./slug";

export type DocHeading = {
  id: string;
  title: string;
};

export type DocSection = {
  id: string;
  title: string;
  source: string;
  headings: DocHeading[];
};

function headingsFrom(sectionId: string, source: string): DocHeading[] {
  return [...source.matchAll(/^## (.+)$/gm)].map((match) => {
    const title = match[1].replace(/[*`]/g, "");
    return { id: `${sectionId}-${slug(title)}`, title };
  });
}

function section(id: string, title: string, source: string): DocSection {
  return { id, title, source, headings: headingsFrom(id, source) };
}

export const sections: DocSection[] = [
  section("overview", "Overview", overview),
  section("architecture", "Architecture", architecture),
  section("stdlib", "Standard library", stdlib),
  section("apply", "Consume the package", apply),
  section("bootstrap", "Bootstrap", bootstrap),
  section("tools", "Tools and CLI", tools),
  section("skills", "Agent skills", skills),
  section("languages", "Languages and versions", languages),
  section("hooks", "Hooks and commits", hooks),
  section("terminal", "Terminal and Cursor", terminal),
  section("ci", "CI and tests", ci),
  section("reference", "Layout reference", reference),
  section("contributing", "Contribution guide", contributing),
];
