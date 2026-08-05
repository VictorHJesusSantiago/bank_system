"""Os três pilares de observabilidade: logs, métricas e traces.

Doze fatores, XI: logs são fluxo de eventos em stdout, não arquivos gerenciados
pela aplicação. Cada registro é uma linha JSON com campos estáveis, para que a
agregação não dependa de parsing de texto livre.

Métricas usam percentis (p50/p95/p99), nunca médias, e traces seguem o modelo do
OpenTelemetry sem acrescentar dependência — ver ``Tracer``. Os três compartilham
o mesmo ``correlation_id``, então uma investigação salta entre eles sem perder o
fio.
"""

from __future__ import annotations

import json
import logging
import os
import secrets
import sys
import threading
import time
import uuid
from contextlib import contextmanager
from datetime import UTC, datetime
from functools import wraps
from typing import Any, Iterator

_RESERVED = {
    "args",
    "asctime",
    "created",
    "exc_info",
    "exc_text",
    "filename",
    "funcName",
    "levelname",
    "levelno",
    "lineno",
    "module",
    "msecs",
    "message",
    "msg",
    "name",
    "pathname",
    "process",
    "processName",
    "relativeCreated",
    "stack_info",
    "thread",
    "threadName",
    "taskName",
}

REDACTED_FIELDS = {
    "password",
    "senha",
    "token",
    "refresh_token",
    "secret",
    "client_secret",
    "pan",
    "cvv",
    "cpf",
    "cnpj",
    "document",
    "email",
    "phone",
    "totp_secret",
    "private_key",
    "master_key",
    "duress",
    "key_value",
}
REDACTED = "***"

_context = threading.local()


class JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.fromtimestamp(record.created, UTC).isoformat(),
            "level": record.levelname,
            "service": os.environ.get("BANK_SERVICE_NAME", "bank-core"),
            "event": record.getMessage(),
            "logger": record.name,
        }
        correlation = getattr(_context, "correlation_id", None)
        if correlation:
            payload["correlation_id"] = correlation
        for key, value in record.__dict__.items():
            if key in _RESERVED or key.startswith("_"):
                continue
            payload[key] = REDACTED if key.lower() in REDACTED_FIELDS else value
        if record.exc_info:
            payload["exception"] = self.formatException(record.exc_info)
        return json.dumps(payload, ensure_ascii=False, sort_keys=True, default=str)


def get_logger(name: str = "bank") -> logging.Logger:
    logger = logging.getLogger(name)
    if not logger.handlers:
        handler = logging.StreamHandler(sys.stdout)
        handler.setFormatter(JsonFormatter())
        logger.addHandler(handler)
        logger.setLevel(os.environ.get("BANK_LOG_LEVEL", "INFO").upper())
        logger.propagate = False
    return logger


@contextmanager
def correlation(correlation_id: str | None = None) -> Iterator[str]:
    """Propaga um identificador por todos os logs emitidos no bloco."""
    previous = getattr(_context, "correlation_id", None)
    _context.correlation_id = correlation_id or str(uuid.uuid4())
    try:
        yield _context.correlation_id
    finally:
        _context.correlation_id = previous


def current_correlation_id() -> str | None:
    return getattr(_context, "correlation_id", None)


