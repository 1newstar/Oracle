-- 先看看每个员工这个月的出勤情况
select id, count(*) cnt from t_worktime group by id order by cnt;

-- 第一题的答案
-- 这种实现方式有一点不好的， 当员工数量比较多的时候， 例如 富士康500W员工， 这里就会有性能问题，
-- 因为这里使用笛卡尔积枚举出每个员工出勤30天的数据
with v_staff_days as
 (select /* 枚举出每个员工30天的考勤 */
   s.id, daynumber, s.dept
    from (select level daynumber from dual connect by level <= 30) days
   cross join (select id, dept from t_staffer) s)
--select * from v_staff_days order by id, daynumber
select t1.id,
       t1.daynumber,
       t1.dept,
       t2.intime,
       t2.outtime,
       (case
         when t2.id is null then
          '缺勤'
         when t2.intime > '09:00' and t2.outtime < '18:00' then
          '迟到、早退'
         when t2.intime > '09:00' then
          '迟到'
         when t2.outtime < '18:00' then
          '早退'
       end) reason
  from v_staff_days t1
  left join t_worktime t2
    on (t1.id = t2.id and t1.daynumber = t2.daynumber)
 where ((t2.id is null) --缺勤
       or (t2.intime > '09:00') --迟到
       or (t2.outtime < '18:00') --早退
       )
   -- and t1.id = 7900 -- 可加上这个过滤条件看看缺勤天数是否对的上
 order by t1.id, t1.daynumber;




----------------------------------------用存储过程来实现的话， 效率会高很多----------------------------------------
with v_base as
 (select t.*,
         lead(daynumber, 1, daynumber) over(partition by t.id order by t.daynumber) next_daynumber,
         (case
           when t.intime > '09:00' and t.outtime < '18:00' then
            3
           when t.intime > '09:00' then
            1
           when t.outtime < '18:00' then
            2
           else
            0
         end) status
    from t_worktime t)
select a.*,
       (case
         when next_daynumber - daynumber > 1 then
          1
         else
          0
       end) lost_range_mark
  from v_base a;


详见 存储过程实现思路.png


-- 搞一个表来存储异常考勤的数据
create table t_incorrect_log(
  staffid int,  -- 员工id
  daynumber int, -- 考勤日期
  status int, -- 是否迟到、早退 状态
  time1 int, --迟到时间(单位：分钟）
  time2 int, --早退时间(单位：分钟）
  lost int -- 是否缺勤  1 是 0 否
);



create procedure proc_analysis_incorrect_kq as
  type tbl_type is table of t_incorrect_log%rowtype index by pls_integer;
  tbl tbl_type; -- 用来存放考勤异常记录

  i pls_integer; -- 计数的

  v_final_date_prefix varchar2(20) := to_char(sysdate, 'yyyyMMdd');
  v_final_intime      date := to_date(v_final_date_prefix || ' 09:00',
                                      'yyyyMMdd hh24:mi');
  v_final_outtime     date := to_date(v_final_date_prefix || ' 18:00',
                                      'yyyyMMdd hh24:mi');
begin
  for r in (with v_base as
               (select t.*,
                      lead(daynumber, 1, daynumber) over(partition by t.id order by t.daynumber) next_daynumber,
                      (case
                        when t.intime > '09:00' and t.outtime < '18:00' then
                         3
                        when t.intime > '09:00' then
                         1
                        when t.outtime < '18:00' then
                         2
                        else
                         0
                      end) status
                 from t_worktime t)
              select a.*,
                     (case
                       when next_daynumber - daynumber > 1 then
                        1
                       else
                        0
                     end) lost_range_mark
                from v_base a) loop
  
    -- 判断迟到
    if r.status <> 0 then
      i := tbl.count + 1; --要+1
      tbl(i).staffid := r.id;
      tbl(i).daynumber := r.daynumber;
      tbl(i).status := r.status;
    
      tbl(i).time1 := (to_date(v_final_date_prefix || ' ' || r.intime,
                               'yyyyMMdd hh24:mi') - v_final_intime) * 24 * 60; --迟到时间(单位：分钟）
      tbl(i).time2 := (v_final_outtime -
                      to_date(v_final_date_prefix || ' ' || r.outtime,
                               'yyyyMMdd hh24:mi')) * 24 * 60; --早退时间(单位：分钟）
    
      if r.status = 2 then
        -- 只早退的不要记录迟到时间，否则会变成负数
        tbl(i).time1 := null;
      elsif r.status = 1 then
        -- 只迟到的不记录早退时间，否则会变成负数
        tbl(i).time2 := null;
      end if;
    
      tbl(i).lost := 0;
    end if;
  
    -- 判断缺勤
    if r.lost_range_mark = 1 then
      -- 找出缺勤的日期
      for j in r.daynumber + 1 .. r.next_daynumber - 1 loop
        dbms_output.put_line(r.daynumber || '~' || r.next_daynumber ||
                             ' ---> ' || j);
        i := tbl.count + 1; --要+1
        tbl(i).staffid := r.id;
        tbl(i).daynumber := j; -- 缺勤日
        tbl(i).status := null;
        tbl(i).time1 := null; --迟到时间(单位：分钟）
        tbl(i).time2 := null; --早退时间(单位：分钟）
        tbl(i).lost := 1;
      end loop;
    
    end if;
  
    -- 批量插入
    if i >= 50000 then
      forall x in 1 .. tbl.count
        insert into t_incorrect_log
          (staffid, daynumber, status, time1, time2, lost)
        values
          (tbl(x).staffid,
           tbl(x).daynumber,
           tbl(x).status,
           tbl(x).time1,
           tbl(x).time2,
           tbl(x).lost);
    
      commit;
      tbl.delete(); -- 一定要清空tbl
    end if;
  
  end loop;

  -- 最后一批数据可能没有达到50000条， 别漏了操作
  forall x in 1 .. tbl.count
    insert into t_incorrect_log
      (staffid, daynumber, status, time1, time2, lost)
    values
      (tbl(x).staffid,
       tbl(x).daynumber,
       tbl(x).status,
       tbl(x).time1,
       tbl(x).time2,
       tbl(x).lost);

  commit;

end;
/

select * from t_incorrect_log;
truncate table t_incorrect_log;  -- 每次测试都先删掉记录表的数据


-- 现在可在 t_incorrect_log 进行更多的分析了， 如看谁是迟到3巨头。。是否超出每个月限定的迟到次数、迟到时间等等。。。


-- 校验是否正确：
-- 运行完存储过程后， 查看 t_incorrect_log 表的数据量， 看和第一条SQL查询出来的数据量是否一致。
-- 也可单独看某个员工的出勤，来和 t_incorrect_log 表的数据进行比对




-- 第二题的答案：每个员工每个月工作总时长
select b.dept, sum(a.day_worktime) / count(distinct a.id) staff_cnt / 30
  from (select x.id,
               (to_date(x.outtime, 'hh24:mi') - to_date(x.intime, 'hh24:mi')) * 24 day_worktime
          from t_worktime x) a
 inner join t_staffer b
    on (a.id = b.id)
 group by b.dept
