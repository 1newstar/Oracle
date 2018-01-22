select distinct a.cust_code 客户号,
                a.dft_acc 资金号,
                a.secu_acc_name 客户姓名,
                a.open_date 开户日期,
                a.open_brh 开户机构,
                decode(b.open_source,
                        '0',
                        '柜台开户',
                        '1',
                        '客户自助',
                        '2',
                        '视频见证',
                        '3',
                        '双人见证',
                        '7',
                        '客户自助_一帐通',
                        '8',
                        '客户自助_保单开户',
                        '9',
                        '客户自助_大智慧',
                        'a',
                        '客户自助_雪球',
                        'b',
                        '客户自助_腾讯自选股',
                        'c',
                        '客户自助_京东金融',
                        'd',
                        '客户自助_全户通',
                        'e',
                        '客户自助_牛骨网',
                        'f',
                        '客户自助_交易宝',
                        'g',
                        '客户自助_金科金证开户',
                        'h',
                        '客户自助_挖财',
                        'i',
                        '客户自助_华尔街见闻') 开户来源
  from kgdb.secu_acc a, kbssuser.user_basic_info b
 where a.status = '0'
   and a.main_flag = '1'
   and a.cust_code = b.user_code
   and a.dft_acc not in (select account
                           from kgdb.brh_fees
                         union
                         select account
                           from kgdb.crm_acc_fee
                         union
                         select account
                           from kgdb.acc_cls_fee
                         union
                         select account
                           from kgdb.COM_PROD_TO_CUSTod_to_cust) --select * from kbssuser.user_basic_info





 
-----------------------------------------------------------------------------------------------------------------------
| Id  | Operation                  | Name             | Rows  | Bytes |TempSpc| Cost (%CPU)| Time     | Inst   |IN-OUT|
-----------------------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT           |                  |       |       |       |   274K(100)|          |        |      |
|   1 |  HASH UNIQUE               |                  |  1020K|    63M|    74M|   274K  (2)| 00:54:53 |        |      |
|   2 |   HASH JOIN                |                  |  1020K|    63M|    59M|   258K  (2)| 00:51:42 |        |      |
|   3 |    HASH JOIN ANTI          |                  |  1020K|    47M|    46M|   167K  (2)| 00:33:36 |        |      |
|   4 |     TABLE ACCESS FULL      | SECU_ACC         |  1020K|    35M|       | 82817   (2)| 00:16:34 |        |      |
|   5 |     VIEW                   | VW_NSO_1         |    14M|   178M|       | 65589   (2)| 00:13:08 |        |      |
|   6 |      SORT UNIQUE           |                  |    14M|   110M|   221M| 65589   (2)| 00:13:08 |        |      |
|   7 |       UNION-ALL            |                  |       |       |       |            |          |        |      |
|   8 |        INDEX FAST FULL SCAN| T329_1           |   160K|  1251K|       |   233   (1)| 00:00:03 |        |      |
|   9 |        TABLE ACCESS FULL   | CRM_ACC_FEE      |  7074K|    53M|       |  6341   (2)| 00:01:17 |        |      |
|  10 |        INDEX FAST FULL SCAN| T32CUQ1          |  7124K|    54M|       |  6066   (2)| 00:01:13 |        |      |
|  11 |        TABLE ACCESS FULL   | COM_PROD_TO_CUST | 77890 |   608K|       |   106   (1)| 00:00:02 |        |      |
|  12 |    REMOTE                  | USER_BASIC_INFO  |    12M|   195M|       | 70380   (2)| 00:14:05 | CAMSL~ | R->S |
-----------------------------------------------------------------------------------------------------------------------
 
Remote SQL Information (identified by operation id):
----------------------------------------------------
 
  12 - SELECT "USER_CODE","OPEN_SOURCE" FROM "KBSSUSER"."USER_BASIC_INFO" "B" (accessing 'CAMSLINK' )



-- 由于不能操作他们的数据库
-- 只能记录下思路了

-- kbssuser.user_basic_info.open_source 列建立索引， 走INDEX FAST FULL SCAN ，

-- 如果整个SQL返回数据不是很多的话， 可以把 kbssuser.user_basic_info 发送到 kgdb 那边进行关联， 关联玩后再把数据传回