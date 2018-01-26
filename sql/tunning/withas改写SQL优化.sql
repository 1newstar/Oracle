-- 下面这条SQL是从TOP SQL 中抓出来的,返回0条记录, 但是要跑好几分钟
select i.mobileno,
       i.custname,
       i.user_code,
       i.userid,
       i.cuacct_code,
       s.open_step,
       s.current_step,
       i.accopenupdate as update_time
  from t_accepted_customer_info i
 inner join t_accepted_schedule s
    on i.userid = s.user_id
 where nvl(is_shortcut_sign, 0) != 2
   and (i.accopenupdate between :1 and :2)
   and not exists
 (select o.id
          from t_b_openaccountpush o
         where o.mobile = i.mobileno
           and o.cust_name = i.custname)
   and i.userid in (select max(userid) userid
                      from t_accepted_customer_info
                     where source is null
                     group by custname, mobileno)
 order by i.accopenupdate asc


  Plan Hash Value  : 3250277162 

--------------------------------------------------------------------------------------------------------------
| Id   | Operation                          | Name                     | Rows   | Bytes   | Cost  | Time     |
--------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                   |                          |      1 |      93 | 10776 | 00:02:10 |
|    1 |   SORT ORDER BY                    |                          |      1 |      93 | 10776 | 00:02:10 |
|  * 2 |    FILTER                          |                          |        |         |       |          |
|  * 3 |     FILTER                         |                          |        |         |       |          |
|  * 4 |      HASH JOIN                     |                          |      1 |      93 |  1360 | 00:00:17 |
|  * 5 |       HASH JOIN ANTI               |                          |      1 |      79 |   770 | 00:00:10 |
|  * 6 |        TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |     38 |    2242 |   220 | 00:00:03 |
|  * 7 |         INDEX RANGE SCAN           | IDX_ACCOPENUPDATE        |   1383 |         |     9 | 00:00:01 |
|    8 |        TABLE ACCESS FULL           | T_B_OPENACCOUNTPUSH      |  74072 | 1481440 |   549 | 00:00:07 |
|    9 |       TABLE ACCESS FULL            | T_ACCEPTED_SCHEDULE      | 154882 | 2168348 |   588 | 00:00:08 |
| * 10 |     FILTER                         |                          |        |         |       |          |
|   11 |      HASH GROUP BY                 |                          |    461 |   16135 |  9415 | 00:01:53 |
| * 12 |       TABLE ACCESS FULL            | T_ACCEPTED_CUSTOMER_INFO |  46035 | 1611225 |  9412 | 00:01:53 |
--------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 2 - filter( EXISTS (SELECT 0 FROM "SISDATA"."T_ACCEPTED_CUSTOMER_INFO" "T_ACCEPTED_CUSTOMER_INFO" WHERE "SOURCE" IS NULL GROUP BY "CUSTNAME","MOBILENO" HAVING MAX("USERID")=:B1))
* 3 - filter(:1<=:2)
* 4 - access("I"."USERID"=TO_NUMBER("S"."USER_ID"))
* 5 - access("O"."MOBILE"="I"."MOBILENO" AND "O"."CUST_NAME"="I"."CUSTNAME")
* 6 - filter(TO_NUMBER(NVL("I"."IS_SHORTCUT_SIGN",'0'))<>2)
* 7 - access("I"."ACCOPENUPDATE">=:1 AND "I"."ACCOPENUPDATE"<=:2)
* 10 - filter(MAX("USERID")=:B1)
* 12 - filter("SOURCE" IS NULL)


--这是几张基表的信息, 我在UAT环境做的试验
select count(*) from t_accepted_customer_info; -- 307245
select count(*) from t_accepted_schedule; -- 158074
select count(*) from t_b_openaccountpush; -- 74074


:::::::::::::::问题分析:::::::::::::::
第一眼看执行计划，ID=10作为Filter的被驱动表,会被扫描多次,也就是in里面的子查询会被反复执行N次,最大的问题就是出现在这里了。

in里面的子查询单独跑要9秒左右
(select max(userid) userid
                      from t_accepted_customer_info
                     where source is null
                     group by custname, mobileno)



:::::::::::::::优化第一阶段:::::::::::::::
先用with as  /*+ materialize */ 试试效果

