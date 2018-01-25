-- 下面的这个是根据 TMP_STRATEGY_CFM_SELL 这个临时表的数据， 去关联更新 robot_advise_strategy 表的数据
-- 且这个SQL放在 存储过程的 for 循环中， 会被执行多次。。。
update robot_advise_strategy b
set (upd_date,ADVISE_CAN_EXECUTE,CANNOT_EXECUTE_REASON,IS_CUST_FOLLOW,REAL_TRADE_QTY,REAL_TRADE_PRICE,
     REAL_TRADE_STOCKVALUE,REAL_TRADE_REMAIND_QTY)
   =(select sysdate,a.F1007,a.F1008,a.F1009,a.F1010,a.F1011,a.F1012,F1013
     from TMP_STRATEGY_CFM_SELL a
     where b.CLOSE_DEAL_DAY=a.pub_dt and b.ADVISE_DAY=a.F1001 and b.CUST_CODE=a.account_id and b.stock_code=a.stock_code
     )
where exists(select 1
             from TMP_STRATEGY_CFM_SELL a
             where b.CLOSE_DEAL_DAY=a.pub_dt and b.ADVISE_DAY=a.F1001 and b.CUST_CODE=a.account_id and b.stock_code=a.stock_code)
  --and b.STRATEGY_TYPE=2    --策略标识 1 换股，2 波段
  and b.ADVISE_TYPE=0;


-- 下面是对这种SQL进行的等价改写
  /*
  update ROBOT_ADVISE_STRATEGY b
  set (upd_date,next_id)
     =(select sysdate,id
       from ROBOT_ADVISE_STRATEGY a
       where a.STRATEGY_TYPE=p_strategy_type and a.advise_type=1 and a.close_deal_day=var_pub_dt_num and a.is_wave_finish=0 and a.last_id=b.id
       )
  where exists(select 1
               from ROBOT_ADVISE_STRATEGY a
               where a.STRATEGY_TYPE=p_strategy_type and a.advise_type=1 and a.close_deal_day=var_pub_dt_num and a.is_wave_finish=0 and a.last_id=b.id)
                and b.STRATEGY_TYPE=p_strategy_type    --策略标识 1 换股，2 纯波段
                and b.ADVISE_TYPE=0;
  */

  -- @Author DANMAOWU500
  -- @Date 2017-01-12
  -- @Desc 对上面的SQL进行了等价改写
  merge into robot_advise_strategy b
  using (select id, last_id
           from robot_advise_strategy a
          where a.strategy_type = to_char(p_strategy_type)
            and a.advise_type = '1'
            and a.close_deal_day = to_char(var_pub_dt_num) 
            and a.is_wave_finish = '0'
         ) a
  on (a.last_id = b.id and b.strategy_type = to_char(p_strategy_type) and b.advise_type = '0')
  when matched then   
    update set b.upd_date = sysdate, b.next_id = a.id;

  pro_procedure_step_log(p_taskid        => v_taskid,
                         p_packagename   => v_pkgname,
                         p_procedurename => v_proname,
                         p_step          => f_inc_step,
                         p_comment       => '最后一步：update ROBOT_ADVISE_STRATEGY ... 更新行数：' || sql%rowcount);   

  commit;



当时同时跟我说这个存储过程跑了差不多30个小时， 还一直卡着在， 日志也都没记， 不知道什么原因卡着。
每次跑的慢了就减少循环处理的记录数， 越搞越慢， 哈哈。。。

我看了下他们的存储过程就知道这种SQL语句肯定出问题了。。。
实际上 update 进行关联更新的 如果关联的表走索引， 也不会导致说跑30多个小时， 
但是他们这里关联更新的表时临时表， 是走不了索引的， 这样就会导致有多少条记录(N)要被更新， 那个临时表
就要被全表扫描 N*2 次， 不死才怪， 对SQL进行等价改写成merge之后， 用时不到40分钟就跑完了。。。
其实还可以更进一步优化的， 但是他们领导不愿意修改这个存储过程太多的内容。。。