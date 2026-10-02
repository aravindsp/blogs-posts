{% snapshot snap_customers %}

{{
    config(
        schema='snapshots',
        unique_key='customer_key',
        strategy='check',
        check_cols=['market_segment', 'account_balance', 'customer_address']
    )
}}

select * from {{ ref('stg_tpch__customers') }}

{% endsnapshot %}
