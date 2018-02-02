%% coding:Latin-1
%% @author liuxiaojun
%% service 
-module(service).
-export([visit/3,test/3]).
-export([askcfg/3,askstatus/3]).
-export([start_app/4]).
-include("smartsystem.hrl").
%%  web接口
%%  {obj,[{result,"success"},{mac,Mac},{app,App},{reply,Reply}]}
%%  {obj,[{result,"fail"},{mac,Mac},{app,App},{reply,""}]}
%%  {obj,[{result,"timeout"},{mac,Mac},{app,App},{reply,""}]} 
%%  {obj,[{result,"exception"},{mac,""},{app,""},{reply,"input json param exception"}]}
%%  {obj,[{result,"offline"}, {mac,Mac},{app,App},{reply,"the control is not online"}]}

test(SessionID,_Env,_Input)->
    %%loger_server:logger("Input info:~p",[Env]),
    
		mod_esi:deliver(SessionID, [
            "Content-Type: text/html\r\n\r\n", 
               "<html><body>" ++ "Hello world" ++ "!</body></html>"
        ]).

%%下载配置文件
askcfg(SessionID,_Env,_Input)->
	case start_app(19929527366,0,1,<<145:8,0:8>>) of
				 {success,Reply}->
					 {ok,Rootpath} = file:get_cwd(),
                     Path = Rootpath ++ "/cfg.bin",
			         file:write_file(Path,Reply);
					 %%loger_server:logger("down cfg is:~p",[Reply]),
					 %%{ok,F}=file:open("cfg.bin",write), %%写模式
                     %%file:write_file(F, Reply);
		              
		                    Other->
								loger_server:logger("down cfg is:~p",[Other])
	end,
	mod_esi:deliver(SessionID, [
            "Content-Type: text/html\r\n\r\n", 
               "<html><body>" ++ "read cfg finished" ++ "!</body></html>"
    ]).


%%请求状态文件
askstatus(SessionID,_Env,_Input)->
	case start_app(19929527366,1,1,<<145:8,0:8>>) of
				 {success,Reply}->
					 {ok,Rootpath} = file:get_cwd(),
                     Path = Rootpath ++ "/status.bin",
			         file:write_file(Path,Reply);
		                    Other->
								loger_server:logger("down status is :~p",[Other])
	end,
    mod_esi:deliver(SessionID, [
            "Content-Type: text/html\r\n\r\n", 
               "<html><body>" ++ "read status finished" ++ "!</body></html>"
    ]).
					 