class Metrics:
    """Counters, gauges e histogramas em memória, expostos em texto Prometheus.

    Suficiente para o modelo de processo único deste sistema; a interface é a
    mesma que um cliente Prometheus real exporia, então trocar a implementação
    não toca os pontos de instrumentação.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._counters: dict[str, float] = {}
        self._gauges: dict[str, float] = {}
        self._histograms: dict[str, list[float]] = {}

    @staticmethod
    def _key(name: str, labels: dict[str, str] | None) -> str:
        if not labels:
            return name
        rendered = ",".join(f'{k}="{v}"' for k, v in sorted(labels.items()))
        return f"{name}{{{rendered}}}"

    def increment(self, name: str, value: float = 1, **labels: str) -> None:
        with self._lock:
            key = self._key(name, labels)
            self._counters[key] = self._counters.get(key, 0) + value

    def gauge(self, name: str, value: float, **labels: str) -> None:
        with self._lock:
            self._gauges[self._key(name, labels)] = value

    def observe(self, name: str, value: float, **labels: str) -> None:
        with self._lock:
            self._histograms.setdefault(self._key(name, labels), []).append(value)

    @contextmanager
    def timer(self, name: str, **labels: str) -> Iterator[None]:
        started = time.perf_counter()
        try:
            yield
        finally:
            self.observe(name, (time.perf_counter() - started) * 1000, **labels)

    def percentiles(self, name: str, **labels: str) -> dict[str, float]:
        """p50/p95/p99 — médias escondem exatamente a cauda que importa."""
        with self._lock:
            samples = sorted(self._histograms.get(self._key(name, labels), []))
        if not samples:
            return {}

        def at(fraction: float) -> float:
            index = min(len(samples) - 1, int(round(fraction * (len(samples) - 1))))
            return samples[index]

        return {"count": len(samples), "p50": at(0.50), "p95": at(0.95), "p99": at(0.99)}

    def snapshot(self) -> dict[str, Any]:
        with self._lock:
            return {
                "counters": dict(self._counters),
                "gauges": dict(self._gauges),
                "histograms": {key: len(values) for key, values in self._histograms.items()},
            }

    def render_prometheus(self) -> str:
        lines: list[str] = []
        with self._lock:
            counters, gauges = dict(self._counters), dict(self._gauges)
            histograms = {k: sorted(v) for k, v in self._histograms.items()}
        for key, value in sorted(counters.items()):
            lines.append(f"{key} {value}")
        for key, value in sorted(gauges.items()):
            lines.append(f"{key} {value}")
        for key, samples in sorted(histograms.items()):
            if not samples:
                continue
            base = key.split("{")[0]
            suffix = key[len(base) :]
            for label, fraction in (("0.5", 0.50), ("0.95", 0.95), ("0.99", 0.99)):
                index = min(len(samples) - 1, int(round(fraction * (len(samples) - 1))))
                inner = suffix[1:-1] + "," if suffix else ""
                lines.append(f'{base}{{{inner}quantile="{label}"}} {samples[index]}')
            lines.append(f"{base}_count{suffix} {len(samples)}")
        return "\n".join(lines) + "\n"


def _otlp_attribute(key: str, value: Any) -> dict[str, Any]:
    """Atributo no formato AnyValue do OTLP."""
    if isinstance(value, bool):
        typed: dict[str, Any] = {"boolValue": value}
    elif isinstance(value, int):
        typed = {"intValue": str(value)}
    elif isinstance(value, float):
        typed = {"doubleValue": value}
    else:
        typed = {"stringValue": str(value)}
    return {"key": key, "value": typed}


_OTLP_STATUS = {"UNSET": 0, "OK": 1, "ERROR": 2}


def _otlp_span(span: "Span") -> dict[str, Any]:
    start_ns = int(span.wall_start * 1_000_000_000)
    end_ns = start_ns + int(span.duration_ms * 1_000_000)
    payload: dict[str, Any] = {
        "traceId": span.trace_id.ljust(32, "0")[:32],
        "spanId": span.span_id.ljust(16, "0")[:16],
        "name": span.name,
        "kind": 1,
        "startTimeUnixNano": str(start_ns),
        "endTimeUnixNano": str(end_ns),
        "attributes": [_otlp_attribute(k, v) for k, v in span.attributes.items()],
        "status": {"code": _OTLP_STATUS.get(span.status, 0)},
    }
    if span.parent_id:
        payload["parentSpanId"] = span.parent_id.ljust(16, "0")[:16]
    return payload


class Span:
    """Unidade de trabalho rastreada, no modelo do OpenTelemetry.

    Campos e semântica seguem a especificação (trace_id/span_id/parent, status,
    atributos), de modo que exportar para um coletor OTel real seja trocar
    ``Tracer.export`` — não reinstrumentar o código. A implementação é própria
    para não acrescentar dependência a um sistema cujo requirements tem duas
    linhas, ambas de segurança.
    """

    __slots__ = (
        "name",
        "trace_id",
        "span_id",
        "parent_id",
        "attributes",
        "started_at",
        "wall_start",
        "ended_at",
        "status",
    )

    def __init__(
        self, name: str, trace_id: str, span_id: str, parent_id: str | None, attributes: dict[str, Any]
    ):
        self.name = name
        self.trace_id = trace_id
        self.span_id = span_id
        self.parent_id = parent_id
        self.attributes = attributes
        self.started_at = time.perf_counter()
        self.wall_start = time.time()
        self.ended_at: float | None = None
        self.status = "UNSET"

    @property
    def duration_ms(self) -> float:
        end = self.ended_at if self.ended_at is not None else time.perf_counter()
        return (end - self.started_at) * 1000

    def set_attribute(self, key: str, value: Any) -> None:
        self.attributes[key] = value

    def to_dict(self) -> dict[str, Any]:
        return {
            "name": self.name,
            "trace_id": self.trace_id,
            "span_id": self.span_id,
            "parent_span_id": self.parent_id,
            "duration_ms": round(self.duration_ms, 3),
            "status": self.status,
            "attributes": self.attributes,
        }


class Tracer:
    """Tracer em processo com propagação de contexto por thread.

    Mantém os últimos ``max_finished`` spans em memória para inspeção local e
    testes; em produção ``export`` entrega ao coletor.
    """

    def __init__(self, max_finished: int = 1000):
        self._finished: list[Span] = []
        self._max_finished = max_finished
        self._lock = threading.Lock()

    @staticmethod
    def _new_id(length: int) -> str:
        return secrets.token_hex(length)

    def current_span(self) -> Span | None:
        stack = getattr(_context, "span_stack", None)
        return stack[-1] if stack else None

    @contextmanager
    def start(self, name: str, **attributes: Any) -> Iterator[Span]:
        parent = self.current_span()
        trace_id = (
            parent.trace_id
            if parent
            else ((current_correlation_id() or "").replace("-", "")[:32] or self._new_id(16))
        )
        span = Span(name, trace_id, self._new_id(8), parent.span_id if parent else None, dict(attributes))
        stack = getattr(_context, "span_stack", None)
        if stack is None:
            stack = _context.span_stack = []
        stack.append(span)
        try:
            yield span
            span.status = "OK"
        except Exception as exc:
            span.status = "ERROR"
            span.set_attribute("error.type", type(exc).__name__)
            raise
        finally:
            span.ended_at = time.perf_counter()
            stack.pop()
            self._record(span)

    def _record(self, span: Span) -> None:
        METRICS.observe(f"span_duration_ms_{span.name}", span.duration_ms)
        LOGGER.debug("trace.span", extra=span.to_dict())
        with self._lock:
            self._finished.append(span)
            if len(self._finished) > self._max_finished:
                del self._finished[: len(self._finished) - self._max_finished]

    def finished_spans(self) -> list[Span]:
        with self._lock:
            return list(self._finished)

    def export(self) -> list[dict[str, Any]]:
        """Representação simplificada, usada por testes e inspeção local."""
        return [span.to_dict() for span in self.finished_spans()]

    def export_otlp(self, service_name: str | None = None) -> dict[str, Any]:
        """Payload no formato OTLP/HTTP JSON (`ExportTraceServiceRequest`).

        É o que um coletor OpenTelemetry aceita em ``POST /v1/traces``. Os ids
        seguem a especificação: 16 bytes hex para trace, 8 para span, e
        timestamps em nanossegundos desde a época.
        """
        service = service_name or os.environ.get("BANK_SERVICE_NAME", "bank-core")
        spans = self.finished_spans()
        return {
            "resourceSpans": [
                {
                    "resource": {
                        "attributes": [
                            _otlp_attribute("service.name", service),
                            _otlp_attribute("telemetry.sdk.language", "python"),
                        ]
                    },
                    "scopeSpans": [
                        {
                            "scope": {"name": "bank.tracer", "version": "1.0.0"},
                            "spans": [_otlp_span(span) for span in spans],
                        }
                    ],
                }
            ]
        }

    def reset(self) -> None:
        with self._lock:
            self._finished.clear()


METRICS = Metrics()
LOGGER = get_logger()
TRACER = Tracer()


def traced(name: str, **attributes: Any):
    """Decorador para instrumentar uma operação sem poluir o corpo dela."""

    def decorator(function):
        @wraps(function)
        def wrapper(*args: Any, **kwargs: Any):
            with TRACER.start(name, **attributes):
                return function(*args, **kwargs)

        return wrapper

    return decorator
