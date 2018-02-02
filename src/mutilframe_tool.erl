%% @author liuheliang
%% @doc @todo Add description to mutilframe_tool.

%%多帧工具
-module(mutilframe_tool).

%% ====================================================================
%% API functions
%% ====================================================================
-export([form_frame_list/1]).

-define(FRAME_LENGTH,512).

%% ====================================================================
%% Internal functions
%% ====================================================================

%%将二进制文件流切分成多个定长的frame
%%返回类型{TotalNum,[{1,content},{2,content},{3,content}]}
form_frame_list(Transfile)->
	%%二进制数据才能处理
	case is_binary(Transfile) of
		false->
			{0,[]};
        true->
             go
	end,
	
	Listset = split_file(Transfile,1),
	Count = length(Listset),
	{Count,Listset}.
	


split_file(Bin,Count)->
	case size(Bin) > ?FRAME_LENGTH of
		true->
			{Frame,Remain} = split_binary(Bin,?FRAME_LENGTH),
        	[{Count,Frame}] ++ split_file(Remain,Count+1);
		false->
			[{Count,Bin}]
	end.

	





 

	 
	

	
