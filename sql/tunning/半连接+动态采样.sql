-- 该SQL返回26行数据， 耗时5秒多
select bakinfo.id, bakinfo.userid, bakinfo.openstate, bakinfo.mobilestate
  from t_accepted_customer_info bakinfo
 where bakinfo.userid in
       (select distinct i.userid
          from t_accepted_customer_info i, t_accepted_schedule s
         where i.userid = s.user_id
           and i.mobilestate is null
           and i.bankcode is not null
           and ((s.lastcomplete_step = 'certintall' or
               s.lastcomplete_step = 'witness') and i.source in (5, 6, 7))
           and i.accopenupdate <=
               to_char(sysdate - 7 / 24 / 60, 'yyyy-mm-dd HH24:MI:SS'))

 Plan Hash Value  : 1592046924 

-------------------------------------------------------------------------------------------------
| Id  | Operation              | Name                     | Rows   | Bytes   | Cost  | Time     |
-------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT       |                          |   7373 |  228563 | 19548 | 00:03:55 |
| * 1 |   HASH JOIN RIGHT SEMI |                          |   7373 |  228563 | 19548 | 00:03:55 |
|   2 |    VIEW                | VW_NSO_1                 |   7351 |   95563 | 10070 | 00:02:01 |
| * 3 |     HASH JOIN          |                          |   7351 |  448411 | 10070 | 00:02:01 |
| * 4 |      TABLE ACCESS FULL | T_ACCEPTED_SCHEDULE      |   7350 |  102900 |   592 | 00:00:08 |
| * 5 |      TABLE ACCESS FULL | T_ACCEPTED_CUSTOMER_INFO |  14782 |  694754 |  9477 | 00:01:54 |
|   6 |    TABLE ACCESS FULL   | T_ACCEPTED_CUSTOMER_INFO | 307255 | 5530590 |  9476 | 00:01:54 |
-------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 1 - access("BAKINFO"."USERID"="USERID")
* 3 - access("I"."USERID"=TO_NUMBER("S"."USER_ID"))
* 4 - filter("S"."LASTCOMPLETE_STEP"='certintall' OR "S"."LASTCOMPLETE_STEP"='witness')
* 5 - filter("I"."MOBILESTATE" IS NULL AND "I"."BANKCODE" IS NOT NULL AND (TO_NUMBER("I"."SOURCE")=5 OR TO_NUMBER("I"."SOURCE")=6 OR TO_NUMBER("I"."SOURCE")=7) AND
  "I"."ACCOPENUPDATE"<=TO_CHAR(SYSDATE@!-.004861111111111111111111111111111111111111,'yyyy-mm-dd HH24:MI:SS'))      




执行计划中都是走的HASH,且都是全表扫描。
但是SQL结果只返回26行记录， t_accepted_customer_info和t_accepted_schedule表的连接列userid的基数都超级高， 基本上相当于唯一。按理说应该走NL，且肯定有哪个过滤条件过滤条了大部分数据。

根据SQL三段拆分大法，先对in里面的子查询进行单独优化。

in子查询SQL的执行计划, 该SQL返回
select i.userid
  from t_accepted_customer_info i, t_accepted_schedule s
 where i.userid = s.user_id
   and i.mobilestate is null
   and i.bankcode is not null
   and ((s.lastcomplete_step = 'certintall' or
       s.lastcomplete_step = 'witness') and i.source in (5, 6, 7))
   and i.accopenupdate <=
       to_char(sysdate - 7 / 24 / 60, 'yyyy-mm-dd HH24:MI:SS')


 Plan Hash Value  : 3903833919 

---------------------------------------------------------------------------------------------
| Id  | Operation            | Name                     | Rows  | Bytes  | Cost  | Time     |
---------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT     |                          |  7351 | 448411 | 10070 | 00:02:01 |
| * 1 |   HASH JOIN          |                          |  7351 | 448411 | 10070 | 00:02:01 |
| * 2 |    TABLE ACCESS FULL | T_ACCEPTED_SCHEDULE      |  7350 | 102900 |   592 | 00:00:08 |
| * 3 |    TABLE ACCESS FULL | T_ACCEPTED_CUSTOMER_INFO | 14782 | 694754 |  9477 | 00:01:54 |
---------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 1 - access("I"."USERID"=TO_NUMBER("S"."USER_ID"))
* 2 - filter("S"."LASTCOMPLETE_STEP"='certintall' OR "S"."LASTCOMPLETE_STEP"='witness')
* 3 - filter("I"."MOBILESTATE" IS NULL AND "I"."BANKCODE" IS NOT NULL AND (TO_NUMBER("I"."SOURCE")=5 OR TO_NUMBER("I"."SOURCE")=6 OR TO_NUMBER("I"."SOURCE")=7) AND
  "I"."ACCOPENUPDATE"<=TO_CHAR(SYSDATE@!-.004861111111111111111111111111111111111111,'yyyy-mm-dd HH24:MI:SS'))



