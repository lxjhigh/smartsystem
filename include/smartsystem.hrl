%% coding:Latin-1
%% @author liuxiaojun
%% @doc @todo Add description
%%内存表，MAC地址映射<IP,Port>
-record(mac_map,{
           srcmac,      
           srvid,
           host,
           port,
           devicetype,
           startime,
           latestime
           }).


%%持久化表，记录手机、主机在线状态
-record(mac_map_ram,{
           guid,
           srcmac,      
           srvid,
           host,
           port,
           devicetype,
           startime,
           latestime
           }).
           
%%持久化表：记录用户操作记录
-record(mac_oper,{
          guid,
          srcmac,
          devicetype,
          destmac,
          linktype,
          opertype,
          time
        }).
        
%%32位唯一码映射到进程ID
-record(app_map_thread,{
          guid,
          pid  
			 }).
			 
-define(APPNAME,smartsystem).

-define(SUCESS,0).
-define(FAIL,1).

%%失败类型
%%离线
-define(FAIL_OFFLINE,<<0:8>>).
%%未登录
-define(FAIL_UNLOGIN,<<1:8>>).
%%超时
-define(FAIL_OUTIME,<<2:8>>).
%%未知
-define(FAIL_UNKOWN,<<3:8>>).
%%未知
-define(FAIL_PARAMERROR,<<4:8>>).
 