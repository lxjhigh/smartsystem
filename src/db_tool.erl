%% @author liuheliang
%% @doc @todo Add description to db_tool.

-module(db_tool).

%% ====================================================================
%% API functions
%% ====================================================================
-export([get_controler_status/1,get_controler_addr/1]).


%% ====================================================================
%% Internal functions
%% ====================================================================

%%获取主机的信息令牌
get_controler_status(Mac)->
   %%查询当前主机的信息
   %%通过标识符找到对应的进程
   case db_server:select({controller_status,Mac}) of
	                                      undefined->
											          %%采用默认值
	                                                  0;
	        {controller_status,_Mac,_Status,_Devicetype,_Name,_Cfgver,_Scenever,_Softver,Token}->
				                                      Token
	                                                               
   end.

%%获取主机的网络地址
get_controler_addr(Mac)->
	case db_server:select({mac_map,Mac}) of
         {mac_map,_Srcmac,_Srvid,Host,Port,_Devicetype,_Startime,_Latestime}->
			       {true,Host,Port};
          undefined->
			       {false,0,0}
		               
	end.
