{{
    config(
        materialized='incremental',
        unique_key='order_item_key',
        incremental_strategy=('merge' if target.type == 'snowflake' else 'delete+insert'),
        on_schema_change='append_new_columns'
    )
}}

select * from {{ ref('int_order_items__enriched') }}

{% if is_incremental() %}
-- only process rows loaded since the last run
where _loaded_at > (select max(_loaded_at) from {{ this }})
{% endif %}
