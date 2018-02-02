%% @author liuheliang
%% @doc @todo Add description to gate_server.


-module(gate_server).

-behaviour(gen_server).
 
 
-export([start_link/1]).
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).


%%--------------------gate_info------------------------------------
%%mac:当前主机的mac
%%status:主机当前状态  0：离线  1：在线
%%devicetype:当前的设备类型，默认为主机0
%%name:当前主机的名称
%%cfgver:配置文件版本
%%scenever:场景文件版本
%%authver:固件版本，暂时不用
%%token:当前的口令
%%time:定时器时间间隔
%%pid:定时器进程，用于跟踪定时器，它挂了需要重启
-record(gate_info,{mac,status=1,devicetype=2,name = <<>>,cfgver=0,scenever=0,authver=0,token=0,time=0,pid}).


%%RegName : 进程注册名
%%Mac: MAC地址
%%Token：口令
%%Binver: 配置文件版本号
%%Scenever:场景文件版本号
%%Authver:主机固件版本
%%Name:主机名
start_link({Regname,Mac,Token,Binver,Scenever,Authver,Name})->
    %%注册名很重要，通过注册名发送消息
	gen_server:start_link({local,Regname}, ?MODULE, [Mac,Token,Binver,Scenever,Authver,Name],[]).


%%LINK帧触发创建主机监督服务，UDP_SERVER
init([Mac,Token,Binver,Scenever,Authver,Name])->
   
   %%很重要，不然就不能监控时钟
   process_flag(trap_exit,true),
   Time = util:time_sec(),
   
   
   %%初始化心跳进程
   Pid = self(),
   TimePid = spawn_link(fun()->timer_click(Pid) end),
   
   
   %%========================【事件】上线====================================
   %%========================设备数据写库====================================
   combine_gate_event(Mac,1,Token,Binver,Scenever,Authver,Name),
   
   State = #gate_info{mac=Mac,name=Name,cfgver=Binver,scenever=Scenever,authver=Authver,token=Token,time=Time,pid=TimePid},
   {ok,State}.

	 
handle_call(Request,_From,State)->
	{reply, {unknown_call, Request}, State}.


handle_cast(_Oher,State)->
  {noreply,State}.

%%link,Src_mac,Token,Binver,Scenever,0,Name
%%udp_server发送过来的link报文，原来状态：离线，检测配置文件是否更新
handle_info({link,Mac_new,Token_new,Binver_new,Scenever_new,Authver_new,Name_new},#gate_info{mac=Mac,status=Status,name=Name,cfgver=Binver,scenever=Scenever,authver=Authver,token=Token}=State)->
  %%记录新的时间
  Time = util:time_sec(),
  io:format("~ngate_controller process~n"),
  %%判断MAC地址是否一致
  case Mac_new =:= Mac of
                        false->
	                           {noreply,State};
                         true->
							  %% 比较配置文件版本、场景文件版本、名字、TOKEN 是否修改，在线，只要有一个修改都产生上报事件
                               case (Binver_new =:= Binver) and (Scenever_new =:= Scenever) and (Name_new =:= Name) and (Authver_new =:= Authver) and (Token_new =:= Token) and (Status =:= 1)of
                                                     true->
														  %%没有任何变化，只需修改时间即可
	                                                      {noreply,State#gate_info{time=Time}};
	                                   
	                                                  false->
	                                                       %%========================【事件】主机相关参数（5）变动，产生事件====================================
									                       combine_gate_event(Mac,1,Token_new,Binver_new,Scenever_new,0,Name_new),
	                                                       {noreply,State#gate_info{name=Name_new,status=1,cfgver=Binver_new,scenever=Scenever_new,authver=Authver,token=Token_new,time=Time}}
	                           end
	end;

 


%%心跳信号,要求状态是在线，离线情况不处理
%%心跳信号，主机在线是才管用
handle_info({timer_click},#gate_info{mac=Mac,status=Status,name=Name,cfgver=Binver,scenever=Scenever,authver=Authver,token=Token,time=Time}=State)when Status=:= 1 ->
  Now = util:time_sec(),
  %%超时判断，超时需要做相应处理
  %%Time时间由LINK来记录
  case (Now - Time) < 40 of
                           true->
                                  {noreply,State};
                           false->
                                  %%=========================【事件】离线============================================
	                              combine_gate_event(Mac,0,Token,Binver,Scenever,Authver,Name),
								  exit(normal),
	                              {noreply,State#gate_info{status=0}}
	          
  end;
	
%%需要定时器长期存在
%%定时器意外挂掉,要重新启动
handle_info({'EXIT',OldPid,_Why},#gate_info{pid=Pid} = State)->
    case OldPid =:= Pid of
                   false->
                         %%其它进程挂了，我不管
                         {noreply,State};
                    true->
                          CurPid = self(),
                          TimePid = spawn_link(fun()->timer_click(CurPid) end),
                          {noreply,State#gate_info{pid=TimePid}}
    end;

                                
handle_info(_Other,State) ->
	{noreply,State}.

terminate(_Reason,_State)->
	ok.

code_change(_OldVsn,State,_Extra)->
	{ok,State}.


%%心跳信号，定时检测当前状态，link报文，心跳频率1秒
timer_click(Pid)->
	receive
	     stop->
	         stop
	after 1000->
	   Pid ! {timer_click},
	   timer_click(Pid)
	end.


%%设备类型：2
%%在线状态 (1 Bytes)//0：离线，1：在线
%%Token (4字节)
%%Cfg Versiong(4个字节)
%%Sence Version(4个字节)
%%Name(32个字节)
%%暂时不考虑软件版本
combine_gate_event(Mac,Status,Token,Binver,Scenever,Authver,Name)->
	%%写入数据库，便于直接查询
	db_server:insert(controller_status,{Mac,Status,2,Name,Binver,Scenever,Authver,Token}),
	%%生成事件正文
	Body = list_to_binary([<<Mac:48>>,<<2:8>>,<<Status:8>>,<<Token:32>>,<<Binver:32>>,<<Scenever:32>>,<<Authver:4>>,Name]),
	%%触发事件
    request:triggle_event(Mac,16#E4,Body).
