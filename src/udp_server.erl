%% coding:Latin-1
%% @author liuxiaojun
%% @doc @todo Add description to udp_server.

-module(udp_server).
-behaviour(gen_server).
-include("smartsystem.hrl").

%%生成校验码
-import(crc, [crc16/1]).
 
-export([start_link/0]).
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).
-export([rpc_send/5]).

-define(TYPE,2).

-record(state,{listener,num}).

%% ====================================================================
%% API functions
%% ====================================================================

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_server process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link()->
	gen_server:start_link({local,?MODULE}, ?MODULE, [],[]).

%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_server process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% 通过udp_server服务器转发的接口
%% Type:ark_httpd;ark_transmit,
%% Bin为list格式
%%  
%%--------------------------------------------------------------------
rpc_send(Type,Srvid,Host,Port,Bin)->
    %%io:format("~nHost:~p  Port:~p   Bin:~p~n",[Host,Port,Bin]),
	case node() =:= Srvid of
		true->
			gen_server:cast(?MODULE,{send,Type,Host,Port,Bin});
		false->
		  void
	end.


%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_server is started using gen_server:start/[3,4] or
%% gen_server:start_link/[3,4], this function is called by the new
%% process to initialize.
%%
%% @spec init(Args) -> {ok, StateName, State} |
%%                     {ok, StateName, State, Timeout} |
%%                     ignore |
%%                     {stop, StopReason}
%% @end
%%--------------------------------------------------------------------
init([])->
     Port_str = util:get_env(?APPNAME,localport,"5001"),
     %%io:format("port:~p~n",[Port_str]),
     Port = list_to_integer(Port_str,10),
	 {ok,Socket} = gen_udp:open(Port,[{active,true}]),
	 {ok,#state{listener=Socket,num=5}}.
	 
%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
handle_call(Request,_From,State)->
	 {reply, {unknown_call, Request}, State}.


%%--------------------------------------------------------------------
%% @private
%% @doc 转发线程处理完成报文
%% @end
%% ark_data     :: 控制报文
%% ark_transmit :: 其它节点服务器报文
%% ark_link     :: link应答报文（服务器合成）
%% ark_httpc    :: httpc发送的请求报文
%%--------------------------------------------------------------------
handle_cast({send,_Arktype,Host,Port,Bin},#state{listener = Socket} = State) ->
	gen_udp:send(Socket,Host,Port,Bin),
	{noreply,State};
	
handle_cast(_Oher,State)->
  {noreply,State}.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% {udp,Socket,Host,Port,Bin} :: 监听到的Socket报文
%% {control,Mac,Data}         :: 模拟主机发送的控制报文
%%--------------------------------------------------------------------
handle_info({udp,_Socket,Host,Port,Bin},#state{listener = Socket,num = Num})  ->
	spawn(fun()->process_udp_packet(Host,Port,Bin) end),
	State = #state{listener=Socket,num = Num + 1},
	{noreply,State};

handle_info({test},State) ->
	io:format("hello world~n"),
	{noreply,State};

handle_info({test,Type},State) when Type =:= ?TYPE ->
	io:format("test1:rev value:~p",[Type]),
	{noreply,State};

handle_info({test,Type},#state{num=Num}=State) when Num =:= Type ->
	io:format("test2:rev value:~p",[Type]),
	{noreply,State};

handle_info(_Other,State) ->
	{noreply,State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
terminate(_Reason,_State)->
	ok.


%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn,State,_Extra)->
	{ok,State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% socket报文帧:检测帧头，检测校验码
%%--------------------------------------------------------------------
process_udp_packet(Host,Port,Bin)->
   
  loger_server:logger(Host,Port,Bin,debug),
  case list_to_binary(Bin) of
  			<<16#EB90EB90:32,Right_remain/binary>> ->
  									                 {Body,<<Crc:16>>} = split_binary(Right_remain,size(Right_remain)-2),
										             case Crc =:= crc16(Body) of
		                                                                        false->
		                                                                               exit(normal);
		                                                                            _->
																						void
		                                               
		                                              end,
	                                                  process_frame(Host,Port,Body,Bin);
	                                          _other->
	       						                       donothing
	end.




%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%  处理主机link报文,注意解析link报文特征  0x1  0x41
%%1、没有将_Dest_mac设置为0xFFFFFFFFFFFF进行强匹配关联
%%2、特征为 0x0F  0xF0  对不同的设备进一步处理
%%3、link报文中正文部分是否填充0,都适合这种匹配模式
%%4、Token也要发送给controller
%%--------------------------------------------------------------------
process_frame(Host,Port,<<16#01:8,_Length:16,16#41:8,Encrypt:8,DeviceType:8,Client:48,Token:32,Src_mac:48,_Dest_mac:48,Content/binary>>,Bin) ->
	  %%保存主机的网络地址信息
      %%io:format("Rev ark link, Data size:~p~n",[length(Bin)]),
	  db_server:insert(mac_map,{Src_mac,Host,Port,DeviceType}),
	   
	  %%合成应答帧
	  Newbin = ark_link_frame(Encrypt,Client,Token,Src_mac),
	  
	  %%返回主机LINK帧
	  rpc_send(link,node(),Host,Port,Newbin),
	  
	  %%loger_server:logger(Host,Port,Bin,debug),
	  
	  %%进一步分析link报文的设备类型
	  process_link_frame(DeviceType,Src_mac,Token,Content);



%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% socket 设备变位报文，直接转给web发出
%%1、设备变位的帧需要特殊处理
%%2、其它类型的帧需要检索对应的进程号转发
%%3、变位的报文直接通过web接口发送出去
%%4、不监测设备类型
%%--------------------------------------------------------------------
process_frame(Host,Port,<<16#01:8, _Length:16,16#40:8,_Encrypt:8,DeviceType:8,_Client:48,_Token:32,Src_mac:48,_Dest_mac:48,Content/binary>>,_Bin) ->	
	  %%更新主机网络地址
	  db_server:insert(mac_map,{Src_mac,Host,Port,DeviceType}),
	  
	  %%云端推送设备变位事件
	  request:triggle_event(Src_mac,16#40,Content);



%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% 特殊监测报文：云端主动LINK主机，应答报文
%%--------------------------------------------------------------------
process_frame(_Host,_Port,<<16#7F:8, _Length:16,16#11:8,_Encrypt:8,DeviceType:8,_Client:48,Token:32,Src_mac:48,_Dest_mac:48,Content/binary>>,_Bin) ->	
	  %%直接按照LINK报文格式交给主机或者网关即可,关键获取时间、token、版本信息
	  process_link_frame(DeviceType,Src_mac,Token,Content);
	   


%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%转发给应用进程的报文：
%%--------------------------------------------------------------------
process_frame(Host,Port,<<Link:8,_Length:16,App:8,_Encrypt:8,DeviceType:8,Client:48,_Token:32,Src_mac:48,_Dest_mac:48,Content/binary>>,Bin) ->	
	  
	  %%loger_server:logger(Host,Port,Bin,debug),
	  %%更新主机网络地址
	  db_server:insert(mac_map,{Src_mac,Host,Port,DeviceType}),
	  
	 
	  
	  %%通过标识符找到对应的进程
	  case db_server:select({app_map_thread,Client}) of
	                                                   undefined->
	                                                              %%无对应进程，直接挂掉
                                                                   io:format("~n[cfg]not find pidid~n"),
	                                                               exit(normal);
	                                                   {app_map_thread,_Appid,Pid}->
														           io:format("~n[cfg_info]find pid,Link:~p,App:~p~n",[Link,App]),
	                                                               %%loger_server:logger("select find"),
	                                                               %%========================【应答】Service====================================
	                                                               Pid ! {reply,Link,App,Content}
	  end;	  


%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% socket 过滤不匹配的帧报文
%%--------------------------------------------------------------------
process_frame(_Host,_Port,_Head,Bin) ->	
    loger_server:logger("can not understand frame ~p",[Bin]).



%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%% 根据不同的设备类型特殊处理link报文
%%--------------------------------------------------------------------
%%智能家居主机：0 
%%OK
process_link_frame(0,Src_mac,Token,Content)->
	
	{Name,<<Binver:32,Scenever:32,Authver:32,_Content/binary>>} =  split_binary(Content,32),
	%%生成规范的link报文
	RegName = util:register_name(Src_mac),
	 
	 
	
	%%通过MAC地址映射到注册进程
	case whereis(RegName) of
  						    undefined->  
								       %%初始化时产生事件，无需再发送事件,软件版本初始为0,目前link报文中没有
                                       controller_server_sup:start_child({RegName,Src_mac,Token,Binver,Scenever,Authver,Name});
		    
                                    _->
									   
                                       RegName ! {link,Src_mac,Token,Binver,Scenever,Authver,Name}
    end;

%%信息箱主机
process_link_frame(1,Src_mac,Token,Content)->
	
	{Name,<<Binver:32,Scenever:32,Authver:32,_Content/binary>>} =  split_binary(Content,32),
	%%生成规范的link报文
	RegName = util:register_name(Src_mac),
	 
	 
	
	%%通过MAC地址映射到注册进程
	case whereis(RegName) of
  						    undefined->  
								       %%初始化时产生事件，无需再发送事件,软件版本初始为0,目前link报文中没有
                                       controller_server_sup:start_child({RegName,Src_mac,Token,Binver,Scenever,Authver,Name});
		    
                                    _->
									   
                                       RegName ! {link,Src_mac,Token,Binver,Scenever,Authver,Name}
    end;

%%智能锁网关：2 
%%OK
process_link_frame(2,Src_mac,Token,Content)->
	%%io:format("~nrev gat link packet~n"),
	{Name,<<Binver:32,Scenever:32, Authver:32,_Content/binary>>} =  split_binary(Content,32),
	%%生成规范的link报文
	RegName = util:register_name(Src_mac),
	case whereis(RegName) of
  						   undefined-> 
  						              %%第一次创建时不会触发crc更新事件                
                                      Result = gate_server_sup:start_child({RegName,Src_mac,Token,Binver,Scenever,Authver,Name}),
									  io:format("~ncreate gate controller result:~p~n",[Result]);
                                   _->
                                      RegName ! {link,Src_mac,Token,Binver,Scenever,Authver,Name}
  end;

%%未定义设备类型
%%OK
process_link_frame(Undefined,Src_mac,Token,Content)->
	%%io:format("~nundefine frame~n"),
	io:format("~n====Type:~p,Mac:~p,token:~p,content:~p ~n",[Undefined,Src_mac,Token,Content]),
	donothing.
	


%%--------------------------------------------------------------------
%%OK
%%数据帧长度：31
%%应答link帧数据，设备类型0x6
%%Encrypt:返回
%%设备类型：0x06
%%客户端标识：0
%%--------------------------------------------------------------------
ark_link_frame(Encrypt,_Client,Token,Src_mac)->
	%% 24 扩展名 + 7位时间长度  = 31
	Body = <<16#7F:8,16#1F:16,16#41:8,Encrypt:8,6:8,0:48,Token:32,16#FFFFFFFFFFFF:48,Src_mac:48>>,
	Time = util:time_data(),
	Data = list_to_binary([Body,Time]),
	Crcode = crc16(Data),
	list_to_binary([<<16#EB90EB90:32>>,Body,Time,<<Crcode:16>>]).