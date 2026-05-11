"""Dagster code location: CoinGecko -> DuckLake ingestion."""

import dlt
from dagster import AssetSelection, Definitions, ScheduleDefinition, define_asset_job
from dagster_embedded_elt.dlt import DagsterDltResource, dlt_assets

from xdata_ingestion.ducklake import destination
from xdata_ingestion.sources.coingecko import coins_markets


@dlt.source(name="coingecko")
def coingecko_source():
    return coins_markets()


pipeline = dlt.pipeline(
    pipeline_name="coingecko",
    destination=destination(),
    dataset_name="raw",
)


@dlt_assets(dlt_source=coingecko_source(), dlt_pipeline=pipeline, name="coingecko")
def coingecko_assets(context, dlt: DagsterDltResource):
    yield from dlt.run(context=context)


coingecko_job = define_asset_job(
    "coingecko_job",
    selection=AssetSelection.assets(coingecko_assets),
)

defs = Definitions(
    assets=[coingecko_assets],
    resources={"dlt": DagsterDltResource()},
    jobs=[coingecko_job],
    schedules=[ScheduleDefinition(job=coingecko_job, cron_schedule="0 * * * *")],
)
