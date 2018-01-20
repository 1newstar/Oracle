select t.*,
       sys_connect_by_path(t.region_name, '-'),
       connect_by_root(t.region_name) root_region_name,
       connect_by_root(t.region_id) root_region_id
  from t_region t
 start with t.level_kind = 2
connect by prior t.region_id = t.parent_region_id;

查询结果见 结果1.png


上面的SQL中, 我们以level_kind=2(省)的开始进行层次查询, 把每个子节点的根省份找出来.




with v_root_region as
 (select t.region_id, connect_by_root(t.region_name) root_region_name
    from t_region t
   start with t.level_kind = 2
  connect by prior t.region_id = t.parent_region_id)
select t1.user_id, trunc(t2.login_date) ldate, t3.root_region_name
  from t_users t1
 inner join t_login t2
    on (t1.user_id = t2.user_id)
 inner join v_root_region t3
    on (t1.region_id = t3.region_id)
 order by 3

查询结果见 结果2.png






------------------------最后的查询SQL------------------------
-- 方式1,使用group by的方式
with v_root_region as
 (select t.region_id, connect_by_root(t.region_name) root_region_name
    from t_region t
   start with t.level_kind = 2
  connect by prior t.region_id = t.parent_region_id),
v_result as
 (select t1.user_id, trunc(t2.login_date) ldate, t3.root_region_name
    from t_users t1
   inner join t_login t2
      on (t1.user_id = t2.user_id)
   inner join v_root_region t3
      on (t1.region_id = t3.region_id))
/*select v.root_region_name,
       v.ldate,
       v.user_id,
       count(*) over(partition by v.root_region_name, v.ldate) "登陆总次数" \*,
       row_number() over(partition by v.root_region_name, v.ldate, v.user_id order by 1) "登陆总人数"*\
  from v_result v
 order by 1, 2, 3*/

select root_region_name,
       ldate,
       count(*) "登陆总次数",
       count(distinct user_id) "登录人数"
  from v_result
 group by root_region_name, ldate
 order by 1, 2




-- 方式2, 分析函数+distinct来实现, 实现思路和上面是一致的, 这个效率没有使用group by好
with v_root_region as
 (select t.region_id, connect_by_root(t.region_name) root_region_name
    from t_region t
   start with t.level_kind = 2
  connect by prior t.region_id = t.parent_region_id),
v_result as
 (select t1.user_id, trunc(t2.login_date) ldate, t3.root_region_name
    from t_users t1
   inner join t_login t2
      on (t1.user_id = t2.user_id)
   inner join v_root_region t3
      on (t1.region_id = t3.region_id))
select distinct v.root_region_name,
                v.ldate,
                count(*) over(partition by v.root_region_name, v.ldate) "登陆总次数",
                count(distinct user_id) over(partition by v.root_region_name, v.ldate) "登陆总人数"
  from v_result v
 order by 1, 2, 3




-- 验证 某个省/某天 的 总访问次数和登录次数
with v_root_region as
 (select t.region_id, connect_by_root(t.region_name) root_region_name
    from t_region t
   start with t.level_kind = 2
  connect by prior t.region_id = t.parent_region_id),
v_result as
 (select t1.user_id, trunc(t2.login_date) ldate, t3.root_region_name
    from t_users t1
   inner join t_login t2
      on (t1.user_id = t2.user_id)
   inner join v_root_region t3
      on (t1.region_id = t3.region_id)
   order by 3)
select count(*), count(distinct user_id)
  from v_result t
 where root_region_name = '广东省'
   and ldate = to_date('20180112', 'yyyy-MM-dd')



