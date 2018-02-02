%% coding:Latin-1
%% @author liuxiaojun

-module(inets_server).
-behaviour(gen_server).
 
-include("smartsystem.hrl").
-export([start_link/0]).
-export([init/1,handle_call/3,handle_cast/2,handle_info/2,terminate/2,code_change/3]).

 

start_link()-> 
	gen_server:start_link({local,?MODULE}, ?MODULE, [],[]).


init([])->
  Port_str = util:get_env(?APPNAME,httport,"10"),
  %%io:format("http port:~p~n",[Port_str]),
  Port = list_to_integer(Port_str,10),
  inets:start(httpd, [
  {modules, [mod_alias,mod_auth,mod_esi,mod_actions,mod_cgi,mod_dir,mod_get,mod_head,mod_log,mod_disk_log]},
  {port,Port},
  {server_name,"service"},
  {server_root,"log"},
  {document_root,"www"},
  {erl_script_alias, {"/inets", [service]}},
  {error_log, "error.log"},
  {bind_address, any},
  {ipfamily, inet},
  {security_log, "security.log"},
  {transfer_log, "transfer.log"},
  {mime_types,[
      {"html","text/html"},
      {"css","text/css"},
      {"js","application/x-javascript"}
  ]}
 ]),
 {ok,state}.
	 
handle_call(Request,_From,State)->
	{reply, {unknown_call, Request}, State}.

handle_cast(_Oher,State)->
  {noreply,State}.
                              
handle_info(_Other,State) ->
	{noreply,State}.

terminate(_Reason,_State)->
	ok.

code_change(_OldVsn,State,_Extra)->
	{ok,State}.