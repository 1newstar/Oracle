-- 创建记录日志的存储过程
create or replace procedure pro_procedure_step_log(p_taskid        varchar2,
                                                   p_packagename   varchar2,
                                                   p_procedurename varchar2,
                                                   p_step          int,
                                                   p_comment       varchar2) as
  -- 开启自治事务
  pragma autonomous_transaction;

  v_comment clob default to_clob(p_comment);

begin
  insert into t_procedure_step_log
    (taskid, packagename, procedurename, step, comments, finishtime)
  values
    (p_taskid, lower(p_packagename), lower(p_procedurename), p_step, v_comment, sysdate);
  commit;
exception
  when others then
    null;
end;
/



------------------------------------------------------------------------------
----------------在具体的存储过程中， 记录日志时，可以这样操作-----------------
------------------------------------------------------------------------------

declare

  -- 记录存储过程日志变量
  v_taskid  varchar2(50) := sys_guid();
  v_pkgname varchar2(50) := '';
  v_proname varchar2(50) := 'PRO_ACCOUNTSTRATEGYPOS_ADV_V2';
  v_step    pls_integer default 1;  
  -- 异常时的记录信息
  v_code    NUMBER;
  v_errm    VARCHAR2(64);

  -- 返回当前step， 并自增step
  function f_inc_step return pls_integer is
  
    v_tmp pls_integer := v_step;
  begin
    v_step := v_step + 1;
    return v_tmp;
  end;  

begin

  pro_procedure_step_log(p_taskid        => v_taskid,
                         p_packagename   => v_pkgname,
                         p_procedurename => v_proname,
                         p_step          => f_inc_step,
                         p_comment       => '开始执行');


  -- .....
  -- other operate
  -- .....                       

  pro_procedure_step_log(p_taskid        => v_taskid,
                           p_packagename   => v_pkgname,
                           p_procedurename => v_proname,
                           p_step          => f_inc_step,
                           p_comment       => '最后一步: merge into robot_advise_strategy ... 更新行数：' || sql%rowcount);   


exception
  when others then 
    v_code := SQLCODE;
    v_errm := SUBSTR(SQLERRM, 1, 64);
    pro_procedure_step_log(p_taskid        => v_taskid,
                         p_packagename   => v_pkgname,
                         p_procedurename => v_proname,
                         p_step          => f_inc_step,
                         p_comment       => '异常-----> sqlcode:' || v_code || '  , sqlerrm:' || v_errm);   

    raise;


end;
/






------------------------------------------------------------------------------
---------------------------------查询存储过程执行日志信息---------------------
------------------------------------------------------------------------------

-- 查询某个存储过程最近一次执行的日志 第一种写法
with v_taskids as
 (select /*+ materialize */
   v.taskid
    from (select t.taskid, row_number() over(order by t.finishtime desc) rn
            from t_procedure_step_log t
           where t.procedurename = lower('pro_accountstrategy_cfm_v2') -- 指定存储过程名
          ) v
   where rn = 1)
select concat(decode(nvl(packagename, '.'), '.', '', packagename || '.'),
              procedurename) procedurename,
       step,
       to_char(comments) comments,
       finishtime,
       (finishtime - prev_finishtime) * 24 * 60 * 60 "该步骤执行耗时(秒)",
       (lasttime - starttime) * 24 * 60 * 60 "该task执行耗时(秒)"
  from (select t.*,
               lag(t.finishtime) over(partition by t.taskid order by t.step) prev_finishtime,
               min(t.finishtime) over(partition by t.taskid) starttime,
               max(t.finishtime) over(partition by t.taskid) lasttime
          from t_procedure_step_log t) v
 where taskid in (select taskid from v_taskids);


-- 查询某个存储过程最近一次执行的日志 第二种写法
with v_taskids as
 (select taskid
    from (select *
            from t_procedure_step_log t
           where t.procedurename = lower('test')
           order by t.finishtime desc)
   where rownum <= 1)
select taskid,
       concat(decode(nvl(packagename, '.'), '.', '', packagename || '.'),
              procedurename) procedurename,
       step,
       to_char(comments) comments,
       finishtime,
       (finishtime - prev_finishtime) * 24 * 60 * 60 "该步骤执行耗时(秒)",
       (lasttime - starttime) * 24 * 60 * 60 "该task执行耗时(秒)"
  from (select t.*,
               lag(t.finishtime) over(partition by t.taskid order by t.step) prev_finishtime,
               min(t.finishtime) over(partition by t.taskid) starttime,
               max(t.finishtime) over(partition by t.taskid) lasttime
          from t_procedure_step_log t) v
 where taskid in (select taskid from v_taskids);





-- 验证总时长SQL
select ((select max(finishtime)
           from t_procedure_step_log
          where taskid = '00180823AF9C44308F219E205918A10C') -
       (select min(finishtime)
           from t_procedure_step_log
          where taskid = '00180823AF9C44308F219E205918A10C')) * 24 * 60 * 60
  from dual; 



-- 对于一天执行一次的job
-- task可能执行时长会跨天 例如23号晚上开始执行 24号凌晨才执行完
-- 查询某个存储过程所有的执行的日志， 按照task开启日期、taskid、step排序
select taskid,
       trunc(starttime) taskdate,
       concat(decode(nvl(packagename, '.'), '.', '', packagename || '.'),
              procedurename) procedurename,
       step,
       to_char(comments) comments,
       finishtime,
       (finishtime - prev_finishtime) * 24 * 60 * 60 "该步骤执行耗时(秒)",
       (lasttime - starttime) * 24 * 60 * 60 "该task执行耗时(秒)"
  from (select t.*,
               lag(t.finishtime) over(partition by t.taskid order by t.step) prev_finishtime,
               min(t.finishtime) over(partition by t.taskid) starttime,
               max(t.finishtime) over(partition by t.taskid) lasttime
          from t_procedure_step_log t
         where t.procedurename = lower('test'))
 order by taskdate, procedurename, step;  