-- Guardrail: no mart may expose a mean/median paid column. The APD per-claim paid statistics exclude $0 claims
-- and rise after a $0 cost-sharing policy; every cost-sharing measure must be built from the *_paid_sum columns.
select table_schema, table_name, column_name
from information_schema.columns
where table_schema like '%marts%'
  and table_name like 'mart_%'
  and (column_name like '%mean%paid%' or column_name like '%median%paid%' or column_name like '%paid%mean%' or column_name like '%paid%median%')
