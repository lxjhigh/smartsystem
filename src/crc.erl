%% @author liuxiaojun
%% @doc @todo Add description to crc.


-module(crc).

%% ====================================================================
%% API functions
%% ====================================================================
-export([crc16/1]).



%% ====================================================================
%% Internal functions
%% ====================================================================

crc16(Srclist)->
	getbyte(0,Srclist).

getbyte(Crc,<<>>)->
	Crc;

getbyte(Crc,<<Headbyte:8,Tail/binary>>)->
	Crc_compute = Crc bxor (Headbyte bsl 8),
	Newcrc = cycle_xor(Crc_compute,0),
	getbyte(Newcrc,Tail).
cycle_xor(Crc,N)->
	case N < 8 of
		false-> Crc;
		true ->
			 case Crc band 16#8000 of
				0->
					NewCrc = (Crc bsl 1) band 16#FFFF,
				 	cycle_xor(NewCrc,N+1);
				_other->
					NewCrc = ((Crc bsl 1) band 16#FFFF) bxor 16#1021,
					cycle_xor(NewCrc,N+1)
			 end  
	end.
							
			