with xxx as (select /*+ materialize */ max(userid) userid
                      from t_accepted_customer_info
                     where source is null
                     group by custname, mobileno)
select i.mobileno,
       i.custname,
       i.user_code,
       i.userid,
       i.cuacct_code,
       s.open_step,
       s.current_step,
       i.accopenupdate as update_time
  from t_accepted_customer_info i
 inner join t_accepted_schedule s
    on i.userid = s.user_id
 where nvl(is_shortcut_sign, 0) != 2
   and (i.accopenupdate between '2017-07-25 10:44:35' and
        '2017-08-25 10:44:35')
   and not exists
 (select o.id
          from t_b_openaccountpush o
         where o.mobile = i.mobileno
           and o.cust_name = i.custname)
   and i.userid in (select user_id from xxx)
 order by i.accopenupdate asc;


 Plan Hash Value  : 3197994549 

--------------------------------------------------------------------------------------------------------------
| Id   | Operation                          | Name                     | Rows   | Bytes   | Cost  | Time     |
--------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                   |                          |      1 |      93 | 11057 | 00:02:13 |
|    1 |   TEMP TABLE TRANSFORMATION        |                          |        |         |       |          |
|    2 |    LOAD AS SELECT                  | SYS_TEMP_0FD9FCC12_D4EAF |        |         |       |          |
|    3 |     HASH GROUP BY                  |                          |  46035 | 1611225 |  9845 | 00:01:59 |
|  * 4 |      TABLE ACCESS FULL             | T_ACCEPTED_CUSTOMER_INFO |  46035 | 1611225 |  9412 | 00:01:53 |
|    5 |    SORT ORDER BY                   |                          |      1 |      93 |  1212 | 00:00:15 |
|  * 6 |     FILTER                         |                          |        |         |       |          |
|  * 7 |      HASH JOIN                     |                          |      1 |      93 |  1149 | 00:00:14 |
|  * 8 |       HASH JOIN ANTI               |                          |      1 |      79 |   560 | 00:00:07 |
|  * 9 |        TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |      2 |     118 |    10 | 00:00:01 |
| * 10 |         INDEX RANGE SCAN           | IDX_ACCOPENUPDATE        |     46 |         |     3 | 00:00:01 |
|   11 |        TABLE ACCESS FULL           | T_B_OPENACCOUNTPUSH      |  74072 | 1481440 |   549 | 00:00:07 |
|   12 |       TABLE ACCESS FULL            | T_ACCEPTED_SCHEDULE      | 154882 | 2168348 |   588 | 00:00:08 |
| * 13 |      FILTER                        |                          |        |         |       |          |
|   14 |       VIEW                         |                          |  46035 |         |    62 | 00:00:01 |
|   15 |        TABLE ACCESS FULL           | SYS_TEMP_0FD9FCC12_D4EAF |  46035 |  598455 |    62 | 00:00:01 |
--------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 4 - filter("SOURCE" IS NULL)
* 6 - filter( EXISTS (SELECT 0 FROM (SELECT /*+ CACHE_TEMP_TABLE ("T1") */ "C0" "USERID" FROM "SYS"."SYS_TEMP_0FD9FCC12_D4EAF" "T1") "XXX" WHERE TO_NUMBER(:B1)=:B2))
* 7 - access("I"."USERID"=TO_NUMBER("S"."USER_ID"))
* 8 - access("O"."MOBILE"="I"."MOBILENO" AND "O"."CUST_NAME"="I"."CUSTNAME")
* 9 - filter(TO_NUMBER(NVL("I"."IS_SHORTCUT_SIGN",'0'))<>2)
* 10 - access("I"."ACCOPENUPDATE">='2017-07-25 10:44:35' AND "I"."ACCOPENUPDATE"<='2017-08-25 10:44:35')
* 13 - filter(TO_NUMBER(:B1)=:B2) 


****使用了with as /*+ materialize */ 之后，SQL基本上1.3秒就出结果了****





:::::::::::::::优化第二阶段:::::::::::::::
因为公司经常有SB把关联列的类型搞的不一样，所以几乎每次优化都会先看下 Predicate Information 里面的信息。

