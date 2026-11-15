# Converts task1.html / task2.html (the lab 10 reports) to Word documents with python-docx.
# Usage: python build_docx.py            (needs: pip install python-docx beautifulsoup4)
# Diagrams are embedded as PNG from diagrams/out; pages that hold a diagram are landscape sections.
import os
import re
import sys

from bs4 import BeautifulSoup, NavigableString, Tag
from docx import Document
from docx.enum.section import WD_ORIENT, WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Mm, Pt, RGBColor

HERE = os.path.dirname(os.path.abspath(__file__))
NAVY = RGBColor(0x1B, 0x3A, 0x5C)
BODY_FONT, CODE_FONT = "Times New Roman", "Consolas"
A4_W, A4_H = Mm(210), Mm(297)
MARGIN_P, MARGIN_L = Mm(18), Mm(13)


def set_font(run, name, size=None):
    run.font.name = name
    rpr = run._element.get_or_add_rPr()
    fonts = rpr.find(qn("w:rFonts"))
    if fonts is None:
        fonts = OxmlElement("w:rFonts")
        rpr.append(fonts)
    for attr in ("w:ascii", "w:hAnsi", "w:cs", "w:eastAsia"):
        fonts.set(qn(attr), name)
    if size:
        run.font.size = size


def shade(cell, color):
    tcpr = cell._element.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), color)
    tcpr.insert_element_before(shd, "w:noWrap", "w:tcMar", "w:textDirection", "w:tcFitText", "w:vAlign", "w:hideMark")


def bottom_border(paragraph, color="1B3A5C"):
    ppr = paragraph._element.get_or_add_pPr()
    borders = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    for key, value in (("w:val", "single"), ("w:sz", "8"), ("w:space", "1"), ("w:color", color)):
        bottom.set(qn(key), value)
    borders.append(bottom)
    # schema order: pBdr must precede shd/tabs/spacing/ind/jc/outlineLvl/rPr
    ppr.insert_element_before(borders, "w:shd", "w:tabs", "w:suppressAutoHyphens", "w:kinsoku", "w:wordWrap",
                              "w:overflowPunct", "w:topLinePunct", "w:autoSpaceDE", "w:autoSpaceDN", "w:bidi",
                              "w:adjustRightInd", "w:snapToGrid", "w:spacing", "w:ind", "w:contextualSpacing",
                              "w:mirrorIndents", "w:suppressOverlap", "w:jc", "w:textDirection",
                              "w:textAlignment", "w:textboxTightWrap", "w:outlineLvl", "w:divId",
                              "w:cnfStyle", "w:rPr", "w:sectPr", "w:pPrChange")


def add_inline(paragraph, node, size, bold=False, italic=False, code=False, color=None):
    """Append the inline content of an HTML node to a paragraph, keeping bold / italic / code."""
    if isinstance(node, NavigableString):
        text = re.sub(r"\s+", " ", str(node))
        if not text:
            return
        run = paragraph.add_run(text)
        set_font(run, CODE_FONT if code else BODY_FONT, Pt(size.pt - 1.5) if code else size)
        run.bold, run.italic = bold or None, italic or None
        if color is not None:
            run.font.color.rgb = color
        return
    if node.name == "br":
        paragraph.add_run().add_break()
        return
    for child in node.children:
        add_inline(paragraph, child, size,
                   bold or node.name in ("b", "strong", "th"),
                   italic or node.name in ("i", "em"),
                   code or node.name == "code", color)


def trim(paragraph):
    """Drop leading/trailing whitespace left over from HTML indentation."""
    runs = paragraph.runs
    if runs:
        runs[0].text = runs[0].text.lstrip()
        runs[-1].text = runs[-1].text.rstrip()


