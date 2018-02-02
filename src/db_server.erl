%% coding:Latin-1
%% @author liuxiaojun
%% @doc @todo Add description to db_server.

-module(db_server).
-behaviour(gen_server).
-include("smartsystem.hrl").
 

%%-----------------标准接口-----------------------------
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).
-export([create_table/0]).
-export([select/1,insert/2,delete/1]).
-export([start_link/0]).
%%-export([test_init/0,test_divorce/0]).
%%----------------------------------------------------
%%数据库异常->db_server重启->检测数据库状态
%%

%%初始化数据库状态
-record(db_state,{db_init=false}).

%%查询
select({mac_map,Mac})->
  gen_server:call(?MODULE,{select,{mac_map,Mac}});
select({app_map_thread,AppId})->
  gen_server:call(?MODULE,{select,{app_map_thread,AppId}});
select({controller_status,Mac})->
  gen_server:call(?MODULE,{select,{controller_status,Mac}});
select(_Select)->
  donothing.
  
  
%%插入
insert(mac_map,{Mac,Host,Port,DeviceType})->
  gen_server:cast(?MODULE,{insert,{mac_map,Mac,Host,Port,DeviceType}});
insert(mac_oper,{Mac,DeviceType,Destmac,Linktype,Opertype})->
  gen_server:cast(?MODULE,{insert,{mac_oper,Mac,DeviceType,Destmac,Linktype,Opertype}});
insert(controller_status,{Mac,Status,Devicetype,Name,Cfgver,Scenever,Softver,Token})->
	gen_server:cast(?MODULE,{insert,{controller_status,Mac,Status,Devicetype,Name,Cfgver,Scenever,Softver,Token}});
insert(app_map_thread,{AppId,Pid})->
  gen_server:cast(?MODULE,{insert,{app_map_thread,AppId,Pid}});
insert(_NoTable,_Null)->
  donothing.

%%删除
delete({app_map_thread,AppId})->
	gen_server:cast(?MODULE,{delete,{app_map_thread,AppId}});
delete(_Other)->
  donothing.


start_link()->
	gen_server:start_link({local,?MODULE}, ?MODULE, [],[]).

