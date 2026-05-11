import dlt

from xdata_ingestion.ducklake import destination


def dataset():
    return dlt.pipeline(
        pipeline_name="coingecko",
        destination=destination(),
        dataset_name="raw",
    ).dataset()
