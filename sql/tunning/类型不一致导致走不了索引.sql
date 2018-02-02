同事给我发邮件说有条SQL跑的非常慢， TP系统的， 非常影响用户体验。

接口：
/ips-portfolio/sis_ips_portfolio.cacheIpsPcProductInfo.do

慢SQL: （我执行了一下，一分多钟还没出来，我取消了）
with tt as 
( select a.create_date, a.account_id, a.total_assets from t_sim_hist_account a , (select max(ta.create_date) create_date, ta.account_id from t_sim_hist_account ta where ta.ACCOUNT_ID in ( 2155, 2108, 2140, 2140, 2140, 2244, 2108, 2183, 2128, 2264, 2124, 6753, 2147, 2133, 2036, 2426, 3160, 2299198, 1098378, 2299902, 93237, 93236, 3000054, 3000047, 2299903, 3000065, 2108, 3000059, 3000059, 3000058) and ta.create_date <= 20180102 and ta.TOTAL_ASSETS > 0 group by ta.account_id) b where a.account_id=b.account_id and a.create_date=b.create_date ), tk as ( select a.create_date, a.account_id, a.total_assets from t_sim_hist_account a , (select max(ta.create_date) create_date, ta.account_id from t_sim_hist_account ta where ta.ACCOUNT_ID in (2155, 2108, 2140, 2140, 2140, 2244, 2108, 2183, 2128, 2264, 2124, 6753, 2147, 2133, 2036, 2426, 3160, 2299198, 1098378, 2299902, 93237, 93236, 3000054, 3000047, 2299903, 3000065, 2108, 3000059, 3000059, 3000058) and ta.TOTAL_ASSETS > 0 group by ta.account_id) b where a.account_id=b.account_id and a.create_date=b.create_date ) select tk.create_date,tk.account_id accountId,to_char((tk.total_assets-tt.total_assets)/tt.total_assets * 100,'FM999999990.09') yield from tt,tk where tt.account_id=tk.account_id

这个SQL是在mybatis中拼的SQL
看一下怎么优化一下，是这个sql： src\main\resources\config\biz\sqlmap-mapping-yield.xml 


<select id="queryProductYieldList" parameterClass="java.util.Map" resultClass="com.pingan.sis.ips.product.dto.ProductYieldDTO">
     with tt as  (
       select a.create_date, a.account_id, a.total_assets 
         from t_sim_hist_account a ,
              (select max(ta.create_date) create_date, ta.account_id
                 from t_sim_hist_account ta
                where ta.ACCOUNT_ID in 
            <iterate property="productList" open="(" conjunction="," close=")">  
                   #productList[].accountId#    这里的accountId的int类型的。但是数据库定义的是varchar2类型的。且这里的绑定变量的方式感觉又问题
                </iterate>   
              <![CDATA[    
                  and ta.create_date  <=  #startDay#
                  and ta.TOTAL_ASSETS > 0 ]]>
                group by ta.account_id) b
          where a.account_id=b.account_id
             and a.create_date=b.create_date
       ),  
         tk as  (
       select a.create_date, a.account_id, a.total_assets 
         from t_sim_hist_account a ,
              (select max(ta.create_date) create_date, ta.account_id
                 from t_sim_hist_account ta
                where ta.ACCOUNT_ID in 
              <iterate property="productList" open="(" conjunction="," close=")">  
                   #productList[].accountId#   这里的accountId的int类型的。但是数据库定义的是varchar2类型的。
                </iterate> 
                <![CDATA[ 
                  and ta.TOTAL_ASSETS > 0]]>
                group by ta.account_id) b
          where a.account_id=b.account_id
             and a.create_date=b.create_date
       ) 
       select tk.create_date,tk.account_id accountId,to_char((tk.total_assets-tt.total_assets)/tt.total_assets * 100,'FM999999990.09') yield from tt,tk
       where tt.account_id=tk.account_id
</select>



