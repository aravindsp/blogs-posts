select
    date_trunc('month', orders.order_date) as order_month,
    customers.region_name,
    customers.market_segment,
    count(*)                               as order_count,
    sum(orders.net_amount)                 as net_revenue,
    sum(orders.total_amount)               as gross_revenue_incl_tax
from {{ ref('fct_orders') }} as orders
inner join {{ ref('dim_customers') }} as customers
    on orders.customer_key = customers.customer_key
group by 1, 2, 3
