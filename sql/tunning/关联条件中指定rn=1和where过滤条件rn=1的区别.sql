-- 监控平台TOPSQL中,有这样一条SQL跑的比较慢, 
-- 平均每次执行用时  248.02s
-- 最长一次执行用时  1736.146s 差不多半个小时了
-- 我优化这个SQL差不多1分钟就搞定了， 这个是我做培训时用做的笔记详细的笔记

select m.v_userid         as "userId",
       m.v_context        as "errorMsg",
       content.error_code as "errorCode"
  from (select mobil.v_userid,
               mobil.v_context,
               row_number() over(partition by mobil.v_userid order by mobil.v_createdate desc) rn
          from t_b_ane_mobileerror mobil
         where exists (select t.id
                  from t_accepted_customer_info t
                 where t.mobilestate != 2
                   and t.accopenupdate >= :1
                   and t.accopenupdate < :2
                   and (upper(t.recommendidno) = :3 || 'W2' or
                       upper(t.recommendidno) = :4 || 'BD' or
                       upper(t.recommendidno) = :5)
                   and mobil.v_userid = t.userid)) m
  left join (select content_id, keyword, variable_two as error_code
               from t_sms_content_templet
              where content_no = 183
                and variable_two is not null
             union all
             select content_id, keyword, variable_one as error_code
               from t_sms_content_templet
              where content_no = 990
                and content_id <> '115') content
    on m.v_context like '%' || content.keyword || '%'
   and m.v_context is not null
   and content.error_code is not null
   and m.rn = 1



--生产真实的执行计划如下（TMD看不到谓词过滤信息）：
-------------------------------------------------------------------------------------------------------------
| Id  | Operation                        | Name                     | Rows  | Bytes | Cost (%CPU)| Time     |
-------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                 |                          |       |       | 18550 (100)|          |
|   1 |  NESTED LOOPS OUTER              |                          |    44 | 94644 | 18550   (2)| 00:03:43 |
|   2 |   VIEW                           |                          |     1 |  2049 | 18536   (2)| 00:03:43 |
|   3 |    WINDOW SORT                   |                          |     1 |   122 | 18536   (2)| 00:03:43 |
|   4 |     FILTER                       |                          |       |       |            |          |
|   5 |      HASH JOIN RIGHT SEMI        |                          |     1 |   122 | 18535   (2)| 00:03:43 |
|   6 |       TABLE ACCESS BY INDEX ROWID| T_ACCEPTED_CUSTOMER_INFO |     1 |    39 |     5   (0)| 00:00:01 |
|   7 |        INDEX RANGE SCAN          | IDX_ACCOPENUPDATE        |     1 |       |     3   (0)| 00:00:01 |
|   8 |       TABLE ACCESS FULL          | T_B_ANE_MOBILEERROR      |  4850K|   383M| 18450   (2)| 00:03:42 |
|   9 |   VIEW                           |                          |    44 |  4488 |    14   (0)| 00:00:01 |
|  10 |    FILTER                        |                          |       |       |            |          |
|  11 |     VIEW                         |                          |    44 |  8976 |    14   (0)| 00:00:01 |
|  12 |      UNION-ALL                   |                          |       |       |            |          |
|  13 |       TABLE ACCESS FULL          | T_SMS_CONTENT_TEMPLET    |    18 |  1224 |     7   (0)| 00:00:01 |
|  14 |       TABLE ACCESS FULL          | T_SMS_CONTENT_TEMPLET    |    26 |  2600 |     7   (0)| 00:00:01 |
-------------------------------------------------------------------------------------------------------------
 
Note
-----
   - cardinality feedback used for this statement


/*

目测了一下：
这条SQL非常简单, 大致理解为m left join content
从执行计划中看， 
T_B_ANE_MOBILEERROR　　CBO预估返回4850K　　, 走了全表扫描， 其余的全部都是小表
如果统计信息准确的话， 这一步就是导致出性能问题的根源了。

*/



