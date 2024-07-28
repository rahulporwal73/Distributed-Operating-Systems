-module(project3_chord).
-import(rand,[uniform/1]).
-import(math,[pow/2,sqrt/1]).
-import(proplists,[append_values/2]).
-import(lists,[append/2,merge/1,delete/2]).

-export([start_network/2,create_actor_servers/5,supervisor_worker/2,worker/5,find_suc_pre/4,start_worker_requests/10]).
start_network(Num_nodes, Num_requests) ->
  if
    Num_nodes < 2 ->
      io:format(" nodes are not sufficent~n");
    true ->
      Total_request_sent = Num_nodes * Num_requests,
      register(counter, spawn(fun() -> counter(0, Total_request_sent) end)),
      register(wait_for_exit, spawn(fun() -> wait_for_exit(Total_request_sent) end)),
      io:format("supervisor worker actor ~p~n",[spawn(fun() -> supervisor_worker(Num_nodes,Num_requests) end)])
  end.

supervisor_worker(Num_nodes,Num_requests)->
  M = 17,
  Ring_size = round(pow(2,M)),

  %Ring = create_ring(Ring_size,1),
  %random:seed(now()),
  Unsorted_NodeIDs = [rand:uniform(Ring_size) || _ <- lists:seq(1, Num_nodes)],
  %Unsorted_NodeIDs = [1, 8, 14, 21, 32, 38, 42, 48, 51, 56],
  NodeIDs = lists:sort(Unsorted_NodeIDs),
  Highest_node_list = lists:nth(length(NodeIDs),NodeIDs),
  %io:format("NodeIDs:   ~n ~p~n",[NodeIDs]),
  WorkertmpMap = create_actor_servers(Num_nodes, NodeIDs, Num_requests, M, Highest_node_list),
  Worker_Mapped = maps:from_list(WorkertmpMap),
  WorkerPIDs = maps:values(Worker_Mapped),

  io:format("Worker_Mapped: ~p~n", [Worker_Mapped]),

  create_worker_request(Num_requests, Worker_Mapped, M, WorkerPIDs).
create_actor_servers(0,_,_,_,_) -> [];
create_actor_servers( N,NodeIDs,Num_requests,M,Highest_node_list) when N > 0 ->
  NodeID = lists:nth(N,NodeIDs),
  Value = create_finger_table(NodeID, M, NodeIDs, Highest_node_list, M),
  Finger_table_map = maps:from_list(Value),
  io:format("Finger table is ~p~n", [Finger_table_map]),
  %register(NodeID,spawn(fun() -> worker(NodeIDs,NodeID,Num_requests,M,Finger_table_map) end)),
  Node_PID=spawn(fun() -> worker(NodeIDs,NodeID,Num_requests,M,Finger_table_map) end),
  %io:format("created worker ~p~n",[NodeID]),
  create_actor_servers(N-1,NodeIDs,Num_requests,M,Highest_node_list)++[{NodeID,Node_PID}].


create_finger_table(_, _, _, _, 0) ->
  [];

create_finger_table(NodeId, M, NodeIDs, Highest_node_list, Count) ->
  io:format("~p~n",[NodeIDs]),
  Number = (NodeId + round(math:pow(2, M-Count))) rem round(math:pow(2,M)),
  io:format("~p~n",[Number]),
  if(Number > Highest_node_list) ->
    [Head | _] = lists:filtermap(fun(Z) -> round(math:pow(2,M)) + Z - Number >= 0 end, NodeIDs),
    create_finger_table(NodeId, M, NodeIDs, Highest_node_list, Count-1) ++ [{M-Count, Head}];
    true ->
      case lists:member(Number, NodeIDs) of
        true -> create_finger_table(NodeId, M, NodeIDs, Highest_node_list, Count-1) ++ [{M-Count, Number}];
        false ->
          [Head | _] = lists:filtermap(fun(Z) -> Z - Number > 0 end, NodeIDs),
          create_finger_table(NodeId, M, NodeIDs, Highest_node_list, Count-1) ++ [{M-Count, Head}]
      end
  end.



worker(NodeIDs,NodeID,Num_requests,M,Finger_table_map)->
  receive
    {serversendrequest,Node_PIDMap,Random_in_Node}->

      io:format("Node server list is ~p~n",[Node_PIDMap]),

      Highest_node_list = lists:nth(length(NodeIDs),NodeIDs),
      Low_node_in_list = lists:nth(1,NodeIDs),
      start_worker_requests(NodeID, length(NodeIDs), Num_requests, M, Finger_table_map, NodeIDs, Low_node_in_list, Highest_node_list, Node_PIDMap,Random_in_Node),
      worker(NodeIDs,NodeID,Num_requests,M,Finger_table_map)
  end.




create_worker_request(0, _, _, _) ->
  ok;