select count(*) from t_accepted_customer_info i; -- Num_Rows:307255 Cols:232  大宽表
select count(*) from t_accepted_schedule i; -- Num_Rows:158118  Cols:26

从上面的执行计划中可以看到id=3的过滤信息中SOURCE字段进行了强制类型转换,而t_accepted_customer_info表上有一个组合索引,创建信息如下
IDX_CUACCT_TASKTYPE(MOBILESTATE, TASKTYPE, OPENSTATE, SOURCE)
把过滤条件改成 i.source in ('5', '6', '7');
select count(*)
  from t_accepted_customer_info i
 where i.mobilestate is null
   and i.bankcode is not null
   and i.source in ('5', '6', '7');  -- 过滤后返回1172行记录， 从307255中选择1172行记录，走索引肯定秒杀。

再看执行计划中的id=1的，关联条件 access("I"."USERID"=TO_NUMBER("S"."USER_ID"))，也是进行了强制类型转换， 导致走不了NL。。。。

把上面的问题都修改过后...SQL以及执行计划如下

select i.userid
  from t_accepted_customer_info i, t_accepted_schedule s
 where to_char(i.userid) = s.user_id
   and i.mobilestate is null
   and i.bankcode is not null
   and ((s.lastcomplete_step = 'certintall' or
        s.lastcomplete_step = 'witness') and i.source in ('5', '6', '7'))
   and i.accopenupdate <=
       to_char(sysdate - 7 / 24 / 60, 'yyyy-mm-dd HH24:MI:SS')   


 Plan Hash Value  : 2854946559 

------------------------------------------------------------------------------------------------------
| Id  | Operation                      | Name                     | Rows  | Bytes  | Cost | Time     |
------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT               |                          |  7351 | 448411 | 4603 | 00:00:56 |
| * 1 |   HASH JOIN                    |                          |  7351 | 448411 | 4603 | 00:00:56 |
| * 2 |    TABLE ACCESS FULL           | T_ACCEPTED_SCHEDULE      |  7350 | 102900 |  592 | 00:00:08 |
| * 3 |    TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO | 17089 | 803183 | 4011 | 00:00:49 |
| * 4 |     INDEX RANGE SCAN           | IDX_CUACCT_TASKTYPE      | 23672 |        |  201 | 00:00:03 |
------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 1 - access("S"."USER_ID"=TO_CHAR("I"."USERID"))
* 2 - filter("S"."LASTCOMPLETE_STEP"='certintall' OR "S"."LASTCOMPLETE_STEP"='witness')
* 3 - filter("I"."BANKCODE" IS NOT NULL AND "I"."ACCOPENUPDATE"<=TO_CHAR(SYSDATE@!-.004861111111111111111111111111111111111111,'yyyy-mm-dd HH24:MI:SS'))
* 4 - access("I"."MOBILESTATE" IS NULL)
* 4 - filter("I"."SOURCE"='5' OR "I"."SOURCE"='6' OR "I"."SOURCE"='7')


此时SQL还是走的HASH连接，是因为CBO错误的估算了T_ACCEPTED_CUSTOMER_INFO过滤后返回的行数为23672，实际上过滤后返回1172行。
（这里可能是过滤条件过多导致CBO估算错误,或者是统计信息过期）， 我们可以强制使用HINT让其走我们想要的执行计划，或者是用动态采样Level=4即可
select /*+ dynamic_sampling(i 4) use_nl(i s)*/ i.userid
  from t_accepted_customer_info i, t_accepted_schedule s
 where to_char(i.userid) = s.user_id
   and i.mobilestate is null
   and i.bankcode is not null
   and ((s.lastcomplete_step = 'certintall' or
        s.lastcomplete_step = 'witness') and i.source in ('5', '6', '7'))
   and i.accopenupdate <=
       to_char(sysdate - 7 / 24 / 60, 'yyyy-mm-dd HH24:MI:SS')

 Plan Hash Value  : 3718024927 

------------------------------------------------------------------------------------------------------
| Id  | Operation                       | Name                     | Rows  | Bytes | Cost | Time     |
------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                |                          |   959 | 58499 | 6889 | 00:01:23 |
|   1 |   NESTED LOOPS                  |                          |       |       |      |          |
|   2 |    NESTED LOOPS                 |                          |   959 | 58499 | 6889 | 00:01:23 |
| * 3 |     TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |   959 | 45073 | 4011 | 00:00:49 |
| * 4 |      INDEX RANGE SCAN           | IDX_CUACCT_TASKTYPE      | 23672 |       |  201 | 00:00:03 |
| * 5 |     INDEX RANGE SCAN            | IDX_SCHEDULE_USERID      |     1 |       |    2 | 00:00:01 |
| * 6 |    TABLE ACCESS BY INDEX ROWID  | T_ACCEPTED_SCHEDULE      |     1 |    14 |    3 | 00:00:01 |
------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 3 - filter("I"."BANKCODE" IS NOT NULL AND "I"."ACCOPENUPDATE"<=TO_CHAR(SYSDATE@!-.004861111111111111111111111111111111111111,'yyyy-mm-dd HH24:MI:SS'))
* 4 - access("I"."MOBILESTATE" IS NULL)
* 4 - filter("I"."SOURCE"='5' OR "I"."SOURCE"='6' OR "I"."SOURCE"='7')
* 5 - access("S"."USER_ID"=TO_CHAR("I"."USERID"))
* 6 - filter("S"."LASTCOMPLETE_STEP"='certintall' OR "S"."LASTCOMPLETE_STEP"='witness')


