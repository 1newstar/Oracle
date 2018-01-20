思路:
 1/我是准备先给每一行添加一列值 new_id 值都为sys_guid(), 然后通过层次查询把父行的 new_id 列的值取到
 这一步通过下面的这个SQL来实现
 注意: with as 的子查询中必须使用materialize , 不然会影响层次查询的结果.
	with v as
	 (select /*+ materialize */
	   t.region_id, t.parent_region_id, sys_guid() new_id
	    from t_region t)
	select v.*, prior new_id new_parent_id, level lv
	  from v
	 start with v.parent_region_id is null
	connect by v.parent_region_id = prior v.region_id
	 order by lv;

 2/通过上面的子查询和原表t_region进行merge达到目的, 但是merge的时候是通过region_id来进行关联的, 
   merge 语句是不允许更新关联列的值的, 所以, 还要对上面的SQL进行一番改造, 通过rowid来进行关联更新.
	对上面的子查询进行改造
	with v as
	 (select /*+ materialize */
	   rowid rid, region_id, parent_region_id, sys_guid() new_id
	    from t_region t)
	select v.rid, v.new_id, prior new_id new_parent_id, level lv
	  from v
	 start with v.parent_region_id is null
	connect by v.parent_region_id = prior v.region_id
	 order by lv;

	 查询结果见 查询结果1.png



 3/最后的merge 语句
merge into t_region t1
using (
  with v as
   (select /*+ materialize */
     rowid rid, region_id, parent_region_id, sys_guid() new_id
      from t_region t)
  select v.rid, v.new_id, prior new_id new_parent_id
    from v
   start with v.parent_region_id is null
  connect by v.parent_region_id = prior v.region_id) t2
  -- 通过rowid进行关联更新
   on (t1.rowid = t2.rid) when matched then
    update
       set t1.region_id = t2.new_id, t1.parent_region_id = t2.new_parent_id;

merge 之后再查询表的数据
select *
  from t_region t
 start with t.parent_region_id is null
connect by prior t.region_id = t.parent_region_id
查询结果见 查询结果2.png 