"""Remove hard-coded Flutter mock seed lists; point getters at CatalogStore."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MOCK_DIR = ROOT / "frontend" / "lib" / "core" / "mock_data"
STORE_IMPORT = "import '../api/catalog_store.dart';\n"

FIELD_MAP = {
    "tradeSquareMockUsers": "users",
    "tradeSquareMockBusinesses": "businesses",
    "tradeSquareMockProducts": "products",
    "tradeSquareMockBuyingRequests": "buyingRequests",
    "tradeSquareMockConversations": "conversations",
    "tradeSquareMockConnections": "connections",
    "tradeSquareMockCategories": "categories",
    "tradeSquareMockFeedItems": "feedItems",
    "tradeSquareMockNotifications": "notifications",
    "tradeSquareMockBusinessVerificationStatuses": "verifications",
    "tradeSquareMockAnalytics": "analytics",
    "tradeSquareMockAiRecommendations": None,
    "tradeSquareMockMarketInsights": None,
    "tradeSquareMockAuthStates": None,
    "tradeSquareMockUploads": None,
}


def strip_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    pattern = re.compile(
        r"final\s+List<([^>]+)>\s+(\w+)\s*=\s*\[.*?\];\n?",
        re.S,
    )
    matches = list(pattern.finditer(text))
    if not matches:
        print(f"no list: {path.name}")
        return

    getters: list[str] = []
    new_text = text
    for match in reversed(matches):
        typ, name = match.group(1), match.group(2)
        store_field = FIELD_MAP.get(name)
        new_text = new_text[: match.start()] + new_text[match.end() :]
        if store_field is None:
            getters.append(f"List<{typ}> get {name} => const [];\n")
        else:
            getters.append(
                f"List<{typ}> get {name} => CatalogStore.instance.{store_field};\n"
            )
    getters.reverse()

    needs_store = any("CatalogStore" in g for g in getters)
    if needs_store and "catalog_store.dart" not in new_text:
        lines = new_text.splitlines(True)
        last_import = -1
        for i, line in enumerate(lines):
            if line.startswith("import "):
                last_import = i
        if last_import >= 0:
            lines.insert(last_import + 1, STORE_IMPORT)
            new_text = "".join(lines)
        else:
            new_text = STORE_IMPORT + "\n" + new_text

    path.write_text(new_text.rstrip() + "\n\n" + "".join(getters), encoding="utf-8")
    print(f"stripped {path.name} ({len(getters)} getters)")


def main() -> None:
    for path in sorted(MOCK_DIR.glob("mock_*.dart")):
        if path.name == "mock_data.dart":
            continue
        strip_file(path)


if __name__ == "__main__":
    main()
