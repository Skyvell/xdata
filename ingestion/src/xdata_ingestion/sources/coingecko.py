import dlt
from dlt.sources.helpers import requests


@dlt.resource(name="coins_markets", write_disposition="merge", primary_key="id")
def coins_markets():
    r = requests.get(
        "https://api.coingecko.com/api/v3/coins/markets",
        params={"vs_currency": "usd", "per_page": 250, "page": 1},
        timeout=30,
    )
    r.raise_for_status()
    yield from r.json()
