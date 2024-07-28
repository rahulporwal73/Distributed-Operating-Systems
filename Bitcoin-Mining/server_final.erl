-module(server_final).
-import(string,[substr/3]).
-export([start_server/1,printstr/0, servermining/2, localactor/2,bossactor/2,clienthandler/1,printtime/0]).


%% Server Mining is will generate random strings, hashes and  does Pattern matching. It sends the value to Print Actor.
servermining(0,_) ->

  ok;

servermining(Count, Y ) ->

  Mainstringlocal = ["rahulporwal"]++[io_lib:format("~2.16.0B", [X]) || <<X>> <= crypto:strong_rand_bytes(18) ],

  Hash1 = io_lib:format("~64.16.0b~n", [binary:decode_unsigned(crypto:hash(sha256, [Mainstringlocal]))]),
  Zero = "0000000000000",
  Zero1 = substr(Zero,1,Y),
  Str2 = substr(Hash1,1,Y),
  if
    Str2 == Zero1 ->
      printstr ! {print,Mainstringlocal, Hash1};

    true -> ok
  end,

  servermining( Count-1 , Y).

%%Printstr spawn will Print the Mined Value sent by either the local miners or client miners.
printstr()->
  receive
    {print,Printvalue, Hashvalue}->
      io:format("~s\t~s~n",[Printvalue,Hashvalue]),
      printstr()
  end.


%%CLienthandler will generate strings and send it to client.
clienthandler(N) ->

  Mainstring1 = ["p.kothari"]++[io_lib:format("~2.16.0B", [X]) || <<X>> <= crypto:strong_rand_bytes(18) ],

  receive
    finished ->

      io:format("ClientSide finished~n", []);

    {client,  Client_PID} ->
      Client_PID ! {clienthandler, Mainstring1,N},
      clienthandler(N)
  end.

%%Local Actor will spawn actors depending upon the core size and leading no. of zeros requested.
localactor(0,_)->

  {_, Time1} = statistics(runtime),   %CPU time
  U1 = Time1,
  {_, Time2} = statistics(wall_clock),    %Real time
  U2 = Time2,


  if
    U2 =/= 0  ->
      Ratio = U1/U2,
      io:format("CPU time: ~p\t Real Time: ~p\n",[U1, U2]),
  io:format("Ratio (CPU:Real): ~p\n",[Ratio]);

    true -> ok

      end,
  io:format("~n", []);

localactor(Nactors,N)->
  servermining(N*500,N),
  localactor(Nactors-1, N).

%%Prints Status Time
printtime() ->
  receive
    statusprint ->
      {_, Time1} = statistics(runtime),   %CPU time
      U1 = Time1,
      {_, Time2} = statistics(wall_clock),    %Real time
      U2 = Time2,


      if
        U2 =/= 0  ->
          Ratio = U1/U2,
          io:format("CPU time: ~p\t Real Time: ~p\n",[U1, U2]),
          io:format("Ratio (CPU:Real): ~p\n",[Ratio]);

        true -> ok

      end,
      printtime()
  end.


%% Bossactor spawns the local actors depending upon the number of cores.
bossactor(0,_)->
  ok;

bossactor( Count,N)->
  Cores=erlang:system_info(logical_processors_online),
  Nactors=Cores*2,
  spawn(server_final, localactor, [Nactors,N]),
  bossactor( Count-1,N).




%%Start server intiates the program.
start_server(N) ->

  statistics(runtime),
  statistics(wall_clock),
  spawn(server_final,bossactor,[100,N]),
  register(clienthandler, spawn(server_final, clienthandler, [N])),
  register(printtime, spawn(server_loop,printtime,[])),
  register(printstr, spawn(server_final, printstr,[])).
