CREATE EXTENSION tablefunc;
select item_category, coalesce(Monday, 0) as Monday,
coalesce(Tuesday, 0) as Tuesday,
coalesce(Wednesday, 0) as Wednesday,
coalesce(Thursday, 0) as Thursday,
coalesce(Friday, 0) as Friday,
coalesce(Saturday, 0) as Saturday,
coalesce(Sunday, 0) as Sunday
from crosstab(
$$ 
select item_category::varchar(20), weekday::varchar(20), total_quantity::integer from 
(select items.item_category,
case extract(dow from order_date) 
when 0 then 'Sunday'
when 1 then 'Monday'
when 2 then 'Tuesday'
when 3 then 'Wednesday'
when 4 then 'Thursday'
when 5 then 'Friday'
when 6 then 'Saturday' end as weekday,
sum(quantity::integer) as total_quantity
from items
left join orders
using(item_id)
group by item_category, extract(dow from order_date)) a
order by item_category
$$,
$$values ('Monday'), ('Tuesday'), ('Wednesday'), ('Thursday'), ('Friday'), ('Saturday'), ('Sunday') $$) as 
t(item_category varchar(20), Monday integer, Tuesday integer,
Wednesday integer, Thursday integer, Friday integer, Saturday integer, Sunday integer);