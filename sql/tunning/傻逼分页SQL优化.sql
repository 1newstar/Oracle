-- 监控平台TOPSQL中有这样一条SQL  
-- 平均每次执行耗时 237.026s
-- 最长一次执行耗时 1422.16s
select custinfo.userid      as userid,
       custinfo.custname    as custname,
       custinfo.usersex     as usersex,
       custinfo.idtype      as idtype,
       custinfo.idno        as idno,
       custinfo.mobileno    as mobileno,
       custinfo.user_code   as usercode,
       custinfo.mobilestate as mobilestate,
       custinfo.openstate   as openstate,
       custinfo.cuacct_code as cuacct_code,
       custinfo.branchno    as branchno
  from t_accepted_customer_info custinfo, t_b_mobile_pem pem
 where custinfo.userid = pem.userid
   and pem.is_thexjb = '1'
   and pem.openxjb_result = '0'
   and custinfo.user_code is not null
   and custinfo.cuacct_code is not null
   and (custinfo.shaaccount is not null or custinfo.szaaccount is not null)
   and rownum < :1



---------抓到的两次的执行计划分别是

------------------------------------------------------------------------------------------------------------
| Id  | Operation                     | Name                       | Rows  | Bytes | Cost (%CPU)| Time     |
------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                            |       |       |    22 (100)|          |
|   1 |  COUNT STOPKEY                |                            |       |       |            |          |
|   2 |   NESTED LOOPS                |                            |       |       |            |          |
|   3 |    NESTED LOOPS               |                            |     4 |   448 |    22   (0)| 00:00:01 |
|   4 |     TABLE ACCESS FULL         | T_B_MOBILE_PEM             |   306K|  3593K|     2   (0)| 00:00:01 |
|   5 |     INDEX RANGE SCAN          | CUSTOMER_INF_INDEX_OUSERID |     1 |       |     2   (0)| 00:00:01 |
|   6 |    TABLE ACCESS BY INDEX ROWID| T_ACCEPTED_CUSTOMER_INFO   |     1 |   100 |     4   (0)| 00:00:01 |
------------------------------------------------------------------------------------------------------------




 
--------------------------------------------------------------------------------------------------------
| Id  | Operation           | Name                     | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     |
--------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT    |                          |       |       |       | 15776 (100)|          |
|   1 |  COUNT STOPKEY      |                          |       |       |       |            |          |
|   2 |   HASH JOIN         |                          |  1000 |   209K|    10M| 15776   (3)| 00:03:10 |
|   3 |    TABLE ACCESS FULL| T_B_MOBILE_PEM           |   421K|  5355K|       | 13618   (3)| 00:02:44 |
|   4 |    TABLE ACCESS FULL| T_ACCEPTED_CUSTOMER_INFO | 18960 |  1870K|       |  1546   (2)| 00:00:19 |
--------------------------------------------------------------------------------------------------------
 
Note
-----
   - cardinality feedback used for this statement





这是一个非常简单的分页语句， 他娘的既然没有order by 。。。。 
该SQL只查询了 custinfo 表的数据  ， 那么该SQL可以改写成半连接的方式进行优化。



在UAT环境看下该SQL详细的执行计划信息



 Plan Hash Value  : 1992991820 

--------------------------------------------------------------------------------------------
| Id  | Operation             | Name                     | Rows | Bytes  | Cost | Time     |
--------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT      |                          |   18 |   1602 | 9581 | 00:01:55 |
| * 1 |   COUNT STOPKEY       |                          |      |        |      |          |
| * 2 |    HASH JOIN          |                          |   18 |   1602 | 9581 | 00:01:55 |
| * 3 |     TABLE ACCESS FULL | T_ACCEPTED_CUSTOMER_INFO |   18 |   1368 | 9406 | 00:01:53 |
| * 4 |     TABLE ACCESS FULL | T_B_MOBILE_PEM           | 9425 | 122525 |  174 | 00:00:03 |
--------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
------------------------------------------
* 1 - filter(ROWNUM<100)
* 2 - access("CUSTINFO"."USERID"=TO_NUMBER("PEM"."USERID"))
* 3 - filter("CUSTINFO"."CUACCT_CODE" IS NOT NULL AND "CUSTINFO"."USER_CODE" IS NOT NULL AND ("CUSTINFO"."SZAACCOUNT" IS NOT NULL OR "CUSTINFO"."SHAACCOUNT" IS NOT NULL))
* 4 - filter("PEM"."OPENXJB_RESULT"='0' AND "PEM"."IS_THEXJB"='1')


谓词信息里面又是连接列进行了隐式类型转换， TP系统就喜欢搞这事.
这里慢的原因是因为走HASH 肯定是不能快速出结果， 而且使用 T_ACCEPTED_CUSTOMER_INFO 表做驱动表， 
T_ACCEPTED_CUSTOMER_INFO 是大宽表， 200多个字段， 大几百万的数据量

既然没有order by ， 那么这个SQL 只需要走NL 就好了。。。且让 T_B_MOBILE_PEM 做为驱动表

这里我先使用HINT，强制走NL ， 结果表明我是对的， SQL直接秒杀了。
select /*+ use_nl(pem custinfo) leading(pem) */
 custinfo.userid      as userid,
 custinfo.custname    as custname,
 custinfo.usersex     as usersex,
 custinfo.idtype      as idtype,
 custinfo.idno        as idno,
 custinfo.mobileno    as mobileno,
 custinfo.user_code   as usercode,
 custinfo.mobilestate as mobilestate,
 custinfo.openstate   as openstate,
 custinfo.cuacct_code as cuacct_code,
 custinfo.branchno    as branchno
  from t_accepted_customer_info custinfo, t_b_mobile_pem pem
 where custinfo.userid = to_number(pem.userid)
   and pem.is_thexjb = '1'
   and pem.openxjb_result = '0'
   and custinfo.user_code is not null
   and custinfo.cuacct_code is not null
   and (custinfo.shaaccount is not null or custinfo.szaaccount is not null)
   and rownum < 100


如果需要修改成半连接



select /*+ use_nl(pem@sb custinfo) leading(pem@sb) */
 custinfo.userid      as userid,
 custinfo.custname    as custname,
 custinfo.usersex     as usersex,
 custinfo.idtype      as idtype,
 custinfo.idno        as idno,
 custinfo.mobileno    as mobileno,
 custinfo.user_code   as usercode,
 custinfo.mobilestate as mobilestate,
 custinfo.openstate   as openstate,
 custinfo.cuacct_code as cuacct_code,
 custinfo.branchno    as branchno
  from t_accepted_customer_info custinfo
 where custinfo.user_code is not null
   and custinfo.cuacct_code is not null
   and (custinfo.shaaccount is not null or custinfo.szaaccount is not null)
   and custinfo.userid in
       (select /*+ qb_name(sb) */
         to_number(pem.userid)
          from t_b_mobile_pem pem
         where pem.is_thexjb = '1'
           and pem.openxjb_result = '0')
   and rownum < 100
