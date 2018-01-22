
-- first_value() over(partition by xxx order by xxx ASC) 分析函数
select *
  from (select a.*,
               first_value(ads_id) over(partition by pageid order by ads_pos asc) fv
          from a);


/**
根据pageid分组
然后按照ads_pos进行升序排序
每组pageid里面， ads_pos最小的那一行的ads_id就是我们要求出的
**/
select pageid, ads_id
  from a
 where (a.pageid, a.ads_pos) in
       (select pageid, min(ads_pos) from a group by pageid);


/**
然后拿上面的结果和a表再去关联， pageid相等的first_value(ads_id) 全部都为上面结果集中的ads_id
**/
with group_sort_min_ads_id as
 (select pageid, ads_id
    from a
   where (a.pageid, a.ads_pos) in
         (select pageid, min(ads_pos) min_ads_pos from a group by pageid))
select a.*, b.ads_id fv
  from a
  left join group_sort_min_ads_id b
    on (a.pageid = b.pageid)
 order by 1, 2;

/****************************************************************************/
/****************************************************************************/
/****************************************************************************/
/****************************************************************************/


-- first_value() over(partition by xxx order by xxx DESC) 分析函数
select *
  from (select a.*,
               first_value(ads_id) over(partition by pageid order by ads_pos desc) fv,
               row_number() over(partition by pageid order by ads_pos) rn
          from a)
 order by pageid, rn;

/**
根据pageid分组
然后按照ads_pos进行降序排序
每组pageid里面， ads_pos最大的那一行的ads_id就是我们要求出的
**/
select pageid, ads_id
  from a
 where (a.pageid, a.ads_pos) in
       (select pageid, max(ads_pos) from a group by pageid);
       
/*然后再和a表进行关联*/       
with group_sort_max_ads_id as
 (select pageid, ads_id
    from a
   where (a.pageid, a.ads_pos) in
         (select pageid, max(ads_pos) from a group by pageid))
select a.*, b.ads_id
  from a
  left join group_sort_max_ads_id b
    on (a.pageid = b.pageid)
 order by 1, 2




/****************************************************************************/
/****************************************************************************/
/****************************************************************************/
/****************************************************************************/
last_value 和first_value 一模一样， over子句中的order顺序颠倒一下就是了




/****************************************************************************/
/**************************用标量子查询的方式实现****************************/
/****************************************************************************/
/****************************************************************************/

-- 如果pageid和ads_pos是组合起来是唯一的， 那么可以直接写这个
select a.*,
       (select v2.ads_id
          from a v2
         where (v2.pageid, v2.ads_pos) in
               ((select v1.pageid, max(v1.ads_pos)  -- 这里max表示是求first_value desc 的
                  from a v1
                 group by v1.pageid))
           and a.pageid = v2.pageid) fv
  from a
 order by 1, 2;
  
-- 如果不确定是否是唯一的， 那还是使用这个保险一点  
select a.*,
       (select min(v2.ads_id)
          from a v2
         where (v2.pageid, v2.ads_pos) in
               ((select v1.pageid, max(v1.ads_pos)
                  from a v1
                 group by v1.pageid))
           and a.pageid = v2.pageid) fv
  from a
  order by 1, 2