Note
-----
- dynamic sampling used for this statement       

此时， in子查询已经优化完毕了，把优化完的SQL替换原有的in子查询即可。

select bakinfo.id, bakinfo.userid, bakinfo.openstate, bakinfo.mobilestate
  from t_accepted_customer_info bakinfo
 where bakinfo.userid in
       (select /*+ dynamic_sampling(i 4) use_nl(i s)*/
         i.userid
          from t_accepted_customer_info i, t_accepted_schedule s
         where to_char(i.userid) = s.user_id
           and i.mobilestate is null
           and i.bankcode is not null
           and ((s.lastcomplete_step = 'certintall' or
                s.lastcomplete_step = 'witness') and
                i.source in ('5', '6', '7'))
           and i.accopenupdate <=
               to_char(sysdate - 7 / 24 / 60, 'yyyy-mm-dd HH24:MI:SS'))

Plan Hash Value  : 1410735202 

-------------------------------------------------------------------------------------------------------------
| Id   | Operation                           | Name                       | Rows  | Bytes | Cost | Time     |
-------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                    |                            |   962 | 29822 | 9769 | 00:01:58 |
|    1 |   NESTED LOOPS                      |                            |       |       |      |          |
|    2 |    NESTED LOOPS                     |                            |   962 | 29822 | 9769 | 00:01:58 |
|    3 |     VIEW                            | VW_NSO_1                   |   959 | 12467 | 6889 | 00:01:23 |
|    4 |      HASH UNIQUE                    |                            |   959 | 58499 |      |          |
|    5 |       NESTED LOOPS                  |                            |       |       |      |          |
|    6 |        NESTED LOOPS                 |                            |   959 | 58499 | 6889 | 00:01:23 |
|  * 7 |         TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO   |   959 | 45073 | 4011 | 00:00:49 |
|  * 8 |          INDEX RANGE SCAN           | IDX_CUACCT_TASKTYPE        | 23672 |       |  201 | 00:00:03 |
|  * 9 |         INDEX RANGE SCAN            | IDX_SCHEDULE_USERID        |     1 |       |    2 | 00:00:01 |
| * 10 |        TABLE ACCESS BY INDEX ROWID  | T_ACCEPTED_SCHEDULE        |     1 |    14 |    3 | 00:00:01 |
| * 11 |     INDEX RANGE SCAN                | CUSTOMER_INF_INDEX_OUSERID |     1 |       |    2 | 00:00:01 |
|   12 |    TABLE ACCESS BY INDEX ROWID      | T_ACCEPTED_CUSTOMER_INFO   |     1 |    18 |    3 | 00:00:01 |
-------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 7 - filter("I"."BANKCODE" IS NOT NULL AND "I"."ACCOPENUPDATE"<=TO_CHAR(SYSDATE@!-.004861111111111111111111111111111111111111,'yyyy-mm-dd HH24:MI:SS'))
* 8 - access("I"."MOBILESTATE" IS NULL)
* 8 - filter("I"."SOURCE"='5' OR "I"."SOURCE"='6' OR "I"."SOURCE"='7')
* 9 - access("S"."USER_ID"=TO_CHAR("I"."USERID"))
* 10 - filter("S"."LASTCOMPLETE_STEP"='certintall' OR "S"."LASTCOMPLETE_STEP"='witness')
* 11 - access("BAKINFO"."USERID"="USERID")


Note
-----
- dynamic sampling used for this statement


校验了结果， 是之前是对的上的。SQL也在0.1秒内查询出结果。






其实仔细检查上述SQL，T_ACCEPTED_CUSTOMER_INFO这个表被访问了两次， 这个是没有必要的。
因为in子查询里面就有访问T_ACCEPTED_CUSTOMER_INFO这个表， 我们只需要在in子查询里面查询我们需要的字段， 且做distinct操作即可。



select /*+ dynamic_sampling(i 4) use_nl(i s)*/
distinct i.id, i.userid, i.openstate, i.mobilestate
  from t_accepted_customer_info i, t_accepted_schedule s
 where to_char(i.userid) = s.user_id
   and i.mobilestate is null
   and i.bankcode is not null
   and ((s.lastcomplete_step = 'certintall' or
        s.lastcomplete_step = 'witness') and i.source in ('5', '6', '7'))
   and i.accopenupdate <=
       to_char(sysdate - 7 / 24 / 60, 'yyyy-mm-dd HH24:MI:SS')