%%统一访问接口                
visit(SessionID, _Env, Input) ->
  io:format("~n[Rev]web rev~p~n",[Input]),
  case util:get_param(Input)  of
                   {Mac,App,Token,Body}->                                   
                                   case start_app(Mac,App,Token,Body) of
                                                  {0,Reply}->
                                                                  %% Hostinfo = {obj,[{result,"ok"},{mac,Mac},{app,App},{reply,Reply}]},      
                                                                  Json = "{\"ark\":0," ++ "\"mac\":" ++ integer_to_list(Mac) ++ ",\"app\":" ++ integer_to_list(App) ++ ",\"value\":" ++ util:tostring(Reply) ++ "}",
                                                                  mod_esi:deliver(SessionID, [ "Content-Type: application/json\r\n\r\n",Json]); 
                                                  {1,Reply}-> 
                                                                  %% Hostinfo = {obj,[{result,"ok"},{mac,Mac},{app,App},{reply,Reply}]},      
                                                                  %% nak指令
                                                                  Json = "{\"ark\":1," ++ "\"mac\":" ++ integer_to_list(Mac) ++ ",\"app\":" ++ integer_to_list(App) ++ ",\"value\":" ++ util:tostring(Reply) ++ "}",
                                                                  mod_esi:deliver(SessionID, [ "Content-Type: application/json\r\n\r\n",Json]);   
                                                  
									               {timeout,_} ->
													              %% Hostinfo = {obj,[{result,"ok"},{mac,Mac},{app,App},{reply,Reply}]},      
                                                                  %% nak指令
                                                                  Json = "{\"ark\":1," ++ "\"mac\":" ++ integer_to_list(Mac) ++ ",\"app\":" ++ integer_to_list(App) ++ ",\"value\":" ++ util:tostring(<<16#F2>>) ++ "}",
                                                                  mod_esi:deliver(SessionID, [ "Content-Type: application/json\r\n\r\n",Json]);   
                                                  
									               {_Other,_}->
                                                                   %%Hostinfo = {obj,[{result,"timeout"},{mac,Mac},{app,App},{reply,""}]},                                                               
                                                                   %%0x03表示结果是未知
													               Json = "{\"ark\":1," ++ "\"mac\":" ++ integer_to_list(Mac) ++ ",\"app\":" ++ integer_to_list(App) ++ ",\"value\":" ++ util:tostring(<<3:8>>) ++ "}",
                                                                   mod_esi:deliver(SessionID, [ "Content-Type: application/json\r\n\r\n",Json])
                                   
                                   end;
                            Other->
                                   loger_server:logger("Other info:~p",[Other]),
                                   %%Hostinfo = {obj,[{result,"exception"},{mac,""},{app,""},{value,"input json param exception"}]},      
                                   Json = "{\"ark\":1," ++ "\"mac\":" ++ integer_to_list(16#FFFFFFFFFFFF) ++ ",\"app\":" ++ integer_to_list(16#FF) ++ ",\"value\":" ++ util:tostring(<<4:8>>) ++ "}",
                                   %%0x04表示参数错误
								   mod_esi:deliver(SessionID, [ "Content-Type: application/json\r\n\r\n",Json])
  end.



%%【多帧 0x02】请求主机BIN文件0x02
start_app(Mac,16#02,_Token,_Body)->
   Pid = self(),
   RegName = util:register_name(mutil), 
   {ok,NewPid}  = mutilframe_cfg_sup:start_child({RegName,Pid,Mac}),
   
   receive
         {Ark,NewPid,2,ReplyInfo}->
                      {Ark,ReplyInfo} 
   after 10000 ->
         {timeout,"timeout"}
   end;


%%【多帧 0x03】请求主机状态文件0x03
start_app(Mac,16#03,_Token,_Body)->
   Pid = self(),
   RegName = util:register_name(mutil), 
   {ok,NewPid}  = mutilframe_status_sup:start_child({RegName,Pid,Mac}),
   
    receive
         {Ark,NewPid,3,ReplyInfo}->
                      {Ark,ReplyInfo} 
    after 10000 ->
         {timeout,"timeout"}
    end;


%%【多帧 0x60】云端操作场景：增加、删除、修改：0x60,返回Crc
%%根据数据 的长度采用单帧模式或者多帧模式
start_app(Mac,16#60,_Token,Body)->
	App = 16#60,
	Webpid = self(),
	case size(Body) =< 546 of
		             false->                                              
						    RegName = util:register_name(mutil),
						    {ok,NewPid}  = mutilframe_scenecontrol_sup:start_child({RegName,Webpid,Mac,Body,0}),
						   
						    receive
						         {Ark,NewPid,App,ReplyInfo}->
						                      {Ark,ReplyInfo} 
						    after 10000 ->
						         {timeout,"timeout"}
						    end;
                      true->
							 RegName = util:register_name(single),
							 {ok,NewPid} = singleframe_app_sup:start_child({RegName,Webpid,Mac,App,Body}),
							 receive
							        {Ark,NewPid,App,ReplyInfo}->
							                      {Ark,ReplyInfo} 
							 after 10000 ->
							         {timeout,"timeout"}
							 end
    end;
                             


%%【多帧 0x61】云端写主机场景0x61,返回Crc
start_app(Mac,16#61,_Token,Body)->
	%%取出校验码
	<<Crc:4,Body_retain/binary>> = Body,
    %%测试代码，将文件保存在本地                                                      
    Webpid = self(),
    RegName = util:register_name(mutil),
   {ok,NewPid}  = mutilframe_scenedown_sup:start_child({RegName,Webpid,Mac,Body_retain,Crc}),
   
    receive
         {Ark,NewPid,16#61,ReplyInfo}->
                      {Ark,ReplyInfo} 
    after 10000 ->
         {timeout,"timeout"}
    end;


%%【多帧 0x62】云端读主机场景0x62
start_app(Mac,16#62,_Token,_Body)->
   Pid = self(),
   RegName = util:register_name(mutil), 
   {ok,NewPid}  = mutilframe_sceneup_sup:start_child({RegName,Pid,Mac}),
   
    receive
         {Ark,NewPid,16#62,ReplyInfo}->
                      {Ark,ReplyInfo} 
    after 10000 ->
         {timeout,"timeout"}
    end;


%%【多帧 0x14】升级主机固件版本0x14
start_app(Mac,16#14,_Token,Body)->                                          
    Webpid = self(),
    RegName = util:register_name(mutil),
    {ok,NewPid}  = mutilframe_version_sup:start_child({RegName,Webpid,Mac,Body,10}),
    receive
         {Ark,NewPid,16#14,ReplyInfo}->
                      {Ark,ReplyInfo} 
    after 10000 ->
         {timeout,"timeout"}
    end;
 
%%=========================================【单帧】处理查询主机状态=========================
%%==================================================================================
%%【单帧】查询主机状态
start_app(Mac,16#F4,Token,Body)->
   Reply = resovle_F4(Body),
   {0,Reply};


%%=========================================【多帧】处理查询主机状态=========================
%%==================================================================================
start_app(Mac,App,Token,Body)->
   Pid = self(),
   RegName = util:register_name(single),
   {ok,NewPid} = singleframe_app_sup:start_child({RegName,Pid,Mac,App,Body}),
   receive
         {Ark,NewPid,App,ReplyInfo}->
                      {Ark,ReplyInfo} 
   after 10000 ->
         {timeout,"timeout"}
   end.


%%处理规约指令0xF4,应答为Body内容
resovle_F4(<<>>)->
  <<0>>;
resovle_F4(<<Total:8,Bin/binary>>)->
	%%保证长度够
	case size(Bin) >= Total*6 of
	                      true->
	                         Body =  get_device_status(Total,Bin),
	                         list_to_binary([<<Total:8>>,Body]);
	                      false->
	                         loger_server:logger(">>step:false"),
	                         <<0>>
	end;
resovle_F4(_Other)->
  <<0>>.
	


get_device_status(0,_client)->
	<<>>;
get_device_status(Total,<<Mac:48,Client/binary>>)->
  Self = format(Mac),
  Client_result = get_device_status(Total-1,Client),
  list_to_binary([Self,Client_result]).


%%设备类型：1
%%在线状态 (1 Bytes)//0：离线，1：在线
%%Token (4字节)
%%Cfg Versiong(4个字节)
%%Sence Version(4个字节)
%%Name(32个字节)
format(Mac)->
	case db_server:select({controller_status,Mac}) of
		     {controller_status,_Srcmac,Status,Devicetype,Name,Cfgver,Scenever,_Softver,Token}->
                        list_to_binary([<<Mac:48,Devicetype:8,Status:8,Token:32,Cfgver:32,Scenever:32>>,Name]);
               undefined->
				        <<Mac:48,0:8,0:8,0:32,0:32,0:32,0:256>>
	end.