with customers as (

    select * from {{ ref('stg_tpch__customers') }}

),

nations as (

    select * from {{ ref('stg_tpch__nations') }}

),

regions as (

    select * from {{ ref('stg_tpch__regions') }}

),

order_summary as (

    select
        customer_key,
        min(order_date)  as first_order_date,
        max(order_date)  as most_recent_order_date,
        count(*)         as lifetime_orders
    from {{ ref('stg_tpch__orders') }}
    group by customer_key

)

select
    customers.customer_key,
    customers.customer_name,
    customers.market_segment,
    customers.account_balance,
    nations.nation_name,
    regions.region_name,
    order_summary.first_order_date,
    order_summary.most_recent_order_date,
    coalesce(order_summary.lifetime_orders, 0) as lifetime_orders
from customers
left join nations
    on customers.nation_key = nations.nation_key
left join regions
    on nations.region_key = regions.region_key
left join order_summary
    on customers.customer_key = order_summary.customer_key