-- 以下是在UAT环境中做的测试
-- T_SMS_CONTENT_TEMPLET  消息模板表  几百条记录
-- T_ACCEPTED_CUSTOMER_INFO 客户流水表之类的  400百万记录 过滤条件可以走索引 access("T"."ACCOPENUPDATE">=:1 AND "T"."ACCOPENUPDATE"<:2)
-- T_B_ANE_MOBILEERROR 这个是APP错误日志表 测试环境1715698数据

 Plan Hash Value  : 1780157300 

----------------------------------------------------------------------------------------------------------------
| Id   | Operation                          | Name                     | Rows    | Bytes     | Cost | Time     |
----------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                   |                          |      34 |     76398 | 6904 | 00:01:23 |
|    1 |   NESTED LOOPS OUTER               |                          |      34 |     76398 | 6904 | 00:01:23 |
|    2 |    VIEW                            |                          |       2 |      4290 | 6880 | 00:01:23 |
|    3 |     WINDOW SORT                    |                          |       2 |       268 | 6880 | 00:01:23 |
|  * 4 |      FILTER                        |                          |         |           |      |          |
|  * 5 |       HASH JOIN RIGHT SEMI         |                          |       2 |       268 | 6879 | 00:01:23 |
|  * 6 |        TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |      14 |       616 |  225 | 00:00:03 |
|  * 7 |         INDEX RANGE SCAN           | IDX_ACCOPENUPDATE        |    1387 |           |    9 | 00:00:01 |
|    8 |        TABLE ACCESS FULL           | T_B_ANE_MOBILEERROR      | 1662130 | 149591700 | 6643 | 00:01:20 |
|    9 |    VIEW                            |                          |      17 |      1734 |   12 | 00:00:01 |
| * 10 |     FILTER                         |                          |         |           |      |          |
| * 11 |      VIEW                          |                          |      17 |      3468 |   12 | 00:00:01 |
|   12 |       UNION-ALL                    |                          |         |           |      |          |
| * 13 |        TABLE ACCESS FULL           | T_SMS_CONTENT_TEMPLET    |       5 |       210 |    6 | 00:00:01 |
| * 14 |        TABLE ACCESS FULL           | T_SMS_CONTENT_TEMPLET    |      12 |      1200 |    6 | 00:00:01 |
----------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 4 - filter(:1<:2)
* 5 - access("T"."USERID"=TO_NUMBER("MOBIL"."V_USERID"))
* 6 - filter((UPPER("T"."RECOMMENDIDNO")=:5 OR UPPER("T"."RECOMMENDIDNO")=:3||'W2' OR UPPER("T"."RECOMMENDIDNO")=:4||'BD') AND TO_NUMBER("T"."MOBILESTATE")<>2)
* 7 - access("T"."ACCOPENUPDATE">=:1 AND "T"."ACCOPENUPDATE"<:2)
* 10 - filter("M"."RN"=1 AND "M"."V_CONTEXT" IS NOT NULL)
* 11 - filter("M"."V_CONTEXT" LIKE '%'||"CONTENT"."KEYWORD"||'%')
* 13 - filter("VARIABLE_TWO" IS NOT NULL AND "CONTENT_NO"=183)
* 14 - filter("CONTENT_NO"=990 AND "VARIABLE_ONE" IS NOT NULL AND "CONTENT_ID"<>115)


-- 分析

我问了开发人员， 这是一个后台系统的SQL， 可以选择开始、结束日期进行查询， 
且前端做了限制， 最多只能查询近一周的，默认是查询最近一天的错误信息

T_ACCEPTED_CUSTOMER_INFO.ACCOPENUPDATE 既然是个字符串
access("T"."ACCOPENUPDATE">=:1 AND "T"."ACCOPENUPDATE"<:2)

看看每天的数据量


