"""
Generate the SoilGood Use Case Diagram with stickman actors.

Produces docs/paper/figures/fig3_use_case.png in classic UML stickman style
(Farmer on the left, Administrator on the right, use cases inside a system
boundary rectangle). Matches the hand-sketched reference the user provided.

Run:  python docs/paper/build_use_case.py
"""

from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, Rectangle

HERE = Path(__file__).resolve().parent
OUT = HERE / "figures" / "fig3_use_case.png"

# SoilGood theme colors
BG = "#F6F8F3"
DARK = "#243028"
BORDER = "#62A844"
LINE = "#4E9434"


def draw_stickman(ax, x, y, label):
    """Draw a classic UML actor (stickman) centered at (x, y)."""
    # Head
    head = plt.Circle((x, y + 1.1), 0.28, fill=False,
                      edgecolor=DARK, linewidth=1.8)
    ax.add_patch(head)
    # Body
    ax.plot([x, x], [y + 0.82, y - 0.1], color=DARK, linewidth=1.8)
    # Arms (upside-down V)
    ax.plot([x - 0.55, x, x + 0.55], [y + 0.1, y + 0.55, y + 0.1],
            color=DARK, linewidth=1.8)
    # Legs
    ax.plot([x - 0.45, x, x + 0.45], [y - 0.95, y - 0.1, y - 0.95],
            color=DARK, linewidth=1.8)
    # Label
    ax.text(x, y - 1.35, label, ha="center", fontsize=11, color=DARK,
            weight="bold")


def draw_use_case(ax, x, y, text, width=2.7, height=0.65):
    """Draw a use-case ellipse at (x, y). Returns anchor edge points."""
    e = Ellipse((x, y), width, height, facecolor="white",
                edgecolor=BORDER, linewidth=1.6)
    ax.add_patch(e)
    ax.text(x, y, text, ha="center", va="center", fontsize=9.5, color=DARK)
    # Return (left_edge_x, right_edge_x, y) so callers can connect cleanly
    return x - width / 2, x + width / 2, y


def connect(ax, from_x, from_y, to_x, to_y):
    """Thin solid association line between an actor and a use case."""
    ax.plot([from_x, to_x], [from_y, to_y], color=LINE, linewidth=0.9)


def build():
    fig, ax = plt.subplots(figsize=(10.5, 11.5), facecolor=BG)
    ax.set_facecolor(BG)
    ax.set_xlim(0, 10.5)
    ax.set_ylim(0, 12)
    ax.axis("off")

    # System boundary rectangle
    boundary = Rectangle((2.5, 0.6), 5.5, 11, fill=False,
                         edgecolor=BORDER, linewidth=1.5)
    ax.add_patch(boundary)
    ax.text(5.25, 11.3, "SoilGood System", ha="center", fontsize=12,
            color=DARK, style="italic")

    # Actors
    draw_stickman(ax, 1.3, 6, "Farmer")
    draw_stickman(ax, 9.2, 6, "Administrator")

    # ---- Farmer use cases (left column inside system) ----
    farmer_cases = [
        "Register account",
        "Sign in / out",
        "Onboard farm",
        "Claim ESP32 sensor",
        "Monitor soil & weather",
        "View AI advice",
        "View analytics",
        "Manage crops & watering",
        "View notifications",
    ]
    # Vertically distribute
    y_values = [10.5, 9.3, 8.1, 6.9, 5.7, 4.5, 3.3, 2.1, 0.9 + 0.2]
    for case, y in zip(farmer_cases, y_values):
        left, right, cy = draw_use_case(ax, 4.1, y, case, width=2.7,
                                         height=0.6)
        # Connect farmer's right arm/body to left edge of the ellipse
        connect(ax, 1.85, 6, left, cy)

    # ---- Admin use cases (right column inside system) ----
    admin_cases = [
        "Admin sign in",
        "Provision ESP32 kits",
        "Generate claim codes",
        "Flash firmware",
    ]
    y_admin = [8.6, 6.9, 5.2, 3.5]
    for case, y in zip(admin_cases, y_admin):
        left, right, cy = draw_use_case(ax, 6.75, y, case, width=2.5,
                                         height=0.6)
        # Connect admin's left side to right edge of ellipse
        connect(ax, 8.65, 6, right, cy)

    plt.tight_layout(pad=0.5)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    plt.savefig(OUT, facecolor=BG, dpi=130, bbox_inches="tight")
    plt.close(fig)
    print(f"Wrote {OUT}")


if __name__ == "__main__":
    build()
