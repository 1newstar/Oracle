/*
create or replace type test_entity as object
(
  owner       varchar2(30),
  object_name varchar2(128),
  object_id   number,
  created     date
);

CREATE OR REPLACE TYPE test_list IS TABLE OF test_entity

*/

declare
  list1 test_list;
  obj1  test_entity;

  type test_rec is record(
    owner       test.owner%type,
    object_name test.object_name%type,
    object_id   test.object_id%type,
    created     test.created%type);
  type tbl_type is table of test_rec index by pls_integer;
  list2 tbl_type;
  obj2  test_rec;

begin
  select owner, object_name, object_id, created
    into obj2
    from test
   where rownum <= 1;

  obj1 := new test_entity(obj2.owner,
                          obj2.object_name,
                          obj2.object_id,
                          obj2.created);

  dbms_output.put_line(obj1.owner);

  /***************************************/
  /**********或者像下面这样来使用*********/
  /***************************************/

  /*这样的话obj1就要提前初始化了*/
  obj1             := new test_entity(null, null, null, null);
  obj1.owner       := obj2.owner;
  obj1.object_name := obj2.object_name;

  dbms_output.put_line(obj1.owner);
end;
/
