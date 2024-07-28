-module(client_final).
-import(string,[substr/3]).
-export([send_request/1,client/2]).
%%Client does string hashes and pattern matching.
client(0, Server_Node) ->
  {clienthandler, Server_Node} ! finished,

  io:format("client mining finished~n", []);

client(N, Server_Node) ->

  {clienthandler, Server_Node} ! {client,self()},
  receive
    {clienthandler,Mainstring, Nz} ->

      Hash = io_lib:format("~64.16.0b~n", [binary:decode_unsigned(crypto:hash(sha256, [Mainstring]))]),
      Zero = "000000000000",
      Zero1 = substr(Zero,1,Nz),
      Str2 = substr(Hash,1,Nz),
      if
        Str2 == Zero1 ->
          {printstr, Server_Node} ! {print, Mainstring,Hash};
        true -> ok
      end
  end,
  client(N-1, Server_Node).

%%Send_request pings the server to start mining.
send_request(Server_Node) ->
  Cores=erlang:system_info(logical_processors_online),
  Nactors=Cores*1000,
  spawn(client_final,client,[Nactors*10, Server_Node]).