select /*+ parallel(8) */
 substr(accopenupdate, '0', 10), count(*)
  from t_accepted_customer_info
  where accopenupdate is not null
 group by substr(accopenupdate, '0', 10)
 order by 2 desc;

2016-03-02  257970
2016-12-13  22596
2016-12-10  21577
2016-12-12  1744
2015-06-08  223
2015-06-10  99
2017-01-04  51
2017-01-05  48
2017-11-29  44
2016-12-19  38
2017-08-31  38
2017-02-28  37





既然其它的表返回的数据都不多，
那就只有 T_B_ANE_MOBILEERROR 是大表，那看看是否可以让 T_B_ANE_MOBILEERROR 做NL的被驱动表， 避免全表扫描

select mobil.v_userid,
               mobil.v_context,
               row_number() over(partition by mobil.v_userid order by mobil.v_createdate desc) rn
          from t_b_ane_mobileerror mobil
         where exists (select t.id
                  from t_accepted_customer_info t
                 where t.mobilestate != 2
                   and t.accopenupdate >= :1
                   and t.accopenupdate < :2
                   and (upper(t.recommendidno) = :3 || 'W2' or
                       upper(t.recommendidno) = :4 || 'BD' or
                       upper(t.recommendidno) = :5)
                   and mobil.v_userid = t.userid)

关联列为 v_userid
查看下 T_B_ANE_MOBILEERROR 表 V_USERID 列的索引信息
select i.owner,
       i.table_name,
       i.index_type,
       c.column_name,
       c.column_position
  from all_indexes i
 inner join all_ind_columns c
    on (i.owner = c.index_owner and i.index_name = c.index_name)
 where i.table_name = upper('T_B_ANE_MOBILEERROR')
   and c.column_name = upper('V_USERID')
 order by c.column_position

OWNER   TABLE_NAME          INDEX_TYPE  COLUMN_NAME COLUMN_POSITION
------- ------------------- ----------  ----------- ---------------
SISDATA T_B_ANE_MOBILEERROR NORMAL      V_USERID    1


是有索引信息的， 那这种情况CBO一般会选择走NL， 可是从执行计划中可以看出走的是HASH JOIN （id=5），
再看看谓词过滤信息
* 5 - access("T"."USERID"=TO_NUMBER("MOBIL"."V_USERID"))

卧槽 ， 又是关联列类型不匹配导致走不了索引， 索引CBO选择了走HASH 连接， 导致T_B_ANE_MOBILEERROR走全表扫描。。


--- 修改后的SQL
select m.v_userid         as "userId",
       m.v_context        as "errorMsg",
       content.error_code as "errorCode"
  from (select mobil.v_userid,
               mobil.v_context,
               row_number() over(partition by mobil.v_userid order by mobil.v_createdate desc) rn
          from t_b_ane_mobileerror mobil
         where exists (select t.id
                  from t_accepted_customer_info t
                 where t.mobilestate != 2
                   and t.accopenupdate >= :1
                   and t.accopenupdate < :2
                   and (upper(t.recommendidno) = :3 || 'W2' or
                       upper(t.recommendidno) = :4 || 'BD' or
                       upper(t.recommendidno) = :5)
                   
                   --and mobil.v_userid = t.userid
                   and mobil.v_userid = to_char(t.userid)  
                   )) m
  left join (select content_id, keyword, variable_two as error_code
               from t_sms_content_templet
              where content_no = 183
                and variable_two is not null
             union all
             select content_id, keyword, variable_one as error_code
               from t_sms_content_templet
              where content_no = 990
                and content_id <> '115') content
    on m.v_context like '%' || content.keyword || '%'
   and m.v_context is not null
   and content.error_code is not null
   and m.rn = 1

 Plan Hash Value  : 1236735437 

