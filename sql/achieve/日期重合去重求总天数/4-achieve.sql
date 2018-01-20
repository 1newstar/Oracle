with v as
 (select t.*,
         lag(t.enddate) over(partition by t.brand order by t.startdate) prev_enddate
    from t_sale t)
select brand, sum(days)
  from (select v.*,
               (case
                 when v.prev_enddate is null then
                  v.enddate - v.startdate
                 when v.startdate > v.prev_enddate then
                  v.enddate - v.startdate
                 else
                  v.enddate - v.prev_enddate - 1 -- 这里还要减1 ， 因为v.prev_enddate，在上一条记录中已经被算过一天了
               end) + 1 days
          from v)
 group by brand