with tt as
 (select a.create_date, a.account_id, a.total_assets
    from t_sim_hist_account a,
         (select max(ta.create_date) create_date, ta.account_id
            from t_sim_hist_account ta
           where ta.account_id in (2155,
                                   2108,
                                   2140,
                                   2140,
                                   2140,
                                   2244,
                                   2108,
                                   2183,
                                   2128,
                                   2264,
                                   2124,
                                   6753,
                                   2147,
                                   2133,
                                   2036,
                                   2426,
                                   3160,
                                   2299198,
                                   1098378,
                                   2299902,
                                   93237,
                                   93236,
                                   3000054,
                                   3000047,
                                   2299903,
                                   3000065,
                                   2108,
                                   3000059,
                                   3000059,
                                   3000058)
             and ta.create_date <= 20180102
             and ta.total_assets > 0
           group by ta.account_id) b
   where a.account_id = b.account_id
     and a.create_date = b.create_date),
tk as
 (select a.create_date, a.account_id, a.total_assets
    from t_sim_hist_account a,
         (select max(ta.create_date) create_date, ta.account_id
            from t_sim_hist_account ta
           where ta.account_id in (2155,
                                   2108,
                                   2140,
                                   2140,
                                   2140,
                                   2244,
                                   2108,
                                   2183,
                                   2128,
                                   2264,
                                   2124,
                                   6753,
                                   2147,
                                   2133,
                                   2036,
                                   2426,
                                   3160,
                                   2299198,
                                   1098378,
                                   2299902,
                                   93237,
                                   93236,
                                   3000054,
                                   3000047,
                                   2299903,
                                   3000065,
                                   2108,
                                   3000059,
                                   3000059,
                                   3000058)
             and ta.total_assets > 0
           group by ta.account_id) b
   where a.account_id = b.account_id
     and a.create_date = b.create_date)
select tk.create_date,
       tk.account_id accountid,
       to_char((tk.total_assets - tt.total_assets) / tt.total_assets * 100,
               'FM999999990.09') yield
  from tt, tk
 where tt.account_id = tk.account_id




Plan hash value: 3961474028