------------------------------------------------------------------------------------------------------------
| Id   | Operation                            | Name                     | Rows | Bytes  | Cost | Time     |
------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                     |                          |  374 | 840378 |  519 | 00:00:07 |
|    1 |   NESTED LOOPS OUTER                 |                          |  374 | 840378 |  519 | 00:00:07 |
|    2 |    VIEW                              |                          |   22 |  47190 |  255 | 00:00:04 |
|    3 |     WINDOW SORT                      |                          |   22 |   2948 |  255 | 00:00:04 |
|  * 4 |      FILTER                          |                          |      |        |      |          |
|    5 |       NESTED LOOPS                   |                          |      |        |      |          |
|    6 |        NESTED LOOPS                  |                          |   22 |   2948 |  254 | 00:00:04 |
|    7 |         SORT UNIQUE                  |                          |   14 |    616 |  225 | 00:00:03 |
|  * 8 |          TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |   14 |    616 |  225 | 00:00:03 |
|  * 9 |           INDEX RANGE SCAN           | IDX_ACCOPENUPDATE        | 1387 |        |    9 | 00:00:01 |
| * 10 |         INDEX RANGE SCAN             | IDX_T_B_A_M_USERID       |    2 |        |    2 | 00:00:01 |
|   11 |        TABLE ACCESS BY INDEX ROWID   | T_B_ANE_MOBILEERROR      |    2 |    180 |    4 | 00:00:01 |
|   12 |    VIEW                              |                          |   17 |   1734 |   12 | 00:00:01 |
| * 13 |     FILTER                           |                          |      |        |      |          |
| * 14 |      VIEW                            |                          |   17 |   3468 |   12 | 00:00:01 |
|   15 |       UNION-ALL                      |                          |      |        |      |          |
| * 16 |        TABLE ACCESS FULL             | T_SMS_CONTENT_TEMPLET    |    5 |    210 |    6 | 00:00:01 |
| * 17 |        TABLE ACCESS FULL             | T_SMS_CONTENT_TEMPLET    |   12 |   1200 |    6 | 00:00:01 |
------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 4 - filter(:1<:2)
* 8 - filter((UPPER("T"."RECOMMENDIDNO")=:5 OR UPPER("T"."RECOMMENDIDNO")=:3||'W2' OR UPPER("T"."RECOMMENDIDNO")=:4||'BD') AND TO_NUMBER("T"."MOBILESTATE")<>2)
* 9 - access("T"."ACCOPENUPDATE">=:1 AND "T"."ACCOPENUPDATE"<:2)
* 10 - access("MOBIL"."V_USERID"=TO_CHAR("T"."USERID"))
* 13 - filter("M"."RN"=1 AND "M"."V_CONTEXT" IS NOT NULL)
* 14 - filter("M"."V_CONTEXT" LIKE '%'||"CONTENT"."KEYWORD"||'%')
* 16 - filter("VARIABLE_TWO" IS NOT NULL AND "CONTENT_NO"=183)
* 17 - filter("CONTENT_NO"=990 AND "VARIABLE_ONE" IS NOT NULL AND "CONTENT_ID"<>115)


现在 T_ACCEPTED_CUSTOMER_INFO 和 T_B_ANE_MOBILEERROR 就是走的NL连接了。。此时SQL几乎已经是秒出了









------------------------------------------------------------------------------------------------------

再来看看 m和content 关联

关联条件为
  () m left join () content
    on m.v_context like '%' || content.keyword || '%'
   and m.v_context is not null
   and content.error_code is not null
   and m.rn = 1

关联条件中有like ， 导致走不了HASH ， 只能走NL ， 且被驱动表无法走索引， 
这样当驱动表返回数据量比较多的时候， content子查询会被执行多次， 这里还好 T_SMS_CONTENT_TEMPLET 表数据量不多， 

--  我发现这个 union all 查询出来的数据量非常小， 
select content_id, keyword, variable_two as error_code
               from t_sms_content_templet
              where content_no = 183
                and variable_two is not null
             union all
             select content_id, keyword, variable_one as error_code
               from t_sms_content_templet
              where content_no = 990
                and content_id <> '115'