class Builder:
    def __init__(self):
        self.doc = Document()
        self.landscape = False
        normal = self.doc.styles["Normal"]
        normal.font.name = BODY_FONT
        normal.font.size = Pt(12.5)
        normal.element.rPr.rFonts.set(qn("w:eastAsia"), BODY_FONT)
        normal.paragraph_format.space_after = Pt(6)
        normal.paragraph_format.line_spacing = 1.2
        self._page(self.doc.sections[0], False)
        zoom = self.doc.settings.element.find(qn("w:zoom"))
        if zoom is not None:  # python-docx's template omits the required attribute
            zoom.set(qn("w:percent"), "100")
        self.doc.core_properties.author = "Trương Đắc Kiên - 2424802010029"

    # ----- page layout -----
    def _page(self, section, landscape):
        section.orientation = WD_ORIENT.LANDSCAPE if landscape else WD_ORIENT.PORTRAIT
        section.page_width, section.page_height = (A4_H, A4_W) if landscape else (A4_W, A4_H)
        margin = MARGIN_L if landscape else MARGIN_P
        section.left_margin = section.right_margin = margin
        section.top_margin = section.bottom_margin = Mm(12) if landscape else Mm(17)

    def orient(self, landscape):
        """Start a new page in the wanted orientation."""
        section = self.doc.add_section(WD_SECTION.NEW_PAGE)
        self._page(section, landscape)
        self.landscape = landscape

    @property
    def width(self):
        section = self.doc.sections[-1]
        return section.page_width - section.left_margin - section.right_margin

    # ----- blocks -----
    def paragraph(self, node, size=Pt(12.5), align=WD_ALIGN_PARAGRAPH.JUSTIFY, style=None, after=6):
        p = self.doc.add_paragraph(style=style)
        add_inline(p, node, size)
        trim(p)
        p.alignment = align
        p.paragraph_format.space_after = Pt(after)
        return p

    def heading(self, node, level):
        p = self.doc.add_paragraph()
        size = {1: Pt(18), 2: Pt(14.5), 3: Pt(12.5)}[level]
        add_inline(p, node, size, bold=True, color=None if level == 1 else NAVY)
        trim(p)
        fmt = p.paragraph_format
        fmt.keep_with_next = True
        if level == 1:
            p.alignment = WD_ALIGN_PARAGRAPH.CENTER
            fmt.space_before, fmt.space_after = Pt(4), Pt(6)
        elif level == 2:
            fmt.space_before, fmt.space_after = Pt(14), Pt(6)
            bottom_border(p)
        else:
            fmt.space_before, fmt.space_after = Pt(8), Pt(4)
        # outline level so Word's navigation pane / TOC can see the headings
        ppr = p._element.get_or_add_pPr()
        outline = OxmlElement("w:outlineLvl")
        outline.set(qn("w:val"), str(level - 1))
        ppr.insert_element_before(outline, "w:divId", "w:cnfStyle", "w:rPr", "w:sectPr", "w:pPrChange")

    def list(self, node):
        style = "List Number" if node.name == "ol" else "List Bullet"
        for li in node.find_all("li", recursive=False):
            self.paragraph(li, style=style, after=3)

    def table(self, node, size=Pt(10)):
        rows = node.find_all("tr")
        header = rows[0].find_all(["th", "td"])
        cols = len(header)
        weights = []
        for cell in header:
            match = re.search(r"width:\s*([\d.]+)%", cell.get("style", ""))
            weights.append(float(match.group(1)) if match else None)
        rest = max(100 - sum(w for w in weights if w), 5)
        missing = weights.count(None)
        weights = [w if w else rest / missing for w in weights]
        total = sum(weights)
        table = self.doc.add_table(rows=len(rows), cols=cols)
        table.style = "Table Grid"
        table.alignment = WD_TABLE_ALIGNMENT.CENTER
        table.autofit = False
        for r, tr in enumerate(rows):
            for c, cell_node in enumerate(tr.find_all(["th", "td"])):
                cell = table.cell(r, c)
                cell.width = int(self.width * weights[c] / total)
                p = cell.paragraphs[0]
                is_head = cell_node.name == "th"
                add_inline(p, cell_node, size, bold=is_head, color=RGBColor(0xFF, 0xFF, 0xFF) if is_head else None)
                trim(p)
                p.alignment = WD_ALIGN_PARAGRAPH.LEFT
                p.paragraph_format.space_after = Pt(1)
                p.paragraph_format.line_spacing = 1.05
                if is_head:
                    shade(cell, "1B3A5C")
                elif r % 2 == 0:
                    shade(cell, "F4F7FA")
            if r == 0:  # repeat the header row on every page
                trpr = table.rows[0]._tr.get_or_add_trPr()
                trpr.append(OxmlElement("w:tblHeader"))
            table.rows[r]._tr.get_or_add_trPr().insert(0, OxmlElement("w:cantSplit"))
        self.doc.add_paragraph().paragraph_format.space_after = Pt(2)

    def figure(self, node, reserve_mm):
        from PIL import Image
        src = node.find("img")["src"]
        path = os.path.join(HERE, re.sub(r"\.svg$", ".png", src))
        with Image.open(path) as image:
            ratio = image.height / image.width
        section = self.doc.sections[-1]
        max_h = section.page_height - section.top_margin - section.bottom_margin - Mm(reserve_mm)
        width = self.width
        if width * ratio > max_h:
            width = int(max_h / ratio)
        p = self.doc.add_paragraph()
        p.alignment = WD_ALIGN_PARAGRAPH.CENTER
        p.paragraph_format.space_after = Pt(2)
        p.paragraph_format.keep_with_next = True
        p.add_run().add_picture(path, width=width)
        caption = node.find("figcaption")
        if caption:
            c = self.doc.add_paragraph()
            add_inline(c, caption, Pt(10.5), italic=True)
            trim(c)
            c.alignment = WD_ALIGN_PARAGRAPH.CENTER
            c.paragraph_format.space_after = Pt(4)

    def cover(self, node):
        for child in node.find_all(recursive=False):
            classes = child.get("class", [])
            if child.name == "h1":
                self.heading(child, 1)
            elif child.name == "table":
                for tr in child.find_all("tr"):
                    cells = tr.find_all("td")
                    p = self.doc.add_paragraph()
                    add_inline(p, cells[0], Pt(12), bold=True)
                    trim(p)
                    p.add_run(": ")
                    add_inline(p, cells[1], Pt(12))
                    p.paragraph_format.space_after = Pt(1)
                    p.paragraph_format.left_indent = Cm(2.5)
                self.doc.add_paragraph().paragraph_format.space_after = Pt(0)
            else:
                size = Pt(12) if "school" in classes else Pt(13)
                p = self.paragraph(child, size=size, align=WD_ALIGN_PARAGRAPH.CENTER, after=2)
                if "school" in classes:
                    for run in p.runs:
                        run.text = run.text.upper()

    def note(self, node):
        table = self.doc.add_table(rows=1, cols=1)
        table.style = "Table Grid"
        cell = table.cell(0, 0)
        shade(cell, "FFFBEA")
        p = cell.paragraphs[0]
        add_inline(p, node, Pt(11))
        trim(p)
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY

    # ----- dispatch -----
    def block(self, node, in_wide=False, reserve_mm=30):
        if not isinstance(node, Tag):
            return
        classes = node.get("class", [])
        if self.landscape and not in_wide and node.name != "section":
            self.orient(False)  # back to portrait only when ordinary content follows a diagram page
        if node.name == "div" and "cover" in classes:
            self.cover(node)
        elif node.name == "div" and "note" in classes:
            self.note(node)
        elif node.name in ("h2", "h3"):
            if node.name == "h2" and "newpage" in classes:
                self.doc.add_page_break()
            self.heading(node, int(node.name[1]))
        elif node.name == "p":
            self.paragraph(node, size=Pt(11) if in_wide else Pt(12.5), after=4 if in_wide else 6)
        elif node.name in ("ul", "ol"):
            self.list(node)
        elif node.name == "table":
            self.table(node)
        elif node.name == "figure":
            self.figure(node, reserve_mm)
        elif node.name == "section":
            self.orient(True)
            children = [c for c in node.children if isinstance(c, Tag)]
            # leave room on the page for the heading, caption and explanation that share it
            text_len = sum(len(c.get_text()) for c in children if c.name == "p")
            reserve = 26 + 9 * sum(1 for c in children if c.name in ("h2", "h3")) + text_len / 150 * 5.2
            for child in children:
                self.block(child, in_wide=True, reserve_mm=reserve)


def convert(source, target):
    with open(os.path.join(HERE, source), encoding="utf-8") as handle:
        soup = BeautifulSoup(handle.read(), "html.parser")
    builder = Builder()
    builder.doc.core_properties.title = soup.title.get_text()
    for node in soup.body.children:
        builder.block(node)
    out = os.path.join(HERE, target)
    builder.doc.save(out)
    print("built", target)


if __name__ == "__main__":
    convert("task1.html", "BTH10-Task1-Kien-truc-tong-quat-2424802010029.docx")
    convert("task2.html", "BTH10-Task2-Kien-truc-4-khung-nhin-2424802010029.docx")
