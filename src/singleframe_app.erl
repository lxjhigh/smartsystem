%% coding:Latin-1
%% @author liuxiaojun
%% @doc @todo Add description to singleframe_app.

-module(singleframe_app).
-behaviour(gen_server).
-include("smartsystem.hrl").
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%                        单帧应用服务
%%1、处理与规约相关的请求应用
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-export([start_link/1]).
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).
 


%%webpid:http进程ID
%%app:应用码
%%client:mensia映射本地进程号的32位整型
%%ip:主机IP地址
%%port:主机端口号
%%bin：  需要发送的报文
%%num: 重发的次数
-record(state,{webpid,app,client,ip,port,bin,num=1}).


%%Regname:注册名
%%Pid:进程ID
%%Mac:对应主机MAC地址
%%APP:规约对应的应用码
%%Body：规约控制数据正文
start_link({Regname,Pid,Mac,App,Body})->
    %%loger_server:logger("start singleframe app,Regname:~p,  Pid:~p,  Mac:~p,  App:~p, Body:~p",[Regname,Pid,Mac,App,Body]),
	gen_server:start_link({local,Regname}, ?MODULE, [Pid,Mac,App,Body],[]).

 
 
%%初始化
%%通过时钟判断
%%超时重发机制
init([Webpid,Mac,App,Body])->
   %%设置当前进程权限
   process_flag(trap_exit,true),
    
   %%生成一个随机码，完成注册
   Client = guid:get_app_id(),
   Pid = self(),
   
   %%查询当前主机的信息
   %%通过标识符找到对应的进程
   Token = db_tool:get_controler_status(Mac),
   
   %%================================构建请求帧================================
   %%帧头,默认不加密
   Length = 24 + size(Body),
   Bodyhead = <<16#01:8,Length:16,App:8,0:8,6:8,Client:48,Token:32,16#FFFFFFFFFFFF:48,Mac:48>>,
   %%帧正文
   Data = list_to_binary([Bodyhead,Body]),

   %%生成校验码
   Crcode = crc:crc16(Data),
   %%组成请求帧格式
   Bin = list_to_binary([<<16#EB90EB90:32>>,Data,<<Crcode:16>>]),
   
   case db_tool:get_controler_addr(Mac)  of
	   {false,_,_}->
		                %%应答web进程错误信息
		                Webpid ! {?FAIL,Pid,App,?FAIL_OFFLINE},
		                exit(normal);
	   {true,Host,Port}->
		                %%保存客户端标识与进程ID绑定关系
		                db_server:insert(app_map_thread,{Client,Pid}),
						%%发送规约请求
						udp_server:rpc_send(app,node(),Host,Port,Bin),
						%%启动时钟进程
		                spawn_link(fun()->timer_click(Pid) end),
		                {ok,#state{webpid=Webpid,app=App,client=Client,ip=Host,port=Port,bin=Bin}}      
		      
   end.
		                

%%--------------------------------------------------------------------
%% @private
%% @doc
%% @end
%%--------------------------------------------------------------------
handle_call(Request,_From,State)->
	 {reply, {unknown_call, Request}, State}.

handle_cast(_Oher,State)->
  {noreply,State}.


%%正确应答信息0x7F
handle_info({reply,127,App,ReplyInfo},#state{webpid=Webpid,app=App_src,client=Client}=State)->
    %%判断应用码是否一致
	case App == App_src of
                    true->
                            %%清空映射数据
							db_server:delete({app_map_thread,Client}),
							Pid = self(),
							Webpid ! {?SUCESS,Pid,App,ReplyInfo},
							%%自杀
							exit(normal);
  					false->
  				            {noreply,State}
   end;


%%错误应答信息0x80
handle_info({reply,128,App,ReplyInfo},#state{webpid=Webpid,app=App_src,client=Client}=State)->
  case App == App_src of
                    true->
                            %%错误应答信息
							db_server:delete({app_map_thread,Client}),
							Pid = self(),
							Webpid ! {?FAIL,Pid,App,ReplyInfo},
							exit(normal);
  					false->
  							{noreply,State}
  end;
	 

%%定时器事件
handle_info({timer_click},#state{webpid=Webpid,client=Client,app=App,ip=Host,port=Port,bin=Bin,num=Num}=State)->
    %%判断是否超时
	case Num < 3 of
                false->
					%%超时
                    db_server:delete({app_map_thread,Client}),
                    Pid = self(),
  					Webpid ! {?FAIL,Pid,App,?FAIL_OUTIME},
                    exit(normal); 
                true->
                    loger_server:logger("time less 3 time,resend"),
                    udp_server:rpc_send(app,node(),Host,Port,Bin),
                    {noreply,State#state{num=Num+1}}
   end;


%%定时器意外挂掉,要重新启动
%%防止定时器关掉了，本进程退不了
handle_info({'EXIT',_OldPid,_Why},State)->
    Pid = self(),
    spawn_link(fun()->timer_click(Pid) end),
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


%%心跳信号，定时检测当前状态，link报文
%%3秒发送定时报文
timer_click(Pid)->
	receive
	     stop->
	         stop
	after 3000->
	   Pid ! {timer_click},
	   timer_click(Pid)
	end.
	


