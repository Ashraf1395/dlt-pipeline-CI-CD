-- Databricks notebook source
CREATE OR REFRESH STREAMING LIVE TABLE OKTA_SILVER_SYSTEM_LOGS
COMMENT "Incremental upload of data incoming from okta"
PARTITIONED BY (date, tenant_id)
AS
SELECT *
FROM cloud_files(
  '/Volumes/stackgenius/dev/stackgenius-dev/source=OKTA/*/*/*/*.json',
  'json',
  map('inferschema',"true")
);

-- COMMAND -

CREATE OR REFRESH MATERIALIZED VIEW OKTA_GOLD AS
SELECT
    `date`::DATE,
    source,
    tenant_id,
    actor_alternateId,
    actor_displayName,
    actor_type,
    client_device,
    displayMessage,
    outcome_result,
    outcome_reason,
    eventType,
    published::TIMESTAMP,
    transaction_id,
    CONCAT(city, ' ', country) AS location,
    CONCAT_WS(',', COLLECT_LIST(target_exploded.alternateId)) AS target_alternateId,
    CONCAT_WS(',', COLLECT_LIST(target_exploded.displayName)) AS target_displayName
FROM (
    SELECT *, 
        get_json_object(transaction, "$.id") AS transaction_id,
        get_json_object(client_geographicalContext, "$.city") AS city,
        get_json_object(client_geographicalContext, "$.country") AS country,
        EXPLODE(FROM_JSON(get_json_object(target, '$'), 'ARRAY<STRUCT<alternateId: STRING, displayName: STRING>>')) AS target_exploded
    FROM live.okta_silver_dlt
) AS exploded_table
GROUP BY `date`, tenant_id, actor_alternateId, actor_displayName, actor_type, client_device, displayMessage, outcome_result, outcome_reason, eventType, published, transaction_id, city, country
ORDER BY published DESC;

CREATE OR REFRESH LIVE TABLE ingestion_metadata_dlt AS
SELECT
  'okta' as source,
  tenant_id,
  MAX(published) as most_recent_timestamp
FROM
  live.okta_silver_dlt
GROUP BY
  source,
  tenant_id

