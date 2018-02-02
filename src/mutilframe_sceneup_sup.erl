%% @author liuheliang
%% @doc @todo Add description to mutilframe_sceneup_sup.


-module(mutilframe_sceneup_sup).

-export([start_link/0,start_child/1]).
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, temporary, brutal_kill, Type, [I]}).


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
   Children = [
		     				?CHILD(mutilframe_sceneup,worker)
              ],
   RestartStategy = {simple_one_for_one,0,1},
   {ok,{RestartStategy,Children}}.

