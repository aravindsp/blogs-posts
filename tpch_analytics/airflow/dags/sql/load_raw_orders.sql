-- Load any new files from the stage. COPY INTO remembers which files it has
-- already loaded (for 64 days), so re-running this never duplicates data.
COPY INTO RAW.TPCH.ORDERS
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9,
           CURRENT_TIMESTAMP(), METADATA$FILENAME
    FROM @RAW.TPCH.LANDING/orders/
)
FILE_FORMAT = (FORMAT_NAME = 'RAW.TPCH.CSV_GZ')
ON_ERROR = 'ABORT_STATEMENT';

COPY INTO RAW.TPCH.LINEITEM
FROM (
    SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16,
           CURRENT_TIMESTAMP(), METADATA$FILENAME
    FROM @RAW.TPCH.LANDING/lineitem/
)
FILE_FORMAT = (FORMAT_NAME = 'RAW.TPCH.CSV_GZ')
ON_ERROR = 'ABORT_STATEMENT';