那我们完全可以把 content 内联视图 使用 with as /* materialize */ 来优化

with v_tmp as
 (select /*+ materialize */
   *
    from (select content_id, keyword, variable_two as error_code
            from t_sms_content_templet
           where content_no = 183
             and variable_two is not null
          union all
          select content_id, keyword, variable_one as error_code
            from t_sms_content_templet
           where content_no = 990
             and content_id <> '115'))
select m.v_userid         as "userId",
       m.v_context        as "errorMsg",
       content.error_code as "errorCode"
  from (select mobil.v_userid,
               mobil.v_context,
               row_number() over(partition by mobil.v_userid order by mobil.v_createdate desc) rn
          from t_b_ane_mobileerror mobil
         where exists (select t.id
                  from t_accepted_customer_info t
                 where t.mobilestate != 2
                   and t.accopenupdate >= :1
                   and t.accopenupdate < :2
                   and (upper(t.recommendidno) = :3 || 'W2' or
                       upper(t.recommendidno) = :4 || 'BD' or
                       upper(t.recommendidno) = :5)
                      --and mobil.v_userid = t.userid
                   and mobil.v_userid = to_char(t.userid))) m
  left join v_tmp content
    on m.v_context like '%' || content.keyword || '%'
   and m.v_context is not null
   and content.error_code is not null
   and m.rn = 1


 Plan Hash Value  : 595843322 

-------------------------------------------------------------------------------------------------------------
| Id   | Operation                             | Name                     | Rows | Bytes  | Cost | Time     |
-------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                      |                          |  374 | 840378 |  311 | 00:00:04 |
|    1 |   TEMP TABLE TRANSFORMATION           |                          |      |        |      |          |
|    2 |    LOAD AS SELECT                     | SYS_TEMP_0FD9FCEC9_D4EAF |      |        |      |          |
|    3 |     VIEW                              |                          |   17 |   1377 |   12 | 00:00:01 |
|    4 |      UNION-ALL                        |                          |      |        |      |          |
|  * 5 |       TABLE ACCESS FULL               | T_SMS_CONTENT_TEMPLET    |    5 |    230 |    6 | 00:00:01 |
|  * 6 |       TABLE ACCESS FULL               | T_SMS_CONTENT_TEMPLET    |   12 |   1200 |    6 | 00:00:01 |
|    7 |    NESTED LOOPS OUTER                 |                          |  374 | 840378 |  299 | 00:00:04 |
|    8 |     VIEW                              |                          |   22 |  47190 |  255 | 00:00:04 |
|    9 |      WINDOW SORT                      |                          |   22 |   3080 |  255 | 00:00:04 |
| * 10 |       FILTER                          |                          |      |        |      |          |
|   11 |        NESTED LOOPS                   |                          |      |        |      |          |
|   12 |         NESTED LOOPS                  |                          |   22 |   3080 |  254 | 00:00:04 |
|   13 |          SORT UNIQUE                  |                          |   14 |    700 |  225 | 00:00:03 |
| * 14 |           TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |   14 |    700 |  225 | 00:00:03 |
| * 15 |            INDEX RANGE SCAN           | IDX_ACCOPENUPDATE        | 1387 |        |    9 | 00:00:01 |
| * 16 |          INDEX RANGE SCAN             | IDX_T_B_A_M_USERID       |    2 |        |    2 | 00:00:01 |
|   17 |         TABLE ACCESS BY INDEX ROWID   | T_B_ANE_MOBILEERROR      |    2 |    180 |    4 | 00:00:01 |
|   18 |     VIEW                              |                          |   17 |   1734 |    2 | 00:00:01 |
| * 19 |      FILTER                           |                          |      |        |      |          |
| * 20 |       VIEW                            |                          |   17 |   3468 |    2 | 00:00:01 |
|   21 |        TABLE ACCESS FULL              | SYS_TEMP_0FD9FCEC9_D4EAF |   17 |   1377 |    2 | 00:00:01 |
-------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 5 - filter("VARIABLE_TWO" IS NOT NULL AND "CONTENT_NO"=183)
* 6 - filter("CONTENT_NO"=990 AND "CONTENT_ID"<>115)
* 10 - filter(:1<:2)
* 14 - filter((UPPER("T"."RECOMMENDIDNO")=:5 OR UPPER("T"."RECOMMENDIDNO")=:3||'W2' OR UPPER("T"."RECOMMENDIDNO")=:4||'BD') AND TO_NUMBER("T"."MOBILESTATE")<>2)
* 15 - access("T"."ACCOPENUPDATE">=:1 AND "T"."ACCOPENUPDATE"<:2)
* 16 - access("MOBIL"."V_USERID"=TO_CHAR("T"."USERID"))
* 19 - filter("M"."RN"=1 AND "M"."V_CONTEXT" IS NOT NULL)
* 20 - filter("M"."V_CONTEXT" LIKE '%'||"CONTENT"."KEYWORD"||'%' AND "CONTENT"."ERROR_CODE" IS NOT NULL)


