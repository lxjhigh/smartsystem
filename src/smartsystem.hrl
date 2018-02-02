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

%%保存主机、网关实时的状态
%%srcmac:MAC地址
%%status:0离线，1在线，
%%devicetype:设备类型，主机，网关
%%name:设备名称
%%cfgver:配置文件版本
%%scenever:场景文件版本
%%softver:固件版本
%%token:令牌
%%忽略加密解密字段
-record(controller_status,{
		   srcmac,
		   status,
		   devicetype,
		   name,
		   cfgver,
		   scenever,
		   softver,
		   token		  
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

%%0：成功，VALUE 返回的数据
%%1：失败，对应value：0xF0(不在线)，0xF1(未登录)，0xF2(超时)，0xF3(未知)

-define(SUCESS,0).
-define(FAIL,1).
-define(FAIL_OFFLINE,<<16#F0:8>>).
-define(FAIL_NOLOGIN,<<16#F1:8>>).
-define(FAIL_OUTIME,<<16#F2:8>>).
-define(FAIL_OTHER,<<16#F3:8>>).