init([])->
     process_flag(trap_exit,true),
     spawn(fun()->wait_mnesia_init()end),
     {ok,#db_state{db_init=false}}.
	 
%%查询
handle_call({select,{mac_map,Mac}},_From,#db_state{db_init = Status} = State) when Status=:=true->
   case mnesia:dirty_read(mac_map,Mac) of
        []->
            {reply, undefined, State};
        [Result|_Right]->    
	           {reply, Result, State}
	  end;

handle_call({select,{app_map_thread,Appid}},_From,#db_state{db_init = Status} = State) when Status=:=true->
   case mnesia:dirty_read(app_map_thread,Appid) of
        []->
             {reply, undefined, State};
        [Result|_Right]->    
	           {reply, Result, State}
	  end;

%%select controller_status
handle_call({select,{controller_status,Mac}},_From,#db_state{db_init = Status} = State) when Status=:=true->
   case mnesia:dirty_read(controller_status,Mac) of
        []->
            {reply, undefined, State};
        [Result|_Right]->    
	           {reply, Result, State}
	  end;

 
%%查询失败：数据库未准备好
handle_call({select,_Table},_From,#db_state{db_init = Status}=State) when Status=:=false->
   {reply, undefined, State};
   

handle_call(_Ohter,_From,State)->
   {noreply,State}.



%%插入：mac_map
handle_cast({insert,{mac_map,Mac,Host,Port,DeviceType}},#db_state{db_init = Status} = State) when Status=:=true ->
    Time = calendar:datetime_to_gregorian_seconds(calendar:local_time()),
    case mnesia:dirty_read(mac_map,Mac) of
        []->
            Row = #mac_map{srcmac=Mac,srvid=node(),host=Host,port = Port,devicetype=DeviceType,startime=Time,latestime=Time},
            mnesia:dirty_write(Row);
        [{mac_map,_Srcmac,_Srcid,_Host,_Port,_Devicetype,Starttime,Latestime}|_Right]->  
             case (Time - Latestime) < 30 of
                  true->
	                     Row = #mac_map{srcmac=Mac,srvid=node(),host=Host,port = Port,devicetype=DeviceType,startime=Starttime,latestime=Time},
                       mnesia:dirty_write(Row);
                  false->
                       Row0 = #mac_map{srcmac=Mac,srvid=node(),host=Host,port = Port,devicetype=DeviceType,startime=Time,latestime=Time},
                       mnesia:dirty_write(Row0),
                       Guid = guid:get_guid(),
                       Row1 = #mac_map_ram{guid=Guid,srcmac=Mac,srvid=node(),host=Host,port = Port,devicetype=DeviceType,startime=Starttime,latestime=Latestime},
                       mnesia:dirty_write(Row1)
             end
	   end,
   {noreply,State};


%%插入：mac_oper
handle_cast({insert,{mac_oper,Mac,DeviceType,Destmac,Linktype,Opertype}},#db_state{db_init = Status} = State) when Status=:=true ->
    Time = calendar:datetime_to_gregorian_seconds(calendar:local_time()),
    Guid = guid:get_guid(),
    Row = #mac_oper{guid=Guid,srcmac=Mac,devicetype=DeviceType, destmac=Destmac,linktype=Linktype,opertype=Opertype,time=Time},
    mnesia:dirty_write(Row),
   {noreply,State};
   

%%插入：app_map_thread
handle_cast({insert,{app_map_thread,Appid,Pid}},#db_state{db_init = Status} = State) when Status=:=true ->
    Row = #app_map_thread{guid=Appid,pid=Pid},
    Result = mnesia:dirty_write(Row),
    %%loger_server:logger("db operate:~p",[Result]),
    {noreply,State};

%%插入：主机状态列表
handle_cast({insert,{controller_status,Mac,Devstatus,Devicetype,Name,Cfgver,Scenever,Softver,Token}},#db_state{db_init = Status} = State) when Status=:=true ->
     
	Row = #controller_status{srcmac=Mac,status=Devstatus,devicetype=Devicetype,name=Name,cfgver=Cfgver,scenever=Scenever,softver=Softver,token=Token},
    Result = mnesia:dirty_write(Row),
    %%loger_server:logger("db operate:~p",[Result]),
    {noreply,State};
    
%%插入失败：数据库未准备好
handle_cast({insert,_},#db_state{db_init = Status}=State) when Status =:= false->
    loger_server:logger("mnesia was not ready...~n"),
    {noreply,State};
    
    
%%删除设备app_map_thread
handle_cast({delete,{app_map_thread,AppId}},#db_state{db_init = Status}=State) when Status =:= true->
    loger_server:logger("delete record:Appid:~p~n",[AppId]),
    mnesia:dirty_delete({app_map_thread,AppId}), 
    {noreply,State};


%%检测线程检测数据库完毕，通知db_server服务器提供服务
handle_cast(mnesia_ready,_State)->
    {noreply,#db_state{db_init=true}};
    

%%通用默认接口
handle_cast(Other, State)->
  {noreply,State}.

 
%%不提供这种服务
handle_info(_Other,State)->
	{noreply,State}.

%%终止接口
terminate(_Reason,_State)->
	ok.

%%代码热切换接口
code_change(_OldVsn,State,_Extra)->
	{ok,State}.



%%单节点初始化数据库（本地）
create_table()->
  mnesia:stop(),
  Schema_result = mnesia:create_schema([node()]),
  error_logger:info_msg("create_schema result is ~p~n",[Schema_result]),
  mnesia:start(),
  case proplists:get_value(mac_map,mnesia:system_info(tables)) of
       undefined->
              		%%Opts = [{type,set},{disc_copies, [node()]}],
              		Opts = [{type,set},{ram_copies, [node()]}],
              		Result = mnesia:create_table(mac_map, [{attributes,record_info(fields,mac_map)} | Opts]),
              		error_logger:info_msg("create table result is ~p~n",[Result]);
               _->
                  error_logger:info_msg("The table was created~n")
   end,
   
   case proplists:get_value(mac_map_ram,mnesia:system_info(tables)) of
       undefined->
                 %%Opts_1 = [{type,set},{ram_only_copies, [node()]}],
                 Opts_1 = [{type,set},{ram_copies, [node()]}],
                 Result_1 = mnesia:create_table(mac_map_ram, [{attributes,record_info(fields,mac_map_ram)} | Opts_1]),
                 error_logger:info_msg("create table result is ~p~n",[Result_1]);
               _->
                  error_logger:info_msg("The table was created~n")
   end,
   
   case proplists:get_value(mac_oper,mnesia:system_info(tables)) of
       undefined->
                   %%Opts_2 = [{type,set},{ram_only_copies, [node()]}],
                   Opts_2 = [{type,set},{ram_copies, [node()]}],
                   Result_2 = mnesia:create_table(mac_oper, [{attributes,record_info(fields,mac_oper)} | Opts_2]),
                  error_logger:info_msg("create table result is ~p~n",[Result_2]);
               _->
                 error_logger:info_msg("The table was created~n")
   end,
  
   case proplists:get_value(controller_status,mnesia:system_info(tables)) of
       undefined->
              		 
              		Opt_5 = [{type,set},{ram_copies, [node()]}],
              		Result5 = mnesia:create_table(controller_status, [{attributes,record_info(fields,controller_status)} | Opt_5]),
              		error_logger:info_msg("create table result is ~p~n",[Result5]);
               _->
                  error_logger:info_msg("The table was created~n")
   end,
   
   case proplists:get_value(app_map_thread,mnesia:system_info(tables)) of
       undefined->
              		%%Opts = [{type,set},{disc_copies, [node()]}],
              		Opt_4 = [{type,set},{ram_copies, [node()]}],
              		Result4 = mnesia:create_table(app_map_thread, [{attributes,record_info(fields,app_map_thread)} | Opt_4]),
              		error_logger:info_msg("create table result is ~p~n",[Result4]);
               _->
                  error_logger:info_msg("The table was created~n")
   end.
   

%%经典判断
wait_mnesia_init()->
    process_flag(trap_exit,true),
    Pid = spawn_link(fun()->wait_mnesia_init_loop() end),
    receive
        {'EXIT',Pid,mnesia_ok}->
                 ok;
        {'EXIT',Pid,Reason}->
                error_logger:info_msg("Pid:~p died,Reason:~p, wait 2 seconds,restart~n",[Pid,Reason]),
                timer:sleep(2000),
                wait_mnesia_init()
    end.


%%封装一层的目的：防止线程执行异常，导致db_server处于false僵死状态        
wait_mnesia_init_loop()->
    mnesia:start(),
    case mnesia:wait_for_tables([mac_oper,mac_map,mac_map_ram,app_map_thread],5000) of
         {error,Reason}->
                error_logger:info_msg("mnesia tables are not accessed, reason is ~p, wait 5s...~n",[Reason]),
                wait_mnesia_init_loop();
         {timeout,_}->
                error_logger:info_msg("mnesia tables are not accessed,wait 5s...~n"),
                wait_mnesia_init_loop();
              ok    ->
                gen_server:cast(?MODULE,mnesia_ready),
                error_logger:info_msg("mnesia starts ...~n"),
                exit(mnesia_ok)   
   end.