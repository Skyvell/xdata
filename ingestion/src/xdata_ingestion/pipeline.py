import dlt

from xdata_ingestion.ducklake import destination
from xdata_ingestion.sources.coingecko import coins_markets


def run() -> None:
    dlt.pipeline(
        pipeline_name="coingecko",
        destination=destination(),
        dataset_name="raw",
    ).run(coins_markets())


if __name__ == "__main__":
    run()