---------------------------------------------------------------------------------------------------------
| Id  | Operation                       | Name                  | Rows  | Bytes | Cost (%CPU)| Time     |
---------------------------------------------------------------------------------------------------------
|   0 | SELECT STATEMENT                |                       |     1 |    87 |   149K  (9)| 00:29:58 |
|   1 |  NESTED LOOPS                   |                       |     1 |    87 |   149K  (9)| 00:29:58 |
|   2 |   NESTED LOOPS                  |                       |   109 |  8393 |   149K  (9)| 00:29:51 |
|   3 |    NESTED LOOPS                 |                       |     1 |    57 |   148K  (9)| 00:29:46 |
|   4 |     VIEW                        |                       |     1 |    37 |   148K  (9)| 00:29:46 |
|   5 |      HASH GROUP BY              |                       |     1 |    20 |   148K  (9)| 00:29:46 |
|*  6 |       TABLE ACCESS FULL         | T_SIM_HIST_ACCOUNT    |  9098 |   177K|   148K  (9)| 00:29:46 |
|   7 |     TABLE ACCESS BY INDEX ROWID | T_SIM_HIST_ACCOUNT    |     1 |    20 |     5   (0)| 00:00:01 |
|*  8 |      INDEX RANGE SCAN           | IDX_SIMHISTCREATEDATE |     1 |       |     3   (0)| 00:00:01 |
|   9 |    TABLE ACCESS BY INDEX ROWID  | T_SIM_HIST_ACCOUNT    |   364 |  7280 |   375   (0)| 00:00:05 |
|* 10 |     INDEX RANGE SCAN            | IDX_SIMHISTCREATEDATE |   364 |       |     4   (0)| 00:00:01 |
|* 11 |   VIEW PUSHED PREDICATE         |                       |     1 |    10 |     5   (0)| 00:00:01 |
|* 12 |    FILTER                       |                       |       |       |            |          |
|  13 |     SORT AGGREGATE              |                       |     1 |    20 |            |          |
|* 14 |      TABLE ACCESS BY INDEX ROWID| T_SIM_HIST_ACCOUNT    |     1 |    20 |     5   (0)| 00:00:01 |
|* 15 |       INDEX RANGE SCAN          | IDX_SIMHISTACCOUNTID  |     1 |       |     4   (0)| 00:00:01 |
---------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------

   6 - filter((TO_NUMBER("TA"."ACCOUNT_ID")=2155 OR TO_NUMBER("TA"."ACCOUNT_ID")=2108 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2140 OR TO_NUMBER("TA"."ACCOUNT_ID")=2244 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2183 OR TO_NUMBER("TA"."ACCOUNT_ID")=2128 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2264 OR TO_NUMBER("TA"."ACCOUNT_ID")=2124 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=6753 OR TO_NUMBER("TA"."ACCOUNT_ID")=2147 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2133 OR TO_NUMBER("TA"."ACCOUNT_ID")=2036 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2426 OR TO_NUMBER("TA"."ACCOUNT_ID")=3160 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2299198 OR TO_NUMBER("TA"."ACCOUNT_ID")=1098378 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2299902 OR TO_NUMBER("TA"."ACCOUNT_ID")=93237 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=93236 OR TO_NUMBER("TA"."ACCOUNT_ID")=3000054 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=3000047 OR TO_NUMBER("TA"."ACCOUNT_ID")=2299903 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=3000065 OR TO_NUMBER("TA"."ACCOUNT_ID")=3000059 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=3000058) AND "TA"."TOTAL_ASSETS">0)
   8 - access("A"."ACCOUNT_ID"="B"."ACCOUNT_ID" AND "A"."CREATE_DATE"="B"."CREATE_DATE")
  10 - access("A"."ACCOUNT_ID"="A"."ACCOUNT_ID")
  11 - filter("A"."CREATE_DATE"="B"."CREATE_DATE")
  12 - filter(COUNT(*)>0)
  14 - filter(TO_NUMBER("TA"."CREATE_DATE")<=20180102 AND "TA"."TOTAL_ASSETS">0)
  15 - access("TA"."ACCOUNT_ID"="A"."ACCOUNT_ID")
       filter(TO_NUMBER("TA"."ACCOUNT_ID")=2155 OR TO_NUMBER("TA"."ACCOUNT_ID")=2108 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2140 OR TO_NUMBER("TA"."ACCOUNT_ID")=2244 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2183 OR TO_NUMBER("TA"."ACCOUNT_ID")=2128 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2264 OR TO_NUMBER("TA"."ACCOUNT_ID")=2124 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=6753 OR TO_NUMBER("TA"."ACCOUNT_ID")=2147 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2133 OR TO_NUMBER("TA"."ACCOUNT_ID")=2036 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2426 OR TO_NUMBER("TA"."ACCOUNT_ID")=3160 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2299198 OR TO_NUMBER("TA"."ACCOUNT_ID")=1098378 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=2299902 OR TO_NUMBER("TA"."ACCOUNT_ID")=93237 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=93236 OR TO_NUMBER("TA"."ACCOUNT_ID")=3000054 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=3000047 OR TO_NUMBER("TA"."ACCOUNT_ID")=2299903 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=3000065 OR TO_NUMBER("TA"."ACCOUNT_ID")=3000059 OR 
              TO_NUMBER("TA"."ACCOUNT_ID")=3000058)



我一看这个执行计划， 马上去检查 t_sim_hist_account.ACCOUNT_ID 列是否有索引，一看还真有， 且 ACCOUNT_ID 列的类型为varchar2,
让他们改成字符串在运行SQL就秒杀了



最终的还是要修改mybatis的绑定变量的方式， 修改成官网推荐的这种方式就没有初吻提了。

<select id="selectPostIn" resultType="domain.blog.Post">
  SELECT *
  FROM POST P
  WHERE ID in
  <foreach item="item" index="index" collection="list"
      open="(" separator="," close=")">
        #{item}
  </foreach>
</select>