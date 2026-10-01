from __future__ import annotations

import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    BaseDocTemplate,
    Frame,
    HRFlowable,
    LongTable,
    PageTemplate,
    Paragraph,
    Preformatted,
    Spacer,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "docs"
OUT = ROOT / "output" / "pdf"

FILES = {
    DOCS / "URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2.md": OUT
    / "URITECT_Sex_Specific_Bayesian_UTI_Specification_v1.2.pdf",
    DOCS / "URITECT_Bayesian_Parameter_Validation_Form_v1.3.md": OUT
    / "URITECT_Bayesian_Parameter_Validation_Form_v1.3.pdf",
    DOCS / "URITECT_Bayesian_Review_Cover_Letter_v1.3.md": OUT
    / "URITECT_Bayesian_Review_Cover_Letter_v1.3.pdf",
}

NAVY = colors.HexColor("#153B50")
TEAL = colors.HexColor("#087E8B")
PALE = colors.HexColor("#EAF5F6")
GRID = colors.HexColor("#AFC4CA")
TEXT = colors.HexColor("#26343B")
MUTED = colors.HexColor("#5E6C73")


def _styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=18,
            leading=22,
            textColor=NAVY,
            alignment=TA_CENTER,
            spaceAfter=10,
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=12,
            leading=15,
            textColor=NAVY,
            spaceBefore=9,
            spaceAfter=5,
            keepWithNext=True,
        ),
        "h3": ParagraphStyle(
            "H3",
            parent=base["Heading3"],
            fontName="Helvetica-Bold",
            fontSize=10.5,
            leading=13,
            textColor=TEAL,
            spaceBefore=7,
            spaceAfter=4,
            keepWithNext=True,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=12.5,
            textColor=TEXT,
            spaceAfter=6,
        ),
        "bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=9,
            leading=12,
            leftIndent=12,
            firstLineIndent=-7,
            textColor=TEXT,
            spaceAfter=3,
        ),
        "table": ParagraphStyle(
            "Table",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=7.7,
            leading=9.5,
            textColor=TEXT,
        ),
        "table_head": ParagraphStyle(
            "TableHead",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=7.7,
            leading=9.5,
            textColor=colors.white,
        ),
        "code": ParagraphStyle(
            "Code",
            fontName="Courier",
            fontSize=7.8,
            leading=10,
            textColor=TEXT,
            leftIndent=8,
            rightIndent=8,
            spaceBefore=3,
            spaceAfter=7,
            backColor=colors.HexColor("#F2F5F6"),
            borderPadding=6,
        ),
    }


def _inline(text: str) -> str:
    text = text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"(?<!\*)\*([^*]+?)\*(?!\*)", r"<i>\1</i>", text)
    text = re.sub(r"`(.+?)`", r"<font name='Courier'>\1</font>", text)
    return text


def _table(rows: list[list[str]], styles, width: float):
    count = max(len(row) for row in rows)
    normalized = [row + [""] * (count - len(row)) for row in rows]
    data = []
    for row_index, row in enumerate(normalized):
        style = styles["table_head"] if row_index == 0 else styles["table"]
        data.append([Paragraph(_inline(cell.strip()), style) for cell in row])
    header = normalized[0][0].strip().lower()
    if header == "parameter id" and count == 6:
        widths = [width * 0.12, width * 0.08, width * 0.08, width * 0.08, width * 0.08, width * 0.56]
    elif count == 2:
        widths = [width * 0.68, width * 0.32]
    elif count == 3:
        widths = [width * 0.43, width * 0.18, width * 0.39]
    elif count >= 6:
        widths = [width * 0.07, width * 0.47] + [width * 0.07] * 4
        if count > 6:
            widths += [width - sum(widths)]
    else:
        widths = [width / count] * count
    table = LongTable(data, colWidths=widths[:count], repeatRows=1, hAlign="LEFT")
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), NAVY),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("GRID", (0, 0), (-1, -1), 0.35, GRID),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, PALE]),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table


def _parse(md: str, styles, width: float):
    lines = md.splitlines()
    story = []
    paragraph: list[str] = []
    index = 0

    def flush():
        if paragraph:
            story.append(Paragraph(_inline(" ".join(paragraph)), styles["body"]))
            paragraph.clear()

    while index < len(lines):
        line = lines[index].rstrip()
        if line.startswith("```"):
            flush()
            code = []
            index += 1
            while index < len(lines) and not lines[index].startswith("```"):
                code.append(lines[index])
                index += 1
            story.append(Preformatted("\n".join(code), styles["code"]))
        elif line.startswith("| "):
            flush()
            raw_rows = []
            while index < len(lines) and lines[index].startswith("|"):
                raw_rows.append([cell.strip() for cell in lines[index].strip().strip("|").split("|")])
                index += 1
            if len(raw_rows) > 1 and all(re.fullmatch(r"[-: ]+", cell) for cell in raw_rows[1]):
                raw_rows.pop(1)
            story.append(_table(raw_rows, styles, width))
            story.append(Spacer(1, 6))
            continue
        elif line.startswith("# "):
            flush()
            story.append(Paragraph(_inline(line[2:]), styles["title"]))
            story.append(HRFlowable(width="100%", thickness=1.2, color=TEAL, spaceAfter=8))
        elif line.startswith("## "):
            flush()
            story.append(Paragraph(_inline(line[3:]), styles["h2"]))
        elif line.startswith("### "):
            flush()
            story.append(Paragraph(_inline(line[4:]), styles["h3"]))
        elif line.startswith("- "):
            flush()
            bullet = line[2:].strip()
            while index + 1 < len(lines) and lines[index + 1].startswith("  "):
                index += 1
                bullet += " " + lines[index].strip()
            story.append(Paragraph("&#8226; " + _inline(bullet), styles["bullet"]))
        elif not line.strip():
            flush()
        else:
            paragraph.append(line.strip().replace("  ", " "))
        index += 1
    flush()
    return story


def _page(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 7.5)
    canvas.setFillColor(MUTED)
    canvas.drawString(18 * mm, 12 * mm, "URITECT - Research use; not a diagnosis")
    canvas.drawRightString(A4[0] - 18 * mm, 12 * mm, f"Page {doc.page}")
    canvas.setStrokeColor(GRID)
    canvas.line(18 * mm, 16 * mm, A4[0] - 18 * mm, 16 * mm)
    canvas.restoreState()


def build(source: Path, target: Path):
    styles = _styles()
    margin = 18 * mm
    frame = Frame(margin, 20 * mm, A4[0] - 2 * margin, A4[1] - 35 * mm, id="main")
    doc = BaseDocTemplate(
        str(target),
        pagesize=A4,
        leftMargin=margin,
        rightMargin=margin,
        topMargin=15 * mm,
        bottomMargin=20 * mm,
        title=source.stem,
        author="URITECT Research Team",
    )
    doc.addPageTemplates(PageTemplate(id="standard", frames=[frame], onPage=_page))
    story = _parse(source.read_text(encoding="utf-8"), styles, A4[0] - 2 * margin)
    doc.build(story)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for source, target in FILES.items():
        build(source, target)
        print(target)


if __name__ == "__main__":
    main()
