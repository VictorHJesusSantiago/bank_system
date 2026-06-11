import json

import pytest

import bank_export as be

PIPE_LINE = "20240115 | DEP | Deposito em conta | R$ 100,00 | E"


@pytest.fixture
def sample_records():
    return be.parse_extrato_lines(PIPE_LINE)


@pytest.mark.unit
def test_fmt_date_valid():
    assert be._fmt_date("20240115") == "15/01/2024"


@pytest.mark.unit
def test_fmt_date_invalid_passthrough():
    assert be._fmt_date("abc") == "abc"


@pytest.mark.unit
def test_fmt_time_valid():
    assert be._fmt_time("143005") == "14:30:05"


@pytest.mark.unit
def test_fmt_time_invalid_passthrough():
    assert be._fmt_time("") == ""


@pytest.mark.unit
def test_parse_extrato_lines_pipe_format(sample_records):
    assert len(sample_records) == 1
    record = sample_records[0]
    assert record["data"] == "20240115"
    assert record["tipo"] == "DEP"
    assert record["valor"] == "R$ 100,00"
    assert record["status"] == "E"
    assert record["descricao"] == "Deposito em conta"


@pytest.mark.unit
def test_parse_extrato_lines_skips_blank_and_unrecognized():
    text = "\n   \nlinha sem padrao reconhecido\n"
    assert be.parse_extrato_lines(text) == []


@pytest.mark.unit
def test_humanize(sample_records):
    rows = be._humanize(sample_records)
    assert rows == [["15/01/2024", "", "Deposito", "R$ 100,00", "Efetivada", "Deposito em conta"]]


@pytest.mark.component
def test_export_csv(tmp_path, sample_records):
    path = tmp_path / "extrato.csv"
    assert be.export_csv(sample_records, path) is True
    content = path.read_text(encoding="utf-8-sig")
    assert ";".join(be.HEADERS) in content
    assert "Deposito em conta" in content


@pytest.mark.component
def test_export_txt(tmp_path, sample_records):
    path = tmp_path / "extrato.txt"
    assert be.export_txt(sample_records, path) is True
    content = path.read_text(encoding="utf-8")
    assert "EXTRATO BANCARIO" in content


@pytest.mark.component
def test_export_json(tmp_path, sample_records):
    path = tmp_path / "extrato.json"
    assert be.export_json(sample_records, path) is True
    payload = json.loads(path.read_text(encoding="utf-8"))
    assert payload["total_transacoes"] == 1
    assert payload["transacoes"][0]["tipo"] == "DEP"


@pytest.mark.component
def test_export_xml(tmp_path, sample_records):
    path = tmp_path / "extrato.xml"
    assert be.export_xml(sample_records, path) is True
    content = path.read_text(encoding="utf-8")
    assert content.startswith('<?xml version="1.0" encoding="UTF-8"?>')
    assert "<extrato " in content
    assert "<tipo>DEP</tipo>" in content


@pytest.mark.component
def test_export_html(tmp_path, sample_records):
    path = tmp_path / "extrato.html"
    assert be.export_html(sample_records, path) is True
    content = path.read_text(encoding="utf-8")
    assert "<table>" in content
    assert "Deposito" in content


@pytest.mark.component
def test_export_markdown(tmp_path, sample_records):
    path = tmp_path / "extrato.md"
    assert be.export_markdown(sample_records, path) is True
    content = path.read_text(encoding="utf-8")
    assert content.startswith("# Extrato Bancário")
    assert "Deposito em conta" in content


@pytest.mark.component
@pytest.mark.skipif(not be.HAS_EXCEL, reason="openpyxl nao instalado")
def test_export_excel(tmp_path, sample_records):
    path = tmp_path / "extrato.xlsx"
    assert be.export_excel(sample_records, path) is True
    assert path.exists()


@pytest.mark.component
@pytest.mark.skipif(not be.HAS_PDF, reason="fpdf nao instalado")
def test_export_pdf(tmp_path, sample_records):
    path = tmp_path / "extrato.pdf"
    assert be.export_pdf(sample_records, path) is True
    assert path.exists()


@pytest.mark.component
def test_export_formats_unknown_format(tmp_path, sample_records):
    results = be.export_formats(sample_records, ["csv", "inexistente"], tmp_path)
    assert results["csv"] is True
    assert results["inexistente"] is False


@pytest.mark.system
def test_export_all(tmp_path, sample_records):
    results = be.export_all(sample_records, tmp_path, stem="extrato_full")
    for fmt in be.AVAILABLE_FORMATS:
        if fmt == "xlsx" and not be.HAS_EXCEL:
            continue
        if fmt == "pdf" and not be.HAS_PDF:
            continue
        assert results[fmt] is True
        assert (tmp_path / f"extrato_full.{fmt}").exists()
