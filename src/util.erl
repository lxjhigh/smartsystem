%% coding:Latin-1
%% @author liuxiaojun

-module(util).
-export[register_name/1,time_data/0,time_sec/0,get_env/3,get_param/1].
-export[test/0].
-export[tostring/1].

test()->
   error_logger:info_msg("test:~p~n",[ut]).
   
   
tostring(Bin)->
    case binary_to_list(Bin)  of
                     [] ->
                        "[]";
                     [First|[]]->
                         "[" ++ integer_to_list(First) ++ "]";
                     [First|Last]->
                         Laststr = [ "," ++ integer_to_list(X) || X <- Last],
                         Res = lists:concat(Laststr),
                         "[" ++ integer_to_list(First) ++ Res ++ "]"
    end.
                                           
%%--------------------------------------------------------------------
%% 
%% @doc 在线监控设备
%%--------------------------------------------------------------------
 


%%多帧下载注册名
register_name(mutil)->
   list_to_atom("mutil_" ++ guid:get_guid());
%%单帧下载注册名
register_name(single)->
   list_to_atom("single_" ++ guid:get_guid());
register_name(Mac)->
   Mac_str = integer_to_list(Mac,16),
   %%App = guid:get_app_id(),
   %%App_str = integer_to_list(App,16),
   list_to_atom("r_" ++ Mac_str).
   

time_data()->
	 {{Year,Month,Day},{Hour,Min,Sec}} = calendar:local_time(),
	 Week = calendar:day_of_the_week(Year,Month,Day),
	 NewYear = Year rem 2000,
	 <<NewYear:8,Month:8,Day:8,Hour:8,Min:8,Sec:8,Week:8>>.
	
time_sec()->
	 calendar:datetime_to_gregorian_seconds(calendar:local_time()).
	 

get_env(Appname,Key,Defaultvalue)->
	case application:get_env(Appname,Key) of
	     {ok,Value}->
	           Value;
	     _Ohter->
	           Defaultvalue
	end.
	

get_param(HttpData)->
		case json_util:decode(HttpData) of
		     {ok,{obj,JsonResult},_Other}->
		                           {Result_mac,Mac}    = find_key_value("mac",JsonResult),
		                           %%loger_server:logger("decode mac result:~p   value:~p",[Result_Mac,Mac]),
		                           {Result_app,App}    = find_key_value("app",JsonResult),
		                           %%loger_server:logger("decode app result:~p   value:~p",[Result_App,App]),
		                           {Result_value,Value}  = find_key_value("value",JsonResult), 
								   {Result_token,Token}  = find_key_value("token",JsonResult),
		                           %%loger_server:logger("decode body result:~p   value:~p",[Result_Body,Body]),
		                           case (Result_mac =:= ok) and (Result_app =:= ok) and (Result_value =:= ok) and (Result_token =:= ok) of
		                                                                        true->
		                                                                              {Mac,App,Token,list_to_binary(Value)};
		                                                                        false->
		                                                                               false
		                            end;
		                    _Other->
		                            %%loger_server:logger("decode error:~p",[_Other]),
		                            false
		end.


find_key_value(Key,List)->
        case lists:keyfind(Key,1,List) of
                  {_K,V}->
                       {ok,V};
                  false->
                       {fail,false}
        end.