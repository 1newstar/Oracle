原始SQL如下:
update test1 a
   set owner = '是'
 where exists
 (select 1 from test2 b where instr(a.object_name, b.object_name) > 0);


SQL> explain plan for
  2  update test1 a
  3     set owner = '是'
  4   where exists
  5   (select 1 from test2 b where instr(a.object_name, b.object_name) > 0);

已解释。

SQL> select * from table(dbms_xplan.display);

PLAN_TABLE_OUTPUT
----------------------------------------------------------------------------------------------------------------
--------------------------------------------------
Plan hash value: 1391977299

-----------------------------------------------------------------------------
| Id  | Operation           | Name  | Rows  | Bytes | Cost (%CPU)| Time     |
-----------------------------------------------------------------------------
|   0 | UPDATE STATEMENT    |       |  3517 |   285K|    11M  (1)| 38:57:56 |
|   1 |  UPDATE             | TEST1 |       |       |            |          |
|*  2 |   FILTER            |       |       |       |            |          |
|   3 |    TABLE ACCESS FULL| TEST1 | 70344 |  5701K|   291   (1)| 00:00:04 |
|*  4 |    TABLE ACCESS FULL| TEST2 |  3435 |   221K|   292   (1)| 00:00:04 |
-----------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   2 - filter( EXISTS (SELECT 0 FROM "TEST2" "B" WHERE
              INSTR(:B1,"B"."OBJECT_NAME")>0))
   4 - filter(INSTR(:B1,"B"."OBJECT_NAME")>0)

Note
-----
   - dynamic sampling used for this statement (level=2)

已选择22行。





从执行计划中可以看出, 这个SQL执行方式走的是Filter, 类似嵌套循环, test1每扫描一条记录, 就传值给test2, 然后test2进行全表扫描一次, 
这样test1有多少条记录, test2表就会被执行多少次全表扫描.
你那里两张表都是20W的数据量, 相当于执行20W次20W数据量的表的全表扫描 这样不死才怪

-------------------第一种方式, 由于访问的列都比较少, 建立索引,或者组合索引, 让其走IFFS加并行.
在test1/test2表的object_name都建立索引 
create index IDX_TEST1_ONAME on TEST1 (OBJECT_NAME)
create index IDX_TEST2_ONAME on TEST2 (OBJECT_NAME)

  alter index IDX_TEST1_ONAME storage(buffer_pool keep);
alter index IDX_TEST2_ONAME storage(buffer_pool keep);

  update /*+ parallel(a 8) index_ffs(a IDX_TEST1_ONAME) */ test1 a
   set owner = '是'
 where exists
 (select /*+ parallel(b 8) index_ffs(b IDX_TEST2_ONAME) */ from test2 b where instr(a.object_name, b.object_name) > 0);



-------------------第二种方式, PL/SQL

我们先用查询语句的方式来看这个 update 语句

因为两个表的结构和数据都是一样的, 所以, 查询结果就是test1表的总数据之和.

select /*+ parallel(4) */ count(*)
  from test1 a
 where exists
 (select 1 from test2 b where instr(a.object_name, b.object_name) > 0);

开4个并行执行耗时:
1 row selected in 213.019 seconds



-- 现在改成PL/SQL的方式

在test1/test2表的object_name都建立索引 
create index IDX_TEST1_ONAME on TEST1 (OBJECT_NAME)
create index IDX_TEST2_ONAME on TEST2 (OBJECT_NAME)

由于instr函数只要有一个参数为null, 则返回null, 根据sql的条件
instr(a.object_name, b.object_name) > 0
我可以断定出 a.object_name 和 b.object_name 都要排除为null的数据


declare
  -- 这个用来记录循环每次查询出的结果数量, 如果为1, 表示查询到数据, 为0表是没有查询到匹配的数据
  v_cnt pls_integer default 0;
  -- 这个用来记录最终符合条件的总行数
  v_increment pls_integer default 0;
begin
  -- 如果test1表object_name重复数据比较多, 这里还应该加上一个缓存, 用一个tbl, key为object_name, 值为1或0来标识
  -- 每个object_name都先在tbl中进行查找, 看找不着得到, 找不到再到表中进行查找, 然后缓存到tbl中...
  -- 我这里test1表没有重复数据, 所以我这里没加
  for i in (select object_name from test1) loop
    -- SQL中必须显式的排除null的数据, 否则走不了INDEX FAST FULL SCAN
    -- SQL中必须加上 rownum <=1 只需要查询到一条就马上停止扫描, 类似半连接
    select /*+ index_ffs(b IDX_TEST2_ONAME)*/
     count(*)
      into v_cnt
      from test2 b
     where instr('I_OBJ', b.object_name) > 0
       and b.object_name is not null
       and rownum <= 1;
  
    if v_cnt = 1 then
      v_increment := v_increment + 1;
    end if;
  end loop;

  dbms_output.put_line(v_increment);

end;

-- 单独执行的耗时
Done in 233.393 seconds


现在要拆分成多个执行单元了

我这里test1表7W多的数据量, 我拆分成8个部分[根据机器性能和数据量来决定分成多少部分吧], 每个部分执行1W条
只需要该for 游标里面的分页参数即可..然后分别到8个sqlplus中执行, 我这里用时不到20秒就搞定了...

set timing on;
set serveroutput on;
declare
  -- 这个用来记录循环每次查询出的结果数量, 如果为1, 表示查询到数据, 为0表是没有查询到匹配的数据
  v_cnt pls_integer default 0;
  -- 这个用来记录最终符合条件的总行数
  v_increment pls_integer default 0;
begin
  for i in (select /*+ index_fs(test1 IDX_TEST1_ONAME) */
             *
              from (select v.*, rownum rn
                      from (select object_name
                              from test1
                             where object_name is not null
                             order by object_name) v
                     where rownum <= 10000)
             where rn > 0) loop
    -- SQL中必须加上 b.object_name is not null ,可以走INDEX FAST FULL SCAN
    -- SQL中必须加上 rownum <=1 只需要查询到一条就马上停止扫描, 类似半连接
    select /*+ index_ffs(b)*/
     count(*)
      into v_cnt
      from test2 b
     where instr('I_OBJ', b.object_name) > 0
       and b.object_name is not null
       and rownum <= 1;
  
    if v_cnt = 1 then
      v_increment := v_increment + 1;
    end if;
  end loop;

  -- 这里的最终结果可以写到一张中间表中进行记录, 然后再汇总, 这里只做打印即可.
  dbms_output.put_line(v_increment);

end;
/