-module(smartsystem_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type), {I, {I, start_link, []}, permanent, 5000, Type, [I]}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
   process_flag(trap_exit,true),
   Children = [
							?CHILD(udp_server,worker),
							?CHILD(db_server,worker),
							?CHILD(loger_server,worker), 
							?CHILD(inets_server,worker),
							?CHILD(controller_server_sup,worker),
							?CHILD(gate_server_sup,worker),
							?CHILD(mutilframe_cfg_sup,worker),
							?CHILD(mutilframe_status_sup,worker),
							?CHILD(mutilframe_sceneup_sup,worker),
							?CHILD(mutilframe_scenedown_sup,worker),
							?CHILD(mutilframe_scenecontrol_sup,worker),
							?CHILD(mutilframe_version_sup,worker),
							?CHILD(singleframe_app_sup,worker)
              ],
              
   RestartStategy = {one_for_one,3,10},
   {ok,{RestartStategy,Children}}.
              
              
