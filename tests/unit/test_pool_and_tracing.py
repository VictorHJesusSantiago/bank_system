"""Pool de conexões e tracing distribuído."""

import sqlite3
import threading

import pytest

from bank_core import BankDatabase, LedgerService
from bank_observability import TRACER, correlation


@pytest.fixture
def db(tmp_path):
    database = BankDatabase(tmp_path / "pool.db")
    yield database
    database.close_pool()


def test_pool_reuses_the_same_connection(db):
    with db.connect() as con:
        first = id(con)
    with db.connect() as con:
        assert id(con) == first


def test_pool_respects_its_size(tmp_path):
    database = BankDatabase(tmp_path / "sized.db", pool_size=2)
    try:
        a, b, c = database.connect(), database.connect(), database.connect()
        for connection in (a, b, c):
            database._release(connection)
        assert len(database._idle()) == 2
    finally:
        database.close_pool()


def test_pool_size_zero_disables_pooling(tmp_path):
    database = BankDatabase(tmp_path / "nopool.db", pool_size=0)
    with database.connect() as con:
        first = id(con)
    with database.connect() as con:
        assert id(con) != first


def test_connection_with_open_transaction_is_never_returned_to_the_pool(db):
    """Conexão suja envenenaria o próximo tomador."""
    connection = db.connect()
    connection.execute("BEGIN")
    assert connection.in_transaction
    db._release(connection)
    assert db._idle() == []
    with pytest.raises(sqlite3.ProgrammingError):
        connection.execute("SELECT 1")


def test_failed_transaction_rolls_back_and_connection_stays_usable(db):
    ledger = LedgerService(db)
    ledger.create_account("5001", "dono", initial_balance="10")
    with pytest.raises(RuntimeError):
        with db.transaction() as con:
            con.execute("UPDATE customer_accounts SET ledger_balance_cents=999")
            raise RuntimeError("falha no meio da transação")
    assert ledger.account("5001")["ledger_balance_cents"] == 1000
    with db.connect() as con:
        assert con.execute("SELECT 1").fetchone()[0] == 1


def test_pool_is_per_thread(db):
    """Conexão SQLite não deve atravessar threads mesmo com check_same_thread."""
    with db.connect() as con:
        main_connection = id(con)
    seen: list[int] = []

    def worker() -> None:
        with db.connect() as con:
            seen.append(id(con))

    thread = threading.Thread(target=worker)
    thread.start()
    thread.join()
    assert seen and seen[0] != main_connection


def test_vacuum_still_works_with_a_populated_pool(db):
    """`repair()` faz VACUUM: no Windows, qualquer handle aberto o impediria."""
    ledger = LedgerService(db)
    ledger.create_account("5002", "dono", initial_balance="50")
    with db.connect():
        pass
    assert db.repair()["ok"]


def test_backup_works_with_a_populated_pool(db, tmp_path):
    LedgerService(db).create_account("5003", "dono", initial_balance="50")
    destination = db.backup(tmp_path / "copia.db")
    assert destination.exists() and destination.stat().st_size > 0


def test_spans_nest_and_share_the_trace(db):
    TRACER.reset()
    with correlation("pedido-42"):
        with TRACER.start("caso.de.uso", operacao="transferencia"):
            LedgerService(db).create_account("5004", "dono", initial_balance="10")
    spans = {span.name: span for span in TRACER.finished_spans()}
    assert "ledger.post" in spans and "caso.de.uso" in spans
    ledger_span, use_case = spans["ledger.post"], spans["caso.de.uso"]
    assert ledger_span.trace_id == use_case.trace_id
    assert ledger_span.parent_id == use_case.span_id
    assert use_case.parent_id is None
    assert ledger_span.status == "OK" and ledger_span.duration_ms >= 0


def test_span_records_failure_without_swallowing_it():
    TRACER.reset()
    with pytest.raises(ValueError):
        with TRACER.start("operacao.que.falha"):
            raise ValueError("erro de domínio")
    span = TRACER.finished_spans()[-1]
    assert span.status == "ERROR" and span.attributes["error.type"] == "ValueError"


def test_export_shape_matches_otel_fields():
    TRACER.reset()
    with TRACER.start("x", atributo="v"):
        pass
    exported = TRACER.export()[0]
    assert set(exported) == {
        "name",
        "trace_id",
        "span_id",
        "parent_span_id",
        "duration_ms",
        "status",
        "attributes",
    }
