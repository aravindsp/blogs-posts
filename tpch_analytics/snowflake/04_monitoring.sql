-- Part 10: cost and performance checks. Needs a role with access to the
-- SNOWFLAKE database, e.g.:  GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE TO ROLE SYSADMIN;
-- ACCOUNT_USAGE views lag real time by up to a few hours.

-- Credits per warehouse, last 30 days
SELECT warehouse_name,
       ROUND(SUM(credits_used), 2) AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY credits DESC;

-- Credits per day for the dbt warehouse: spot the day something changed
SELECT DATE_TRUNC('DAY', start_time) AS day,
       ROUND(SUM(credits_used), 2)   AS credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'TRANSFORM_WH'
  AND start_time >= DATEADD(DAY, -30, CURRENT_TIMESTAMP())
GROUP BY day
ORDER BY day;

-- Slowest dbt queries this week (dbt sets QUERY_TAG via +query_tag in dbt_project.yml)
SELECT start_time,
       ROUND(total_elapsed_time / 1000, 1)          AS seconds,
       ROUND(bytes_scanned / POWER(1024, 3), 2)     AS gb_scanned,
       partitions_scanned,
       partitions_total,
       LEFT(query_text, 120)                        AS query_start
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag = 'dbt_tpch_analytics'
  AND start_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
ORDER BY total_elapsed_time DESC
LIMIT 20;

-- Loads that did not fully succeed in the last 7 days
SELECT table_name, file_name, status, row_count, row_parsed, first_error_message, last_load_time
FROM SNOWFLAKE.ACCOUNT_USAGE.COPY_HISTORY
WHERE last_load_time >= DATEADD(DAY, -7, CURRENT_TIMESTAMP())
  AND status <> 'Loaded'
ORDER BY last_load_time DESC;
