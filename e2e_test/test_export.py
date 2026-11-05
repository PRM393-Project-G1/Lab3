"""Flow C: exporting the report. On the Spark plan the PDF stays on the device."""

import re

from realtron import PAPER_ID, PAPER_TITLE, open_paper


async def test_tc09_report_is_created_and_saved(agent, logged):
    data = await agent.check(
        f"{open_paper()} Tap 'Report' in the app bar. Wait until the sheet stops "
        "showing 'Creating PDF…'.",
        "status (string, the line under the icon), "
        "file_line (string, the line with the file name and size), "
        "buttons (list of button labels in the sheet)",
    )
    assert data["status"] == "Saved on device"
    assert re.fullmatch(rf"realtron_{re.escape(PAPER_ID)}\.pdf · \d+ KB", data["file_line"])
    assert data["buttons"] == ["Open", "Share"]
    assert logged("export_report")


async def test_tc19_saved_report_opens_in_a_pdf_app(agent):
    data = await agent.check(
        f"{open_paper()} Tap 'Report' in the app bar. When 'Saved on device' shows, "
        "tap 'Open'. If Android asks which app to use, choose any PDF viewer. "
        "Read the first page of the PDF.",
        "pdf_visible (boolean), paper_title (string, the paper title in the PDF), "
        "arxiv_line (string, the line starting with 'arXiv:')",
    )
    assert data["pdf_visible"] is True
    assert PAPER_TITLE in data["paper_title"]
    assert data["arxiv_line"] == f"arXiv:{PAPER_ID}"