create_worker_request(Num_requests, Worker_Mapped, M, WorkerPIDs) ->
  [Pid ! {serversendrequest, Worker_Mapped, rand:uniform(round(math:pow(2,M)))} || Pid <- WorkerPIDs],
  %1 sec delay timer
  create_worker_request(Num_requests-1, Worker_Mapped, M, WorkerPIDs).

find_suc_pre(NodeID, NodeIDs, Low_node_in_list, Highest_node_list) ->
  if
    NodeID == Highest_node_list ->
      Temp_var = lists:filtermap(fun(Z) -> Z < NodeID end, NodeIDs),
      Temp_var1 = lists:reverse(Temp_var),
      [Head| _] = Temp_var1,
      [Low_node_in_list, Head];

    NodeID == Low_node_in_list ->
      Temp_var = lists:filtermap( fun(Z) -> Z > NodeID end,NodeIDs),
      [Head | _] = Temp_var,
      [Head, Highest_node_list];

    true ->
      Temp_var = lists:filter( fun(Z) -> Z > NodeID end,NodeIDs),
      [Head | _] = Temp_var,
      Temp_var1 = lists:filtermap( fun(Z) -> Z < NodeID end,NodeIDs),
      Temp_var2 = lists:reverse(Temp_var1),
      [Head1| _] = Temp_var2,
      [Head, Head1]
  end.

%%start_worker_requests(_, _, 0, _, _, _, _, _, _)->
%%    io:format("Reached");
start_worker_requests(NodeID, NumNodes, NumRequests, M, Finger_table_map, NodeIDs, Low_node_in_list, Highest_node_list, Worker_Mapped, Lookup_key)->
  io:format("NodeId Reached is: ~p~n",[NodeID]),
  io:format("Finger Table Map is ~p~n",[Finger_table_map]),
%%# IO.inspect Finger_table_map, label: "Node #{NodeID}'s FT:"
%%# IO.inspect NodeIDs, label: "Node #{NodeID}'s LT:"
  [Successor, Predecessor] = find_suc_pre(NodeID, NodeIDs, Low_node_in_list, Highest_node_list),
%Lookup_key = rand:uniform(round(math:pow(2,M))),
%%# IO.puts "node: #{NodeID} -> random node: #{Lookup_key}"
  io:format("Lookup Key is: ~p~n", [Lookup_key]),
%%Range_at =
  if
    NodeID == Low_node_in_list ->
      if (Lookup_key > Highest_node_list) or (Lookup_key =< Low_node_in_list) ->
        Range_at=1;
        true->
          Range_at=0
      end;
    true ->
      if (Lookup_key > Predecessor )and (Lookup_key =< NodeID) ->
        Range_at=1;
        true->
          Range_at=0
      end
  end,
  if Range_at == 1->
%%# IO.puts "#{Lookup_key} is in range of #{NodeID}, sending done and starting a new request"
    %% get_value(NodeIDs) it will send Done to Master so that it waits for all nodes to send done
    wait_for_exit ! {exit},
    maps:get(NodeID, Worker_Mapped);
  %start_worker_requests(NodeID, NumNodes, NumRequests-1, M, Finger_table_map, NodeIDs, Low_node_in_list, Highest_node_list, Worker_Mapped);
    true->
      %%# IO.puts "#{Lookup_key} not in the range of node #{NodeID}"
%%node_pid =
      Values = maps:values(Finger_table_map),

      case lists:member(Lookup_key, Values) of
%# IO.puts "node #{Lookup_key} found in Finger_table_map for node #{NodeID}"
        true -> NodeId = maps:get(Lookup_key, Worker_Mapped);
        false ->
          case lists:any(fun(Z) -> Z < Lookup_key end, Values) and lists:any(fun(Z) -> Z > NodeID end, lists:filtermap(fun(Z) -> Z < Lookup_key end, NodeIDs)) of
            true ->
              Temp_var = lists:filtermap(fun(Z) -> Z - Lookup_key < 0 end, lists:sort(Values)),
              Temp_var1 = lists:reverse(Temp_var),
              [Head| _] = Temp_var1,
        NodeId = maps:get(Head, Worker_Mapped);
            false ->
              NodeId = maps:get(Successor, Worker_Mapped)
          end
      end,
      io:format("Lookup Key has been sent to successor node :~p~n",[ NodeId ]),
      counter ! {add_in},
      NodeId ! {serversendrequest,Worker_Mapped,Lookup_key}
  end.

counter(Count, Total_request_sent) ->
  receive
    {add_in} ->
      counter(Count + 1, Total_request_sent);
    {printAvg} ->
      Avg = Count/Total_request_sent,
      io:format("~n"),
      io:format("Avg Hop Count is : ~p~n",[Avg])
  end.

wait_for_exit(0) ->
  counter ! {printAvg},
  unregister(counter),
  unregister(wait_for_exit);

wait_for_exit(Total_request_sent) ->
  receive
    {exit} ->
      wait_for_exit(Total_request_sent - 1)
  end.

