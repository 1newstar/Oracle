SQL> select regexp_substr('17,20,23', '[^,]+', 1, 3, 'i') as str from dual ;
STR
---
23



SQL> select regexp_substr('17,20,23', '[^,]+', 1, level, 'i') as str from dual connect by level <= 3;
STR
--------------------------------
17
20
23



SQL> select regexp_count('17,20,23', ',') cnt from dual;
       CNT
----------
         2



SQL> select regexp_substr('17,20,23', '[^,]+', 1, level, 'i') str
  2    from dual
  3  connect by level <= regexp_count('17,20,23', ',') + 1;
STR
--------------------------------
17
20
23




SQL> select regexp_substr('17,20,23', '[^,]+', 1, level, 'i') str
  2    from dual
  3  connect by level <=
  4             length('17,20,23') - length(regexp_replace('17,20,23', ',')) + 1;
STR
--------------------------------
17
20
23         