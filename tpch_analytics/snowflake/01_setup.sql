-- Part 2: warehouses, databases, roles and service users for the TPC-H project.
-- Run in a Snowsight worksheet as a user who has ACCOUNTADMIN.

-------------------------------------------------------------------------------
-- 1. Warehouses: one per workload, all X-Small, all auto-suspend after 60s
-------------------------------------------------------------------------------
USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS LOADING_WH
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE
  COMMENT = 'COPY INTO loads run by Airflow';

CREATE WAREHOUSE IF NOT EXISTS TRANSFORM_WH
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE
  COMMENT = 'dbt runs (dev, CI and prod)';

CREATE WAREHOUSE IF NOT EXISTS REPORTING_WH
  WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE INITIALLY_SUSPENDED = TRUE
  COMMENT = 'BI tools and analysts';

-------------------------------------------------------------------------------
-- 2. Databases: RAW holds data as it arrived, ANALYTICS holds what dbt builds
-------------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS RAW;
CREATE SCHEMA IF NOT EXISTS RAW.TPCH;
CREATE DATABASE IF NOT EXISTS ANALYTICS;

-------------------------------------------------------------------------------
-- 3. Functional roles
-------------------------------------------------------------------------------
USE ROLE SECURITYADMIN;

CREATE ROLE IF NOT EXISTS LOADER      COMMENT = 'Writes to RAW';
CREATE ROLE IF NOT EXISTS TRANSFORMER COMMENT = 'Reads RAW, builds ANALYTICS with dbt';
CREATE ROLE IF NOT EXISTS REPORTER    COMMENT = 'Reads ANALYTICS';

-- roll the custom roles up to SYSADMIN so admins can manage what they create
GRANT ROLE LOADER      TO ROLE SYSADMIN;
GRANT ROLE TRANSFORMER TO ROLE SYSADMIN;
GRANT ROLE REPORTER    TO ROLE SYSADMIN;

GRANT USAGE ON WAREHOUSE LOADING_WH   TO ROLE LOADER;
GRANT USAGE ON WAREHOUSE TRANSFORM_WH TO ROLE TRANSFORMER;
GRANT USAGE ON WAREHOUSE REPORTING_WH TO ROLE REPORTER;

-- LOADER: create and fill tables, stages and file formats in RAW.TPCH
GRANT USAGE ON DATABASE RAW TO ROLE LOADER;
GRANT USAGE, CREATE TABLE, CREATE STAGE, CREATE FILE FORMAT ON SCHEMA RAW.TPCH TO ROLE LOADER;

-- TRANSFORMER: read everything in RAW.TPCH (now and in future), own ANALYTICS schemas
GRANT USAGE ON DATABASE RAW TO ROLE TRANSFORMER;
GRANT USAGE ON SCHEMA RAW.TPCH TO ROLE TRANSFORMER;
GRANT SELECT ON ALL TABLES IN SCHEMA RAW.TPCH TO ROLE TRANSFORMER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA RAW.TPCH TO ROLE TRANSFORMER;
GRANT USAGE, CREATE SCHEMA ON DATABASE ANALYTICS TO ROLE TRANSFORMER;

-- REPORTER: read-only on ANALYTICS (dbt grants per model in part 6)
GRANT USAGE ON DATABASE ANALYTICS TO ROLE REPORTER;

-------------------------------------------------------------------------------
-- 4. Sample data access (the TPC-H source for this series)
-------------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;
-- If SNOWFLAKE_SAMPLE_DATA is missing in your account, create it first:
-- CREATE DATABASE SNOWFLAKE_SAMPLE_DATA FROM SHARE SFC_SAMPLES.SAMPLE_DATA;
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_SAMPLE_DATA TO ROLE LOADER;

-------------------------------------------------------------------------------
-- 5. Service user for Airflow and dbt: key-pair authentication, no password
-------------------------------------------------------------------------------
USE ROLE USERADMIN;

CREATE USER IF NOT EXISTS AIRFLOW_SVC
  TYPE = SERVICE
  DEFAULT_ROLE = LOADER
  DEFAULT_WAREHOUSE = LOADING_WH
  RSA_PUBLIC_KEY = 'MIIBIjANBgkqh...paste the body of rsa_key.pub here...'
  COMMENT = 'Airflow: loads RAW and runs dbt in prod';

USE ROLE SECURITYADMIN;
GRANT ROLE LOADER      TO USER AIRFLOW_SVC;
GRANT ROLE TRANSFORMER TO USER AIRFLOW_SVC;

-- your own (human) user for development
GRANT ROLE TRANSFORMER TO USER <your_user>;

-------------------------------------------------------------------------------
-- 6. Cost guardrail: a monthly credit budget for dbt
-------------------------------------------------------------------------------
USE ROLE ACCOUNTADMIN;

CREATE RESOURCE MONITOR IF NOT EXISTS TRANSFORM_MONTHLY
  WITH CREDIT_QUOTA = 30
  FREQUENCY = MONTHLY
  START_TIMESTAMP = IMMEDIATELY
  TRIGGERS ON 75 PERCENT DO NOTIFY
           ON 100 PERCENT DO SUSPEND
           ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER WAREHOUSE TRANSFORM_WH SET RESOURCE_MONITOR = TRANSFORM_MONTHLY;