此时的执行计划应该是最优的， 即时 T_SMS_CONTENT_TEMPLET 表数据量很大， content 内联视图也不会有性能问题 ， 
因为过滤后的数据量非常小。


------------------------------------------------------------------------------------------------------------
此时我以为这个SQL优化完了， 我突然发现 and m.rn = 1 这个过滤条件为什么不直接写在m的内联视图中进行过滤， 
然后我试着把 m.rn=1 写到内联视图中， TMD 此时返回的数据量既然和先前对不上了， 我们做SQL等价改写是绝对不能
改变SQL的返回结果的。。。。


我随意带入了几个值到SQL中进行查询

with v as
 (select /*+ materialize */
   *
    from (select keyword, variable_two as error_code
            from t_sms_content_templet
           where content_no = 183
             and variable_two is not null
          union all
          select keyword, variable_one as error_code
            from t_sms_content_templet
           where content_no = 990
             and content_id <> '115'))
select m.v_userid         as "userId",
      -- m.v_context        as "errorMsg",
       content.error_code as "errorCode",
       m.rn
  from (select * from (select mobil.v_userid,
               mobil.v_context,
               row_number() over(partition by mobil.v_userid order by mobil.v_createdate desc) rn
          from t_b_ane_mobileerror mobil
         where exists (select t.id
                  from t_accepted_customer_info t
                 where t.mobilestate != 2
                   and t.accopenupdate >= '2018-01-08 00:00:00'
                   and t.accopenupdate < '2018-01-18 00:00:00'
                      -- and (upper(t.recommendidno) = :3 || 'W2' or
                      --     upper(t.recommendidno) = :4 || 'BD' or
                      --     upper(t.recommendidno) = :5)
                   and mobil.v_userid = to_char(t.userid))
                  ) where rn = 1) m
  left join v content
    on m.v_context like '%' || content.keyword || '%'
   and m.v_context is not null
   and content.error_code is not null
  -- and m.rn = 1

这个查询出来的RN 值都是为1 的
userId  errorCode RN
10496806    1
10521488    1
10521656    1
10521763    1
10521779    1
10521821    1
10521828    1
10521837    1
10521850    1
10521853    1
10521928    1
10521946    1
10521952    1
10522015    1
10522020    1
10522067    1
10522084    1
10522105    1
10522108    1
10522121    1
10522144    1
10522150    1
10522154    1
10522209    1
10522214    1
10522223    1
10522288    1
10522390    1
10522395    1
10522461    1
10522463    1
10522626    1


原始SQL的查询结果为：

