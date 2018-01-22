-- 造测试数据
declare
  type tbl_log_type is table of t_procedure_step_log%rowtype index by pls_integer;
  tbl_log tbl_log_type;

  v_step_cnt pls_integer;

  x pls_integer default 1;
begin
  for i in (select sys_guid() taskid from dual connect by level <= 100) loop
    v_step_cnt := trunc(dbms_random.value(5, 20));
    -- dbms_output.put_line(v_step_cnt);
  
    select i.taskid, 'pkg_util', 'proc' || x, rownum, null, cdate
      bulk collect
      into tbl_log
      from (select sysdate + (1 / 24 / level) cdate
              from dual
            connect by level <= v_step_cnt
             order by 1);
  
    forall j in 1 .. tbl_log.count
      insert into t_procedure_step_log
        (taskid, packagename, procedurename, step, comments, finishtime)
      values
        (tbl_log(j).taskid,
         tbl_log(j).packagename,
         tbl_log(j).procedurename,
         tbl_log(j).step,
         tbl_log(j).comments,
         tbl_log(j).finishtime);
    x := x + 1;
  end loop;
  commit;
end;

