%% @author liuheliang
%% @doc @todo Add description to unit_test.

-module(unit_test).

%% ====================================================================
%% API functions
%% ====================================================================
-export([test/1]).

-import(service, [start_app/4]).

%% ====================================================================
%% Internal functions
%% ====================================================================

%%加载配置文件  
test(1)->
	start_app(1,2,1,<<>>);

%%加载状态文件
test(2)->
	start_app(1,3,1,<<>>);

%%写场景文件
test(3)->
	{ok,Rootpath} = file:get_cwd(),
    Path = Rootpath ++ "/down/secene_" ++ integer_to_list(1) ++ ".bin",
    {ok,Bin} = file:read_file(Path), 
	start_app(1,16#61,1,Bin);

%%读场景文件
test(4)->
	start_app(1,16#62,1,<<>>);

%%写固件版本文件文件,写到DB里面
test(5)->
	{ok,Rootpath} = file:get_cwd(),
    Path = Rootpath ++ "/down/version_" ++ integer_to_list(1) ++ ".bin",
    {ok,Bin} = file:read_file(Path),  
	start_app(1,16#14,1,Bin);

%%WEB请求读取主机状态
test(6)->
	Result = start_app(1,16#F4,1,<<2,1:48,2:48>>),
	io:format("~nRequest Control Result:~p~n",[Result]);

%%WEB登录主机
test(7)->
	Result = start_app(1,16#0F,1,<<2,1:48,2:48>>),
	io:format("~nRequest Control Result:~p~n",[Result]);

%%WEB修改主机密码
test(8)->
	Result = start_app(1,16#08,1,<<0:96>>),
	io:format("~nRequest Control Result:~p~n",[Result]).
