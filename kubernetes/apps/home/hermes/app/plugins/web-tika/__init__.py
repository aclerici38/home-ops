"""web_extract via a self-hosted Apache Tika.

Pages are fetched here through Hermes' SSRF-guarded client (redirect hops included), then parsed by
Tika, so one path covers HTML, PDF, Office documents and scanned images (Tesseract OCR). Extract-only:
pair with any ``web.search_backend``. Env: ``TIKA_SERVER_URL``.
"""

from __future__ import annotations

import logging
import re
from concurrent.futures import ThreadPoolExecutor
from typing import Any, Optional

import httpx
from lxml import etree
from lxml import html as lxml_html

from agent.web_search_provider import WebSearchProvider, get_provider_env
from tools.url_safety import create_ssrf_safe_client

logger = logging.getLogger(__name__)

_MAX_BYTES = 50 * 1024 * 1024
_FETCH_TIMEOUT = httpx.Timeout(30.0, connect=10.0)
# OCR of a long scanned PDF can take minutes
_TIKA_TIMEOUT = httpx.Timeout(600.0, connect=10.0)
_WORKERS = 4
_NOISE_TAGS = ("script", "style", "noscript", "template", "svg", "iframe", "form", "button", "nav", "aside")
# Page-level chrome; inside an <article> a <header> usually holds the headline
_CHROME_TAGS = ("header", "footer")
_NAV_XPATH = ".//*[@role='navigation' or @role='search' or @aria-hidden='true']"
_BLANK_LINES = re.compile(r"\n{3,}")
# A main/article shorter than this is usually a teaser box, not the page body
_MIN_MAIN_CHARS = 200


class _FetchError(Exception):
    pass


def _page_error(url: str, error: str) -> dict[str, Any]:
    return {"url": url, "title": "", "content": "", "error": error}


def _document(url: str, final_url: str, title: str, content: str) -> dict[str, Any]:
    return {
        "url": url, "title": title, "content": content, "raw_content": content,
        "metadata": {"sourceURL": final_url, "title": title},
    }


def _mime(content_type: str) -> str:
    return content_type.split(";", 1)[0].strip().lower()


def _fetch(client: httpx.Client, url: str) -> tuple[bytes, str, str]:
    with client.stream("GET", url) as response:
        if response.status_code >= 400:
            # Wording matches Hermes' origin-error contract, so it never triggers a keyless rescue
            raise _FetchError(f"HTTP {response.status_code} from origin: {response.reason_phrase}")
        declared = response.headers.get("content-length")
        if declared and declared.isdigit() and int(declared) > _MAX_BYTES:
            raise _FetchError(f"Response is {int(declared)} bytes; limit is {_MAX_BYTES}")
        chunks, size = [], 0
        for chunk in response.iter_bytes():
            size += len(chunk)
            if size > _MAX_BYTES:
                raise _FetchError(f"Response exceeds {_MAX_BYTES} bytes")
            chunks.append(chunk)
        return b"".join(chunks), str(response.url), response.headers.get("content-type", "")


def _main_content(body: bytes) -> tuple[bytes, str]:
    """Trim an HTML page to its main content so Tika's text isn't padded with menus and footers."""
    doc = lxml_html.document_fromstring(body)
    title = " ".join((doc.findtext(".//title") or "").split())
    candidates = doc.xpath("//article | //main | //*[@role='main']")
    best = max(candidates, key=lambda el: len(el.text_content()), default=None)
    root = best if best is not None and len(best.text_content().strip()) >= _MIN_MAIN_CHARS else doc
    etree.strip_elements(root, *_NOISE_TAGS, etree.Comment, with_tail=False)
    if root is doc:
        etree.strip_elements(root, *_CHROME_TAGS, with_tail=False)
    for element in root.xpath(_NAV_XPATH):
        element.drop_tree()
    return lxml_html.tostring(root, encoding="utf-8"), title


def _tidy(text: str) -> str:
    """Tika keeps the source's indentation whitespace; strip it per line and cap blank runs."""
    lines = (" ".join(line.split()) for line in text.splitlines())
    return _BLANK_LINES.sub("\n\n", "\n".join(lines)).strip()


def _first(value: Any) -> str:
    if isinstance(value, list):
        value = value[0] if value else ""
    return str(value or "").strip()


def _tika(client: httpx.Client, base_url: str, body: bytes, mime: str) -> tuple[str, str]:
    headers = {"Accept": "application/json"}
    # Tika sniffs magic bytes itself; a generic type would only mislead it
    if mime and mime != "application/octet-stream":
        headers["Content-Type"] = "text/html; charset=UTF-8" if mime in ("text/html", "application/xhtml+xml") else mime
    response = client.put(f"{base_url}/rmeta/text", content=body, headers=headers)
    if response.status_code >= 400:
        raise _FetchError(f"Tika returned HTTP {response.status_code}: {(response.text or '').strip()[:200]}")
    parts = response.json() or [{}]
    text = "\n\n".join(c for c in (_first(p.get("X-TIKA:content")) for p in parts) if c)
    meta = parts[0]
    title = _first(meta.get("dc:title") or meta.get("title") or meta.get("pdf:docinfo:title"))
    return text, title


class TikaWebExtractProvider(WebSearchProvider):
    """Extract-only provider backed by a self-hosted Tika server."""

    @property
    def name(self) -> str:
        return "tika"

    @property
    def display_name(self) -> str:
        return "Apache Tika (self-hosted)"

    def is_available(self) -> bool:
        return bool(get_provider_env("TIKA_SERVER_URL"))

    def supports_search(self) -> bool:
        return False

    def supports_extract(self) -> bool:
        return True

    def get_setup_schema(self) -> dict[str, Any]:
        return {
            "name": self.display_name, "badge": "free · self-hosted",
            "tag": "Fetch pages locally, parse with Tika (HTML, PDF, Office, OCR).",
            "env_vars": [{"key": "TIKA_SERVER_URL", "prompt": "Tika server URL (e.g. http://tika:9998)",
                          "url": "https://tika.apache.org/"}],
        }

    def extract(self, urls: list[str], **kwargs: Any) -> list[dict[str, Any]]:
        base_url = get_provider_env("TIKA_SERVER_URL").rstrip("/")
        if not base_url:
            return [_page_error(u, "TIKA_SERVER_URL is not set") for u in urls]
        with create_ssrf_safe_client(follow_redirects=True, timeout=_FETCH_TIMEOUT) as web, \
                httpx.Client(timeout=_TIKA_TIMEOUT) as tika:
            with ThreadPoolExecutor(max_workers=min(_WORKERS, max(1, len(urls)))) as pool:
                return list(pool.map(lambda u: self._extract_one(web, tika, base_url, u), urls))

    def _extract_one(self, web: httpx.Client, tika: httpx.Client, base_url: str, url: str) -> dict[str, Any]:
        try:
            body, final_url, content_type = _fetch(web, url)
            mime = _mime(content_type)
            page_title: Optional[str] = None
            if mime in ("text/html", "application/xhtml+xml"):
                body, page_title = _main_content(body)
            text, tika_title = _tika(tika, base_url, body, mime)
        except _FetchError as exc:
            return _page_error(url, str(exc))
        except Exception as exc:
            logger.warning("Tika extract failed for %s: %s", url, exc)
            return _page_error(url, f"{type(exc).__name__}: {exc}")
        text = _tidy(text)
        if not text:
            return _page_error(url, "No text extracted (page may need JavaScript; try the browser tool)")
        return _document(url, final_url, page_title or tika_title, text)


def register(ctx) -> None:
    ctx.register_web_search_provider(TikaWebExtractProvider())
