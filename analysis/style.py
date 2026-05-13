#!/usr/bin/env python3
"""Shared chart styling for rtmx-bench visualizations.

REQ-DATA-003: Publication-quality charts with colorblind-safe palette.
"""

# Colorblind-safe palette (IBM Design Library)
COLORS = {
    "control": "#648FFF",      # blue
    "treatment": "#DC267F",    # magenta
    "rtmx": "#FE6100",         # orange
    "planning": "#785EF0",     # purple
    "execution": "#FFB000",    # gold
    "neutral": "#808080",      # gray
}

FONT_FAMILY = "sans-serif"
FONT_SIZE_TITLE = 14
FONT_SIZE_LABEL = 11
FONT_SIZE_TICK = 9
DPI = 300


def apply_style(ax, title: str = "", xlabel: str = "", ylabel: str = ""):
    """Apply consistent styling to a matplotlib axis."""
    if title:
        ax.set_title(title, fontsize=FONT_SIZE_TITLE, fontfamily=FONT_FAMILY,
                     fontweight="bold", pad=12)
    if xlabel:
        ax.set_xlabel(xlabel, fontsize=FONT_SIZE_LABEL, fontfamily=FONT_FAMILY)
    if ylabel:
        ax.set_ylabel(ylabel, fontsize=FONT_SIZE_LABEL, fontfamily=FONT_FAMILY)
    ax.tick_params(labelsize=FONT_SIZE_TICK)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