userId  errorCode RN
10496806    1
10496806    2
10496806    3
10496806    4
10496806    5
10496806    6
10496806    7
10496806    8
10521488    1
10521488    2
10521488    3
10521656    1
10521656    2
10521763    1
10521779    1
10521821    1
10521821    2
10521828    1
10521828    2
10521837    1
10521837    2
10521837    3
10521850    1
10521853    1
10521928    1
10521928    2
10521946    1
10521946    2
10521946    3
10521946    4
10521946    5
10521952    1
10522015    1
10522020    1
10522067    1
10522084    1
10522105    1
10522108    1
10522121    1
10522144    1
10522150    1
10522154    1
10522209    1
10522214    1
10522223    1
10522223    2
10522288    1
10522288    2
10522390    1
10522395    1
10522461    1
10522461    2
10522463    1
10522463    2
10522463    3
10522463    4
10522463    5
10522463    6
10522463    7
10522463    8
10522626    1


卧槽， 既然没有过滤掉RN不为1的， 这是为什么呢？？
首先我们看看SQL

select * from (select mobil.v_userid,
               mobil.v_context,
               row_number() over(partition by mobil.v_userid order by mobil.v_createdate desc) rn
          from t_b_ane_mobileerror mobil

这里是根据v_userid进行分区， 然后按照时间进行倒序排序， 
应该是想找到每个用户最近一次的报错信息


再看了一下SQL， 这次发现了点问题， 大爷的 m.rn=1 在这里是被当做关联条件进行查询了。。。
    on m.v_context like '%' || content.keyword || '%'
   and m.v_context is not null
   and content.error_code is not null
   and m.rn = 1


而我们的SQL是 left join ， 这里m是left表， 那就是说m表的记录这里全部都要返回的。。。

执行计划中也有一些蛛丝马迹

 Plan Hash Value  : 595843322 

-------------------------------------------------------------------------------------------------------------
| Id   | Operation                             | Name                     | Rows | Bytes  | Cost | Time     |
-------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                      |                          |  374 | 840378 |  311 | 00:00:04 |
|    1 |   TEMP TABLE TRANSFORMATION           |                          |      |        |      |          |
|    2 |    LOAD AS SELECT                     | SYS_TEMP_0FD9FCEC9_D4EAF |      |        |      |          |
|    3 |     VIEW                              |                          |   17 |   1377 |   12 | 00:00:01 |
|    4 |      UNION-ALL                        |                          |      |        |      |          |
|  * 5 |       TABLE ACCESS FULL               | T_SMS_CONTENT_TEMPLET    |    5 |    230 |    6 | 00:00:01 |
|  * 6 |       TABLE ACCESS FULL               | T_SMS_CONTENT_TEMPLET    |   12 |   1200 |    6 | 00:00:01 |
|    7 |    NESTED LOOPS OUTER                 |                          |  374 | 840378 |  299 | 00:00:04 |
|    8 |     VIEW                              |                          |   22 |  47190 |  255 | 00:00:04 |
|    9 |      WINDOW SORT                      |                          |   22 |   3080 |  255 | 00:00:04 |
| * 10 |       FILTER                          |                          |      |        |      |          |
|   11 |        NESTED LOOPS                   |                          |      |        |      |          |
|   12 |         NESTED LOOPS                  |                          |   22 |   3080 |  254 | 00:00:04 |
|   13 |          SORT UNIQUE                  |                          |   14 |    700 |  225 | 00:00:03 |
| * 14 |           TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |   14 |    700 |  225 | 00:00:03 |
| * 15 |            INDEX RANGE SCAN           | IDX_ACCOPENUPDATE        | 1387 |        |    9 | 00:00:01 |
| * 16 |          INDEX RANGE SCAN             | IDX_T_B_A_M_USERID       |    2 |        |    2 | 00:00:01 |
|   17 |         TABLE ACCESS BY INDEX ROWID   | T_B_ANE_MOBILEERROR      |    2 |    180 |    4 | 00:00:01 |
|   18 |     VIEW                              |                          |   17 |   1734 |    2 | 00:00:01 |
| * 19 |      FILTER                           |                          |      |        |      |          |
| * 20 |       VIEW                            |                          |   17 |   3468 |    2 | 00:00:01 |
|   21 |        TABLE ACCESS FULL              | SYS_TEMP_0FD9FCEC9_D4EAF |   17 |   1377 |    2 | 00:00:01 |
-------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 5 - filter("VARIABLE_TWO" IS NOT NULL AND "CONTENT_NO"=183)
* 6 - filter("CONTENT_NO"=990 AND "CONTENT_ID"<>115)
* 10 - filter(:1<:2)
* 14 - filter((UPPER("T"."RECOMMENDIDNO")=:5 OR UPPER("T"."RECOMMENDIDNO")=:3||'W2' OR UPPER("T"."RECOMMENDIDNO")=:4||'BD') AND TO_NUMBER("T"."MOBILESTATE")<>2)
* 15 - access("T"."ACCOPENUPDATE">=:1 AND "T"."ACCOPENUPDATE"<:2)
* 16 - access("MOBIL"."V_USERID"=TO_CHAR("T"."USERID"))
* 19 - filter("M"."RN"=1 AND "M"."V_CONTEXT" IS NOT NULL)
* 20 - filter("M"."V_CONTEXT" LIKE '%'||"CONTENT"."KEYWORD"||'%' AND "CONTENT"."ERROR_CODE" IS NOT NULL)

注意看ID=19的，  * 19 - filter("M"."RN"=1 AND "M"."V_CONTEXT" IS NOT NULL)


|   18 |     VIEW                              |                          |   17 |   1734 |    2 | 00:00:01 |
| * 19 |      FILTER                           |                          |      |        |      |          |
| * 20 |       VIEW                            |                          |   17 |   3468 |    2 | 00:00:01 |
|   21 |        TABLE ACCESS FULL              | SYS_TEMP_0FD9FCEC9_D4EAF |   17 |   1377 |    2 | 00:00:01 |
-------------------------------------------------------------------------------------------------------------

这里我们明明是在m内联视图上进行过滤的， 但是这里既然跑到 content的那个视图进行过滤的， （因为改成了with  as materialize ）,
所以执行计划中显示的是 SYS_TEMP_0FD9FCEC9_D4EAF

卧槽， 赶紧问了下他们那边的开发人员， 到底是要哪一种数据， 他们说只要rn=1的数据。。。SQL都上线了既然没人发现问题, 卧槽

最后的SQL应该是这样子的.

with v_tmp as
 (select /*+ materialize */
   *
    from (select content_id, keyword, variable_two as error_code
            from t_sms_content_templet
           where content_no = 183
             and variable_two is not null
          union all
          select content_id, keyword, variable_one as error_code
            from t_sms_content_templet
           where content_no = 990
             and content_id <> '115'))
select m.v_userid         as "userId",
       m.v_context        as "errorMsg",
       content.error_code as "errorCode"
  from (select *
          from (select mobil.v_userid,
                       mobil.v_context,
                       row_number() over(partition by mobil.v_userid order by mobil.v_createdate desc) rn
                  from t_b_ane_mobileerror mobil
                 where exists
                 (select t.id
                          from t_accepted_customer_info t
                         where t.mobilestate != 2
                           and t.accopenupdate >= :1
                           and t.accopenupdate < :2
                           and (upper(t.recommendidno) = :3 || 'W2' or
                               upper(t.recommendidno) = :4 || 'BD' or
                               upper(t.recommendidno) = :5)
                           and mobil.v_userid = to_char(t.userid)))
         where rn = 1) m
  left join v_tmp content
    on m.v_context like '%' || content.keyword || '%'
   and m.v_context is not null
   and content.error_code is not null