发现ID=7的关联条件 
* 7 - access("I"."USERID"=TO_NUMBER("S"."USER_ID"))
果然又是关联列类型不一致,导致无法传值走索引而没有选择NL!

with xxx as
 (select /*+ materialize */
   max(userid) userid
    from t_accepted_customer_info
   where source is null
   group by custname, mobileno)
select i.mobileno,
       i.custname,
       i.user_code,
       i.userid,
       i.cuacct_code,
       s.open_step,
       s.current_step,
       i.accopenupdate as update_time
  from t_accepted_customer_info i
 inner join t_accepted_schedule s
    on to_char(i.userid) = s.user_id  -- 关联条件改to_char
 where nvl(is_shortcut_sign, 0) != 2
   and (i.accopenupdate between '2017-07-25 10:44:35' and
        '2017-08-25 10:44:35')
   and not exists (select o.id
          from t_b_openaccountpush o
         where o.mobile = i.mobileno
           and o.cust_name = i.custname)
   and i.userid in (select user_id from xxx)
 order by i.accopenupdate asc;


 Plan Hash Value  : 2129582179 

-------------------------------------------------------------------------------------------------------------
| Id   | Operation                          | Name                     | Rows  | Bytes   | Cost  | Time     |
-------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                   |                          |     1 |      93 | 10470 | 00:02:06 |
|    1 |   TEMP TABLE TRANSFORMATION        |                          |       |         |       |          |
|    2 |    LOAD AS SELECT                  | SYS_TEMP_0FD9FCC17_D4EAF |       |         |       |          |
|    3 |     HASH GROUP BY                  |                          | 46035 | 1611225 |  9845 | 00:01:59 |
|  * 4 |      TABLE ACCESS FULL             | T_ACCEPTED_CUSTOMER_INFO | 46035 | 1611225 |  9412 | 00:01:53 |
|    5 |    SORT ORDER BY                   |                          |     1 |      93 |   626 | 00:00:08 |
|    6 |     NESTED LOOPS                   |                          |       |         |       |          |
|    7 |      NESTED LOOPS                  |                          |     1 |      93 |   563 | 00:00:07 |
|  * 8 |       HASH JOIN ANTI               |                          |     1 |      79 |   560 | 00:00:07 |
|  * 9 |        TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO |     2 |     118 |    10 | 00:00:01 |
| * 10 |         INDEX RANGE SCAN           | IDX_ACCOPENUPDATE        |    46 |         |     3 | 00:00:01 |
|   11 |        TABLE ACCESS FULL           | T_B_OPENACCOUNTPUSH      | 74072 | 1481440 |   549 | 00:00:07 |
| * 12 |       INDEX RANGE SCAN             | IDX_SCHEDULE_USERID      |     1 |         |     2 | 00:00:01 |
| * 13 |        FILTER                      |                          |       |         |       |          |
|   14 |         VIEW                       |                          | 46035 |         |    62 | 00:00:01 |
|   15 |          TABLE ACCESS FULL         | SYS_TEMP_0FD9FCC17_D4EAF | 46035 |  598455 |    62 | 00:00:01 |
|   16 |      TABLE ACCESS BY INDEX ROWID   | T_ACCEPTED_SCHEDULE      |     1 |      14 |     3 | 00:00:01 |
-------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 4 - filter("SOURCE" IS NULL)
* 8 - access("O"."MOBILE"="I"."MOBILENO" AND "O"."CUST_NAME"="I"."CUSTNAME")
* 9 - filter(TO_NUMBER(NVL("I"."IS_SHORTCUT_SIGN",'0'))<>2)
* 10 - access("I"."ACCOPENUPDATE">='2017-07-25 10:44:35' AND "I"."ACCOPENUPDATE"<='2017-08-25 10:44:35')
* 12 - access("S"."USER_ID"=TO_CHAR("I"."USERID"))
* 12 - filter( EXISTS (SELECT 0 FROM (SELECT /*+ CACHE_TEMP_TABLE ("T1") */ "C0" "USERID" FROM "SYS"."SYS_TEMP_0FD9FCC17_D4EAF" "T1") "XXX" WHERE TO_NUMBER(:B1)=:B2))
* 13 - filter(TO_NUMBER(:B1)=:B2)


