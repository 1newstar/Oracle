http://bbs.csdn.net/topics/392307147
update tmp_1 a set sfxz='是' where exists(select 1 from tmp_2  where instr(a.addr,b.addr_all)>0);
commit;


a，b表数据都是在二十万左右，因为执行很慢，被killed 