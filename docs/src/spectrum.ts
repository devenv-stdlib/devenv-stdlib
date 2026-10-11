import { createComponent } from "@lit/react";
import { ActionButton } from "@spectrum-web-components/action-button";
import "@spectrum-web-components/action-button/sp-action-button.js";
import { Divider } from "@spectrum-web-components/divider";
import "@spectrum-web-components/divider/sp-divider.js";
import { IconChevronUp } from "@spectrum-web-components/icons-workflow/src/elements/IconChevronUp.js";
import "@spectrum-web-components/icons-workflow/icons/sp-icon-chevron-up.js";
import { Link } from "@spectrum-web-components/link";
import "@spectrum-web-components/link/sp-link.js";
import {
  SideNav,
  SideNavHeading,
  SideNavItem,
} from "@spectrum-web-components/sidenav";
import "@spectrum-web-components/sidenav/sp-sidenav-heading.js";
import "@spectrum-web-components/sidenav/sp-sidenav-item.js";
import "@spectrum-web-components/sidenav/sp-sidenav.js";
import { Theme } from "@spectrum-web-components/theme";
import "@spectrum-web-components/theme/sp-theme.js";
import "@spectrum-web-components/theme/src/spectrum-two/themes.js";
import type { ReactElement, ReactNode } from "react";
import React from "react";

type Wc<P> = (props: P & { children?: ReactNode }) => ReactElement | null;

function asWc<P>(component: object): Wc<P> {
  return component as unknown as Wc<P>;
}

export const SpTheme = asWc<{
  system?: string;
  color?: string;
  scale?: string;
}>(
  createComponent({
    react: React,
    tagName: "sp-theme",
    elementClass: Theme,
  }),
);

export const SpSidenav = asWc<{
  label?: string;
  variant?: "multilevel";
  value?: string;
  onChange?: (event: Event) => void;
}>(
  createComponent({
    react: React,
    tagName: "sp-sidenav",
    elementClass: SideNav,
    events: {
      onChange: "change",
    },
  }),
);

export const SpSidenavItem = asWc<{
  value?: string;
  label?: string;
  href?: string;
  expanded?: boolean;
  selected?: boolean;
}>(
  createComponent({
    react: React,
    tagName: "sp-sidenav-item",
    elementClass: SideNavItem,
  }),
);

export const SpSidenavHeading = asWc<{
  label?: string;
}>(
  createComponent({
    react: React,
    tagName: "sp-sidenav-heading",
    elementClass: SideNavHeading,
  }),
);

export const SpLink = asWc<{
  href?: string;
  target?: string;
}>(
  createComponent({
    react: React,
    tagName: "sp-link",
    elementClass: Link,
  }),
);

export const SpDivider = asWc<{
  size?: string;
}>(
  createComponent({
    react: React,
    tagName: "sp-divider",
    elementClass: Divider,
  }),
);

export const SpActionButton = asWc<{
  quiet?: boolean;
  emphasized?: boolean;
  size?: "s" | "m" | "l";
  label?: string;
  onClick?: (event: Event) => void;
}>(
  createComponent({
    react: React,
    tagName: "sp-action-button",
    elementClass: ActionButton,
    events: {
      onClick: "click",
    },
  }),
);

export const SpIconChevronUp = asWc<{
  slot?: string;
  label?: string;
}>(
  createComponent({
    react: React,
    tagName: "sp-icon-chevron-up",
    elementClass: IconChevronUp,
  }),
);
