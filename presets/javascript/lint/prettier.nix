# Shared JS/TS formatter. Uses javascript-or-typescript category policy.
{ tools, ... }: {
  path = [
    "javascript"
    "lint"
    "prettier"
  ];
  description = "Prettier git-hook and JS/TS editor formatter settings.";
  categoryPolicy = "javascript-or-typescript";
  tools = [ tools.javascript.lint.prettier ];
}
