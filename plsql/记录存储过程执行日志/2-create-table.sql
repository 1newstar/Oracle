-- Create table
create table T_PROCEDURE_STEP_LOG
(
  taskid        VARCHAR2(32),
  packagename   VARCHAR2(100),
  procedurename VARCHAR2(100),
  step          INTEGER,
  comments      CLOB,
  finishtime    DATE
);
-- Add comments to the table 
comment on table T_PROCEDURE_STEP_LOG
  is '该表记录着存储过程执行每一步的耗时、详细信息等等';
-- Add comments to the columns 
comment on column T_PROCEDURE_STEP_LOG.taskid
  is '任务id, 这个并不是唯一的， 一个taskid有多个step';
comment on column T_PROCEDURE_STEP_LOG.packagename
  is '包名称,如果没有则忽略';
comment on column T_PROCEDURE_STEP_LOG.procedurename
  is '存储过程名称或函数名称';
comment on column T_PROCEDURE_STEP_LOG.step
  is '步骤编号,  同一个taskid下有多个步骤, 以递增来标识步骤先后顺序';
comment on column T_PROCEDURE_STEP_LOG.comments
  is '该步骤的详细记录， 例如依赖变量的值、表的记录数量等等';
comment on column T_PROCEDURE_STEP_LOG.finishtime
  is '该步骤结束时的时间';