SQL还变慢了，看了下执行计划, id=12作为NL被驱动表， 每次都是全表扫描，这个肯定是可以优化的。。。
t_accepted_customer_info表的userid列上是有索引的， 且基本唯一,如此， 可让in里面的子查询作为NL被驱动表并走索引。。                     
后来发现in子查询里面 userid怎么都传不进去。。。没办法 只能改exists写法了


select i.mobileno,
       i.custname,
       i.user_code,
       i.userid,
       i.cuacct_code,
       s.open_step,
       s.current_step,
       i.accopenupdate as update_time
  from t_accepted_customer_info i
 inner join t_accepted_schedule s
    on to_char(i.userid) = s.user_id
 where nvl(is_shortcut_sign, 0) != 2
   and (i.accopenupdate between '2017-07-25 10:44:35' and
        '2017-08-25 10:44:35')
   and not exists
 (select o.id
          from t_b_openaccountpush o
         where o.mobile = i.mobileno
           and o.cust_name = i.custname)
   and exists (select max(userid) userid
                      from t_accepted_customer_info
                     where source is null
                     and userid = i.userid
                     group by custname, mobileno)
 order by i.accopenupdate asc;


Plan Hash Value  : 151850670 

--------------------------------------------------------------------------------------------------------------
| Id   | Operation                          | Name                       | Rows  | Bytes   | Cost | Time     |
--------------------------------------------------------------------------------------------------------------
|    0 | SELECT STATEMENT                   |                            |     1 |      93 |  569 | 00:00:07 |
|    1 |   SORT ORDER BY                    |                            |     1 |      93 |  569 | 00:00:07 |
|  * 2 |    FILTER                          |                            |       |         |      |          |
|    3 |     NESTED LOOPS                   |                            |       |         |      |          |
|    4 |      NESTED LOOPS                  |                            |     1 |      93 |  563 | 00:00:07 |
|  * 5 |       HASH JOIN ANTI               |                            |     1 |      79 |  560 | 00:00:07 |
|  * 6 |        TABLE ACCESS BY INDEX ROWID | T_ACCEPTED_CUSTOMER_INFO   |     2 |     118 |   10 | 00:00:01 |
|  * 7 |         INDEX RANGE SCAN           | IDX_ACCOPENUPDATE          |    46 |         |    3 | 00:00:01 |
|    8 |        TABLE ACCESS FULL           | T_B_OPENACCOUNTPUSH        | 74072 | 1481440 |  549 | 00:00:07 |
|  * 9 |       INDEX RANGE SCAN             | IDX_SCHEDULE_USERID        |     1 |         |    2 | 00:00:01 |
|   10 |      TABLE ACCESS BY INDEX ROWID   | T_ACCEPTED_SCHEDULE        |     1 |      14 |    3 | 00:00:01 |
|   11 |     HASH GROUP BY                  |                            |     1 |      35 |    5 | 00:00:01 |
| * 12 |      TABLE ACCESS BY INDEX ROWID   | T_ACCEPTED_CUSTOMER_INFO   |     1 |      35 |    4 | 00:00:01 |
| * 13 |       INDEX RANGE SCAN             | CUSTOMER_INF_INDEX_OUSERID |     1 |         |    3 | 00:00:01 |
--------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 2 - filter( EXISTS (SELECT 0 FROM "SISDATA"."T_ACCEPTED_CUSTOMER_INFO" "T_ACCEPTED_CUSTOMER_INFO" WHERE "USERID"=:B1 AND "SOURCE" IS NULL GROUP BY "CUSTNAME","MOBILENO"))
* 5 - access("O"."MOBILE"="I"."MOBILENO" AND "O"."CUST_NAME"="I"."CUSTNAME")
* 6 - filter(TO_NUMBER(NVL("I"."IS_SHORTCUT_SIGN",'0'))<>2)
* 7 - access("I"."ACCOPENUPDATE">='2017-07-25 10:44:35' AND "I"."ACCOPENUPDATE"<='2017-08-25 10:44:35')
* 9 - access("S"."USER_ID"=TO_CHAR("I"."USERID"))
* 12 - filter("SOURCE" IS NULL)
* 13 - access("USERID"=:B1)


现在SQL就秒杀了,USERID值也传进去了。。。

