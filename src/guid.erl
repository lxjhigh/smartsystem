%% coding:Latin-1
%% @author liuxiaojun
-module(guid).
-export([get_guid/0,get_app_id/0]).


%%获取应用进程ID,对应整型
get_app_id() ->
    Term = term_to_binary({node(), make_ref()}),
    Digest = erlang:md5(Term),
    <<Appid:32,_Other/binary>> = Digest,
    Appid. 

get_guid() ->
    Term = term_to_binary({node(), make_ref()}),
    Digest = erlang:md5(Term),
    binary_to_hex(Digest).
    

binary_to_hex(Bin) when is_binary(Bin) ->
    [oct_to_hex(N) || <<N:4>> <= Bin].

oct_to_hex(0) -> $0;
oct_to_hex(1) -> $1;
oct_to_hex(2) -> $2;
oct_to_hex(3) -> $3;
oct_to_hex(4) -> $4;
oct_to_hex(5) -> $5;
oct_to_hex(6) -> $6;
oct_to_hex(7) -> $7;
oct_to_hex(8) -> $8;
oct_to_hex(9) -> $9;
oct_to_hex(10) -> $a;
oct_to_hex(11) -> $b;
oct_to_hex(12) -> $c;
oct_to_hex(13) -> $d;
oct_to_hex(14) -> $e;
oct_to_hex(15) -> $f.