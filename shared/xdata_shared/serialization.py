"""JSON-serialization helpers for DuckDB query results.

DuckDB returns `Decimal` (NUMERIC columns) and `datetime`/`date` values
that `json.dumps` can't handle. Map them to JSON-friendly types:
- Decimal → str (preserves precision; float would lose it)
- datetime/date → ISO 8601 string
"""

from datetime import date, datetime
from decimal import Decimal


def jsonable(value):
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    return value
