
select * from c;


select c.*, lead(login_time) over(order by cust_code, ip, login_time)
  from c;


-- 手写SQL(标量子查询方式) 实现 lead 分析函数功能
select t2.PAGEID, t2.ADS_POS, t2.ADS_ID
       (
       select t4.ads_id from (select t3.*, row_number() over(order by t3.pageid) rn from a t3) t4
              where t4.rn > t2.rn 
              and rownum = 1
       ) lead_ads_id
  from (select t1.*, row_number() over(order by t1.pageid) rn from a t1) t2;


-- 手写SQL(left join方式) 实现 lead 分析函数功能
select *
  from (select t2.pageid,
               t2.ads_pos,
               t2.ads_id,
               t2.rn t2_rn,
               t4.ads_id t4_ads_id,
               t4.rn t4_rn,
               row_number() over(partition by t2.rn order by t4.rn) rn_xx
          from (select t1.*, row_number() over(order by t1.pageid) rn
                  from a t1) t2
          left join (select t3.*, row_number() over(order by t3.pageid) rn
                      from a t3) t4
            on (t4.rn > t2.rn))
 where rn_xx = 1;
 
 

