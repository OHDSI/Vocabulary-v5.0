"""This script outputs a picture of a treemap of the UKDE deletion data."""
import matplotlib.pyplot as plt
import squarify
import pandas as pd
import numpy as np

CATEGORY_CSS_COLORS: dict[str, list[str]] = {
        # Shades of dark grey for Invalid
        "Invalid": ["#000000", "#111111", "#222222", "#333333", "#444444"],
        # Orange for Drugs
        "Drug": ["#FFA500", "#FFB000", "#FFC000", "#FFD000", "#FFE000"],
        # Blue for Devices
        "Device": ["#0000FF", "#0000EE", "#0000DD", "#0000CC", "#0000BB"],
        # Green for Metadata
        "Metadata": ["#00FF00", "#00EE00", "#00DD00", "#00CC00", "#00BB00"],
    }

cnt = str
lbl = str
shorthand = str

DATA: list[list[cnt, lbl, shorthand]] = [
        [139515,"Total invalid concepts","Invalid"],
        [179276,"Total concepts in Drug domain","Drug"],
        [176623,"Total concepts in Drug domain matching dm+d concepts","Drug/dmd now"],
        [224,"Total concepts in Drug domain matching dm+d sources, but not existing concepts","Drug/dmd next"],
        [186700,"Standard concepts in Device domain matching dm+d concepts","Device/dmd_standard"],
        [2,"Non-standard concepts in Device domain matching dm+d concepts","Device/dmd_nonstandard"],
        [4,"Total concepts in Device domain that are not in dm+d, but have dm+d sources","Device/dmd_next"],
        [19,"Standard concepts in Route domain","Metadata/Standard Route"],
        [3903,"Other domains and Non-standard Routes","Metadata/Other"],
        [188988,"Total concepts in Device domain","Device"],
    ]

df: pd.DataFrame = pd.DataFrame(DATA, columns=["Count", "Label", "Shorthand"])

# If a Category has multiple Shorthands, add Category/Other rows
categories: list[str] = list(CATEGORY_CSS_COLORS.keys())
categories_subcategories: dict[str, list[str]] = {}
for category in categories:
    categories_subcategories[category] = []
    for shorthand in df["Shorthand"]:
        if shorthand.startswith(category+'/'):
            categories_subcategories[category].append(shorthand.split('/')[1])

rows: list[dict[str, str | int]] = []
for category in categories:
    if (
        categories_subcategories[category] and
        not 'Other' in categories_subcategories[category]
    ):
        categories_subcategories[category].append('Other')
        cnt_total, lbl_total = df.loc[
                df["Shorthand"]==category,
                ["Count", "Label"]
            ].values[0]

        cnt_subcategories = (df.loc[
            df["Shorthand"].str.startswith(category + '/'),
            "Count"
        ].sum())

        row = {
            "Count": int(cnt_total) - int(cnt_subcategories),
            "Label": lbl_total + ", other",
            "Shorthand": category+"/Other"
        }
        rows.append(row)

        # Remove 'Total' row
        df = df.loc[df["Shorthand"] != category]

df = pd.concat([df, pd.DataFrame(rows)], ignore_index=True)

df["Normalized"] = squarify.normalize_sizes(df["Count"], 480, 360)
df.sort_values(by=["Shorthand"], inplace=True)

print(df[["Label", "Count"]].to_markdown(index=False))

# Assign colors to Shorthands by Category
_colors_copy = CATEGORY_CSS_COLORS.copy()
colors: dict[str, str] = {
        row["Shorthand"]: _colors_copy[row["Shorthand"].split('/')[0]].pop()
        for _, row in df.iterrows()

    }

df.sort_values(by=["Count"], inplace=True, ascending=False)
fig, ax = plt.subplots(figsize=(12, 9))
ax.axis("off")
ax.set_title("UKDE Deletion Data", fontsize=16, fontweight="bold")
squarify.plot(
    sizes = df["Normalized"],
    norm_x = 480,
    norm_y = 360,
    color = [colors[shorthand] for shorthand in df["Shorthand"]],
    label = df["Label"],
    value = df["Count"],
    ax = ax,
)

plt.show()

# Export as navigable SVG
fig.savefig("ukde_deletion_treemap.svg", format="svg", bbox_inches="tight")
