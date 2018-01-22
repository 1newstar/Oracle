https://dba.stackexchange.com/questions/696/eliminate-duplicates-in-listagg-oracle


CREATE TABLE ListAggTest AS (
  SELECT rownum Num1, DECODE(rownum,1,'2',to_char(rownum)) Num2 FROM dual 
     CONNECT BY rownum<=6
  );
  
  
  select * from ListAggTest;
  select num1, listagg(num2, '-') within group(order by null) over()
    from listaggtest;
    
  SELECT Num1, 
       RTRIM(
         REGEXP_REPLACE(
           (listagg(Num2,'-') WITHIN GROUP (ORDER BY Num2) OVER ()), 
           '([^-]*)(-\1)+($|-)', 
           '\1\3'),
         '-') Num2s 
FROM ListAggTest;
