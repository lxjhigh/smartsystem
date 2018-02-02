%% @author liuheliang
%% @doc @todo Add description to gate_server_sup.


-module(gate_server_sup).

%%监督模式
-behaviour(supervisor).


-export([start_link/0,start_child/1]).
-export([init/1]).
 


%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).


%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%参数传递为control_server
start_child(Arg)->
		supervisor:start_child(?MODULE,[Arg]).
		

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
   %%process_flag(trap_exit,true),
   Server = { gate_server,
	            { gate_server,start_link,[]},
	              temporary,
	              brutal_kill,
	              worker,
	             [gate_server]},
	 Children = [Server],
	 RestartStategy = {simple_one_for_one,0,1},
	 {ok,{RestartStategy,Children}}.

	 


