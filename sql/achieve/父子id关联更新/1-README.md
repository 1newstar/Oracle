REGION_ID	REGION_NAME	PARENT_REGION_ID	LEVEL_KIND
111	中国		1
222	广东省	111	2
555	深圳市	222	3
ccc	广州市	222	3
333	湖北省	111	2
aaa	湖南省	111	2
bbb	浙江省	111	2
ggg	福田区	555	4
hhh	南山区	555	4
ddd	惠州市	222	3
eee	武汉市	333	3
fff	孝感市	333	3
zzz	汉川	fff	4
yyy	孝南	fff	4

类似上面的这种数据, region_id和parent_region_id列不符合规则, 现在想要关联更新成sys_guid(), 
该如何实现呢?
