%% coding:Latin-1
%% @author liuxiaojun
%% request 
-module(request).

-include("smartsystem.hrl").
%%测试接口
-export([test/3]).
-export([triggle_event/3]).

%%设备下线
triggle_event(Mac,Type,Value)->
   spawn(fun()->http_request_event(Mac,Type,Value) end).

%%0:离线
%%1:上线
%%2:配置文件更新
%%3:设备变位
%%4:需要重新登录
http_request_event(Mac,Type,Bin)->
   Value = util:tostring(Bin),
   URL = util:get_env(?APPNAME,httpaddr,"------"),
   %%io:format("request port :~p~n",[Port_addr]),
    
   %%erlang与web接口方式,EVNET默认值
   %%{ ”event”:EVENT,“app”:APP,“mac”:MAC,“value”:[1,2,1,2,1,2]}
   Json = "{\"event\":" ++ integer_to_list(0) ++ ",\"app\":" ++ integer_to_list(Type) ++ ",\"mac\":" ++ integer_to_list(Mac) ++  ",\"value\":" ++ Value ++ "}",
   io:format("~n[Event]data:~p~n",[Json]),
   %%loger_server:logger("Data:~p",[Bin]),
   %%application/x-www-form-urlencoded
   case httpc:request(post,{URL,[],"application/octet-stream", Json},[],[]) of   
        {ok, {_,_,Body}} -> 
                           donothing;
                           %%loger_server:logger("ok Result: ~p",[Body]);
        {error, Reason}  ->
                           donothing
                           %%loger_server:logger("fail reason: ~p",[Reason])
   end. 
 
%%触发事件
test(Mac,Type,Bin)->
   http_request_event(Mac,Type,Bin).