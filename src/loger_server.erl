%% coding:Latin-1
%% @author liuxiaojun
%% @doc @todo Add description to loger_server.


-module(loger_server).
-behaviour(gen_server).
 

-export([start_link/0]).
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).

%%提供接口服务
-export([logger/4,logger/3,logger/2,logger/1]).

%%定义记录，标识开启关闭日志
-record(state,{logger_status=close}).


start_link()->
	gen_server:start_link({local,?MODULE}, ?MODULE, [],[]).

init([])->
   %%默认关闭日志
	 {ok,#state{logger_status=open}}.
	 
handle_call(_Ohter,_From,State)->
   {noreply,State}.

%%通用默认接口
handle_cast({logger,{Value,Arglist,true}},State)->
  error_logger:info_msg(Value,Arglist),
  {noreply,State};
handle_cast({logger,{Value,Arglist}},#state{logger_status=Status}=State) when Status == open->
  error_logger:info_msg(Value,Arglist),
  {noreply,State};
handle_cast({logger,{Value}},#state{logger_status=Status}=State) when Status == open->
  error_logger:info_msg(Value,[]),
  {noreply,State};
  
%%特殊定制接口，解析UDP报文，IP地址，端口号，数据，类型
%%Data必须是二进制
handle_cast({udp_packet,{A,B,C,D,Port,Data,Type}},#state{logger_status=Status}=State) when Status == open->
   case is_list(Data) of
                  true->
                        %%list
   											Data_hex = [string:right( "0" ++ integer_to_list(X,16),2)|| X <-Data],
   											Data_str =  string:join(Data_hex," "),
   											Value = "From: ~p.~p.~p.~p:~p Type: ~p  Data: ~p~n",
   											Arglist = [A,B,C,D,Port,Type,Data_str],
                        error_logger:info_msg(Value,Arglist),
                        {noreply,State};
                  false->
                        %%binary
                        Datalist = [X || <<X:8>> <= Data],
                        Data_hex = [string:right( "0" ++ integer_to_list(X,16),2)|| X <-Datalist],
   										  Data_str =  string:join(Data_hex," "),
   										  Value = "From: ~p.~p.~p.~p:~p Type: ~p  Data: ~p~n",
   										  Arglist = [A,B,C,D,Port,Type,Data_str],
                        error_logger:info_msg(Value,Arglist),
                        {noreply,State}
                       
                      
    end;  
handle_cast(_Other, State)->
  {noreply,State}.
  
	
%%外部隐式接口：接受线程信息，通过窗口打开关闭日志功能
handle_info(open,_State)->
  error_logger:info_msg("loger server start ~n"),
	{noreply,#state{logger_status=open}};
handle_info(close,_State)->
  error_logger:info_msg("loger server close~n"),
	{noreply,#state{logger_status=close}};
handle_info(_Other,State)->
	{noreply,State}.

%%终止接口
terminate(_Reason,_State)->
	ok.

%%代码热切换接口
code_change(_OldVsn,State,_Extra)->
	{ok,State}.


%%定制接口接口 Ip地址，端口号，数据，类型
logger({A,B,C,D},Port,Data,Type)->
   gen_server:cast(?MODULE,{udp_packet,{A,B,C,D,Port,Data,Type}}).




%%通用接口
logger(Value,Arglist)->
   gen_server:cast(?MODULE,{logger,{Value,Arglist}}).
logger(Value,Arglist,true)->
   gen_server:cast(?MODULE,{logger,{Value,Arglist,true}});
logger(Value,Arglist,_)->
   gen_server:cast(?MODULE,{logger,{Value,Arglist}}).
logger(Value)->
   gen_server:cast(?MODULE,{logger,{Value}}).