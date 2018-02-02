%% @author liuheliang
%% @doc @todo Add description to mutilframe_scenedown.

%%主机主动，主机要第几帧就返回第几帧

-module(mutilframe_scenedown).

-behaviour(gen_fsm).
%%写场景数据
-define(TYPE,16#61).

-include("smartsystem.hrl").

%% API
-export([start_link/1]).
 
%% gen_fsm callbacks
-export([init/1,handle_event/3,
     handle_sync_event/4, handle_info/3, terminate/3, code_change/4]).

%%=========================【静态数据】=============================
%%webpid:http进程ID
%%client:mensia映射本地进程号的32位整型
%%mac：目标主机MAC地址
%%ip:主机IP地址
%%port:主机端口号
%%===================================================================== 
-record(static_data,{webpid,token,client,mac,ip,port}).


%%=========================【动态数据】=============
%%bindex:期望确认帧号
%%totalength:总的帧长
%%sendset:待发送集合
%%lastsend:上一次发送
%%time:上一次发送帧的时间，用于计算超时
%%num:超时次数，用户记录超时时间
-record(dynamic_data,{bindex=0,sendset,lastsend,time=0,num=0,totalength=0}).       %%用于下载配置文件与状态信息


%%--------------------------------------------------------------------
%% @doc
%% Creates a gen_fsm process which calls Module:init/1 to
%% initialize. To ensure a synchronized start-up procedure, this
%% function does not return until Module:init/1 has returned.
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link({Regname,Pid,Mac,Bin,Bincrc}) ->
    gen_fsm:start_link({local, Regname}, ?MODULE, [Pid,Mac,Bin,Bincrc], []).
     
 
%%%===================================================================
%%% gen_fsm callbacks
%%%===================================================================
 
%%进程ID,Mac,?TYPE类型
%%Bin需要下载的文件
%%Bincrc bin文件校验和
init([Webpid,Mac,Srcbin,Bincrc]) ->
	
	process_flag(trap_exit,true),
	%%加载文件
    Pid = self(),
	%%{TotalNum,[{1,length,content},{2,length,content},{3,length,content}]}
	{Totalnum,FrameList} = mutilframe_tool:form_frame_list(Srcbin),
	%%io:format("~ntotal:~p   length:~p~n",[Totalnum,FrameList]),
	%%io:format("~ndata:~p~n",[FrameList]),
	
	%%查询当前主机的信息
    %%通过标识符找到对应的进程
    Token = db_tool:get_controler_status(Mac),
	Client = guid:get_app_id(),
	 
	
	%%================================构建信息帧APP:0x02  CMD:0x2================================
	Bin = form_info_frame(Client,Token,Mac,Totalnum,size(Srcbin),Bincrc),
	case db_tool:get_controler_addr(Mac)  of
	   {false,_,_}->
		                %%应答web进程错误信息
		                Webpid ! {?FAIL,Pid,?TYPE,?FAIL_OFFLINE},
		                exit(normal);    
	   {true,Host,Port}->
		                %%保存客户端标识与进程ID绑定关系
		                db_server:insert(app_map_thread,{Client,Pid}),
						%%发送信息帧
						udp_server:rpc_send(app,node(),Host,Port,Bin),
						%%启动时钟进程
		                spawn_link(fun()->timer_click(Pid) end),
		                 
                        %%当前时间
	                	Currentime = util:time_sec(),
	                
	                    %%静态数据
                        Static = #static_data{webpid=Webpid,token=Token,client=Client,mac=Mac,ip=Host,port=Port},
                    
						%%动态数据
		                Dynamic = #dynamic_data{bindex=0,sendset=FrameList,lastsend=Bin,time=Currentime,num=0,totalength=Totalnum},
		                
	                    %%启动心跳时钟，1秒启动一次
	                    spawn_link(fun()->timer_click(Pid) end),

                        %%【【【【【测试】】】】】】场景进程成功
                        %%loger_server:logger("muti create success,Static:~p,Dynamic:~p",[Static,Dynamic]),
                    
                        %%进入信息帧等待状态
		                {ok,info,{Static,Dynamic}}
		    
    end.
        
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:send_all_state_event/2, this function is called to handle
%% the event.
%%
%% @spec handle_event(Event, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState}
%% @end
%%--------------------------------------------------------------------
handle_event(_Event, StateName, State) ->
    {next_state, StateName, State}.
 
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a gen_fsm receives an event sent using
%% gen_fsm:sync_send_all_state_event/[2,3], this function is called
%% to handle the event.
%%
%% @spec handle_sync_event(Event, From, StateName, State) ->
%%                   {next_state, NextStateName, NextState} |
%%                   {next_state, NextStateName, NextState, Timeout} |
%%                   {reply, Reply, NextStateName, NextState} |
%%                   {reply, Reply, NextStateName, NextState, Timeout} |
%%                   {stop, Reason, NewState} |
%%                   {stop, Reason, Reply, NewState}
%% @end
%%--------------------------------------------------------------------
handle_sync_event(_Event, _From, StateName, State) ->
    Reply = ok,
    {reply, Reply, StateName, State}.
    
 
%%信息帧  与配置文件差别，缺少版本号
%%UDP_SERVER发过来的信息帧0x7F  0x02
%%======================================数据信息帧格式===========================
%%扩展数据(N bytes)
%%数据帧号0(2 bytes)
%%===========================================================================
handle_info({reply,16#7F,?TYPE,<<0:16,_Other/binary>>},info,{#static_data{token=Token,client=Client,mac=Mac,ip=Desthost,port=Destport}=Static,Dynamic}) ->
    
	Newtime = util:time_sec(),
	%%================================构建数据帧 ================================
    #dynamic_data{sendset=[{Frameindex,Bin}|Remainset]} = Dynamic,
   
    Dataframe = form_data_frame(Client,Token,Mac,1,Bin),
	io:format("~n[sence]send ~p~n",[1]),
	
	%%更新时间
    %%loger_server:logger("muti:form the first data frame:~p",[Dataframe]),
    %%【发送请求帧】
    udp_server:rpc_send(app,node(),Desthost,Destport,Dataframe),
	
    %%loger_server:logger("INFO==>>>MAC:~p, infobin:~p",[Mac,Bin]),
    %%loger_server:logger("INFO==>>>MAC:~p  TotalCount:~p  Totalength:~p",[Mac,Framecount,Totalength]),         
    
	%%【状态跳跃】
    %%期望收到第1帧
    {next_state,data,{Static,Dynamic#dynamic_data{bindex=1,sendset=Remainset,lastsend=Dataframe,time=Newtime}}};
		
%%错误的信息帧
%%直接返回错误
%%错误码由web端解析
%%0x01	无效的命令字	未定义的命令字
%%0x02	CRC校验错	CRC校验错误
%%0x03	字节数不符	字节间超过400mS
%%0x04	接收超时	报文中止1.5s
%%0x05	通讯超时	无应答
%%0x06	无效的功能码	未定义的功能码
%%0x07	无效的下载文件	下载数据文件与对应功能不符
%%0x08	主机配置发生变化	上位机需要重新获取主机配置
%%0x09	未登录设备	设备未登录，不能操作主机
%%0x0A	登陆密码错误	登陆时输入密码错误
%%0x0B	主机忙	主机正在下载数据时，或下载数据异常终止时的提示；
%%0x0C	主机无配置数据	当设备读取配置时无配置NAK回复
%%0x0D	原密码验证错误	修改密码时原密码验证错误
%%0x10	外网不允许升级APP程序	外网下不允许更新主机或者从机APP程序
%%0x11	异常操作	针对一些不符合正常逻辑对主机的操作：如在主机进行逻辑运算时下载配置数据或下载数据时在没有接收到信息帧的情况下接收到数据帧等
handle_info({reply,16#80,?TYPE,<<Errorcode:8,_Ohter/binary>>},info,{#static_data{webpid=Webpid,client=Client},_Dynamic})->
	Pid = self(),
    Webpid ! {?FAIL,Pid,?TYPE,<<Errorcode:8>>},
    db_server:delete({app_map_thread,Client}),
    exit(normal);
    
 

%%开始处理接收到的数据
%%处理配置数据帧
%%数据类型2
%%帧的校验码
handle_info({reply,16#7F,?TYPE,<<Arkindex:16,SecenCrc:32,Framedata/binary>>},data,{Static,Dynamic})->
	  
	 %%#dynamic_data{sendset=[bindex=Bindex,{Frameindex,Bin}|Remainset]}=Dynamic,
	 
	 #static_data{webpid=Webpid,client=Client,token=Token,mac=Mac,ip=Desthost,port=Destport} = Static,
     #dynamic_data{bindex=Bindex,sendset=Sendset,lastsend=Lastsend}=Dynamic,
     Pid = self(),
	 
	 
	 %%判断收到的帧是否是期望的帧号
     case Arkindex == Bindex of
		                  false->
							       %%io:format("~n[sence]rev index:~p   expect index:~p~n",[Frameindex,Bindex]),
                                   %%发现帧号不一致，重新发一次要的帧号
                                   %%loger_server:logger("mutil:frame index no correct ,resend"),
                                   %%loger_server:logger("DATA==>>>MAC:~p resend:~p",[Mac,Frameindex]),
                                   udp_server:rpc_send(app,node(),Desthost,Destport,Lastsend),
                                   {next_state,data,{Static,Dynamic}};
                           true->
                                   case Sendset of
                                                         []->
															   %%发送完毕                                                                 
                                                               %%【返回数据】
                                                               Webpid ! {?SUCESS,Pid,?TYPE,<<SecenCrc:32>>},
                                                               db_server:delete({app_map_thread,Client}),
                                                               exit(normal);
                                                         [{Frameindex,Bin}|Remainset]->
															     
															    %%收集数据
							                                    Newtime = util:time_sec(),                                                             
							                                    Dataframe = form_data_frame(Client,Token,Mac,Frameindex,Bin),
							                                    %%发送下一数据帧
																udp_server:rpc_send(app,node(),Desthost,Destport,Dataframe),
																%%切换到下一个状态：期望序号递增，更新接受报文，更新发送报文，更新时间，重
							                                    %%期望帧号递增
							                                    %%更新接收报文集合
							                                    %%更新发送报文
							                                    %%重置超时时间
							                                    %%判断是否发送完毕
																{next_state,data,{Static,Dynamic#dynamic_data{bindex=Frameindex,sendset=Remainset,lastsend=Dataframe,time=Newtime}}}
	
                                    end
                                        
                           
      end;
                      
 
		 
%%处理心跳信号
handle_info({time_click},State,{Static,Dynamic})->
    #static_data{webpid=Webpid,client=Client,ip=Desthost,port=Destport} = Static,
    #dynamic_data{lastsend=Lastsend,time=Time,num=Num} = Dynamic,
   
    %%当前时间
    Currentime = util:time_sec(),
    Pid = self(),
    
    %%超过3秒没有返回就是超时
    case (Currentime - Time) < 3  of 
                               true->
                                    %%未超时，不处理
                                    {next_state,State,{Static,Dynamic}};
                               false->
                                    %%重发次数是否超过3次
                                    case Num < 3 of
                                             true->
                                                   %%重发，同时修改时间,修改重发次数
                                                   %%loger_server:logger("muti:time_click ,resend"),
                                                   udp_server:rpc_send(app,node(),Desthost,Destport,Lastsend),
                                                   {next_state,State,{Static,Dynamic#dynamic_data{time=Currentime,num=Num+1}}};
                                             false->
                                                    %%【超时应答】
                                                    %%loger_server:logger("muti:over time out,wepid:~p",[Webpid]),
                                                    %%超时错误码
												    Webpid ! {?FAIL,Pid,?TYPE,?FAIL_OUTIME},
                                                    db_server:delete({app_map_thread,Client}),
                                                    %%使命完结，结束
                                                    exit(normal)
                                     end
     end;
                                         
handle_info(_Info,Statename,State)->
    
    {next_state, Statename, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_fsm when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_fsm terminates with
%% Reason. The return value is ignored.
%%
%% @spec terminate(Reason, StateName, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _StateName, _State) ->
    ok.
 
%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, StateName, State, Extra) ->
%%                   {ok, StateName, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, StateName, State, _Extra) ->
    {ok, StateName, State}.
 
 
%%心跳信号，定时检测当前状态，link报文
%%3秒发送定时报文
timer_click(Pid)->
	receive
	     stop->
	         stop
	after 1000->
	   Pid ! {time_click},
	   timer_click(Pid)
	end.

%%==========================================信息帧结构===========
%%合成信息帧
%%扩展数据(N bytes)
%%数据帧号（2 bytes 先高后低）
%%数据的总帧数（2 bytes先高后低）
%%数据版本号（4 bytes先高后低下） 000000000000
%%数据压缩算法(1 byte)
%%数据包长度（4byte 先高后低）
%%场景数据校验码（4byte先高后低）
form_info_frame(Client,Token,Mac,Framecount,Framelength,Crc)->
	%% 24 + 17 = 41
	Length = 24 + 17,
	Head = <<16#02:8,Length:16,?TYPE:8>>,
	Extend = <<0:8,6:8,Client:48,Token:32,16#FFFFFFFFFFFF:48,Mac:48>>,
	Data = <<0:16,Framecount:16,0:32,0:8,Framelength:32,Crc:32>>,
	Body = list_to_binary([Head,Extend,Data]),
     
    %%生成校验码
    Crcode = crc:crc16(Body),
    %%组成请求帧格式
    list_to_binary([<<16#EB90EB90:32>>,Body,<<Crcode:16>>]).
	

%%合成数据请求帧3,2
%%扩展数据(N bytes)
%%数据帧帧号（2bytes 先高后低）
%%数据实体
form_data_frame(Client,Token,Mac,Frameindex,Bin)->
	%%================================构建请求数据帧 APP:0x02  CMD:0x3================================
    %%帧头,默认不加密  24 + 2,body:帧号，2个字节
    Length = 24 + 2 + size(Bin),
	Head = <<16#03:8,Length:16,?TYPE:8>>,
	Extend = <<0:8,6:8,Client:48,Token:32,16#FFFFFFFFFFFF:48,Mac:48>>,
	%%第1帧
	Data = <<Frameindex:16>>,
	Body = list_to_binary([Head,Extend,Data,Bin]),
    %%生成校验码
    Crcode = crc:crc16(Body),
    %%组成请求帧格式
    list_to_binary([<<16#EB90EB90:32>>,Body,<<Crcode:16>>]).
