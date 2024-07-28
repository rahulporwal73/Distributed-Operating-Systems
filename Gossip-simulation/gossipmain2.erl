%%%-------------------------------------------------------------------
%%% @author Rahul Porwal
%%% @copyright (C) 2022, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 04. Oct 2022 15:31
%%%-------------------------------------------------------------------
-module(gossipmain2).
-author("Rahul Porwal").
-export([start/3,createnodes_gossip/2,supervisor/3,worker/1,create_dict_line_top/2,termination_line2d3d/1,termination/1,create_pushsum_nodes/2,worker_pushsum/3,create_2d_top_map/3,create_dict_2d_top/4,create_dict_3d_top/5]).
-import(rand,[uniform/1]).
-import(math,[pow/2,sqrt/1]).
-import(lists,[append/2,merge/1,delete/2]).
-import(proplists,[append_values/2]).


%%Terminates the process for Full topology
termination(Starting_time) ->
  receive
    {endfullgossipprocess,NodePid,Nodelist,Rumour} ->
     %% io:format("Node Terminated: ~p~n",[NodePid]),
      New_Nodelist = lists:delete(NodePid,Nodelist),
      if
        length(New_Nodelist)>1 ->
          Random_node = lists:nth(rand:uniform(length(New_Nodelist)), New_Nodelist),
          Random_node ! {fullgossip,Rumour,New_Nodelist};
        true ->
          Ending_time = erlang:monotonic_time()/10000,
          Running_time = Ending_time - Starting_time,
          io:format("Node Terminated: ~p~n",[NodePid]),
          io:format("total time: ~f milliseconds~n", [Running_time]),
          io:format("Convergence Achieved~n"),

          erlang:halt()
      end;
    {endfullpushsumprocess,NodePid,Nodelist} ->
     %% io:format("Node Terminated: ~p~n",[NodePid]),
      New_Nodelist = lists:delete(NodePid,Nodelist),
      if
        length(New_Nodelist)>1 ->
          Random_node = lists:nth(rand:uniform(length(New_Nodelist)), New_Nodelist),
          Random_node ! {fullpushsum,0,1,New_Nodelist};
        true ->
          Ending_time = erlang:monotonic_time()/10000,
          Running_time = Ending_time - Starting_time,
          io:format("Node Terminated: ~p~n",[NodePid]),
          io:format("total time: ~f milliseconds~n", [Running_time]),
          io:format("Convergence Achieved~n"),
          erlang:halt()
      end
  end,
  termination(Starting_time).

%%Terminates the process for Line,2D,3D topology
termination_line2d3d(Starting_time) ->
  receive
    {done,NodePid} ->
      Ending_time = erlang:monotonic_time()/10000,
      Running_time = Ending_time - Starting_time,
      io:format("Node Terminated: ~p~n",[NodePid]),
      io:format("total time: ~f milliseconds~n", [Running_time]),
      io:format("Convergence Achieved~n"),
      erlang:halt()
  end,
  termination_line2d3d(Starting_time).


%%Worker Actor Creates and Maintains the working for gossip topology.
worker(Rounds_gossip)->
  receive
    {fullgossip,Rumour,Nodelist}->
      io:format("Node: ~p ------- Count : ~p~n",[self(),Rounds_gossip]),
      io:format("Rumour is : ~s~n",[Rumour]),
      if
        Rounds_gossip == 0 ->
          termination ! {endfullgossipprocess,self(),Nodelist,Rumour};
        true ->
          Node_to_send_list = lists:delete(self(),Nodelist),
         %% io:format("Node list~n"),
         %% io:format("~w~n",[Nodelist]),
%%          io:format("Node to send list~n"),
%%          io:format("~w~n",[Node_to_send_list]),
          Node_to_send = lists:nth(rand:uniform(length(Node_to_send_list)), Node_to_send_list), %changed rand:uniform(N) to length(Node_to_send_list)
          io:format("Node to send..... ~n"),
          io:format("~p~n",[Node_to_send]),
          Node_to_send ! {fullgossip,Rumour,Nodelist}
      end,
      worker(Rounds_gossip-1);
    {line2d3dgossip,Rumour,NodeMap,Nlist}->

      if
        Rounds_gossip =< 0 ->
          Nlist_new = lists:delete(self(),Nlist),
          Node_to_send_list = maps:get(self(),NodeMap),
          Node_to_send = lists:nth(rand:uniform(length(Node_to_send_list)), Node_to_send_list),

          if
            length(Nlist_new)>1 -> Node_to_send ! {line2d3dgossip,Rumour,NodeMap,Nlist_new};
            true ->
              termination_line2d3d!{done,self()}
          end;

        true ->
          io:format("worker message received at node~n"),
          io:format("~p~n",[self()]),
          io:format("Rumour message is: ~n"),
          io:format("~s~n",[Rumour]),
          Node_to_send_list = maps:get(self(),NodeMap),
%%          io:format("Node to send list~n"),
%%          io:format("~w~n",[Node_to_send_list]),
          Node_to_send = lists:nth(rand:uniform(length(Node_to_send_list)), Node_to_send_list),
          io:format("Node to send..... ~n"),
          io:format("~p~n",[Node_to_send]),
          Node_to_send ! {line2d3dgossip,Rumour,NodeMap,Nlist}
          end,
      worker(Rounds_gossip-1)

  end.



worker_pushsum(S,W, Rounds_pushsum) ->
  receive
    {fullpushsum,S_rec,W_rec,PS_Nodelist}->

      S_new = (S+S_rec)/2,
      W_new = (W+W_rec)/2,
      Ratio = abs((S_new/W_new) - (S/W)),

      if
        Rounds_pushsum == 0 -> termination ! {endfullpushsumprocess, self(),PS_Nodelist};
        true ->
          io:format("Node: ~p ------------ SW Ratio: ~p~n",[self(),Ratio]),
          Node_to_send_list = lists:delete(self(),PS_Nodelist),
          Node_to_send = lists:nth(rand:uniform(length(Node_to_send_list)), Node_to_send_list),
          io:format("Node to send..... ~n"),
          io:format("~p~n",[Node_to_send]),
          Node_to_send ! {fullpushsum,S_new,W_new,PS_Nodelist}
      end,
      if
        Ratio < 0.0000000001 ->
          worker_pushsum(S_new,W_new,Rounds_pushsum - 1);
        true ->
          worker_pushsum(S_new,W_new,3)
      end;

    {line2d3dpushsum,S_rec,W_rec,PS_NodeMap,Nlist}->
      io:format("worker message received at node~n"),
      io:format("~p~n",[self()]),
      S_new = (S+S_rec)/2,
      W_new = (W+W_rec)/2,
      Ratio = abs((S_new/W_new) - (S/W)),
      if
        Rounds_pushsum =< 0 ->
          Nlist_new = lists:delete(self(),Nlist),

          Node_to_send_list = maps:get(self(),PS_NodeMap),

          Node_to_send = lists:nth(rand:uniform(length(Node_to_send_list)), Node_to_send_list),

          if
            length(Nlist_new)>1 ->

              Node_to_send ! {line2d3dpushsum,S_new,W_new,PS_NodeMap,Nlist_new};
            true ->
              termination_line2d3d ! {done,self()}
          end;
        true ->
          io:format("Node: ~p~nSW Ratio: ~p~n",[self(),Ratio]),
          Node_to_send_list = maps:get(self(),PS_NodeMap),
%%          io:format("Node to send list~n"),
%%          io:format("~w~n",[Node_to_send_list]),
          Node_to_send = lists:nth(rand:uniform(length(Node_to_send_list)), Node_to_send_list),
          io:format("Node to send..... ~n"),
          io:format("~p~n",[Node_to_send]),
          Node_to_send ! {line2d3dpushsum,S_new,W_new,PS_NodeMap,Nlist}
      end,
      if
        Ratio < 0.0000000001 ->
          worker_pushsum(S_new,W_new,Rounds_pushsum - 1);
        true ->
          worker_pushsum(S_new,W_new,3)
      end
  end.


%%%%Creates Maps to associate Nodes to the neighbours for pushsum Alogrithm.

create_pushsum_nodes(0,_) -> [];
create_pushsum_nodes(S,Rounds) when S > 0 ->
  W = 1,
  NodePID = spawn(fun() -> worker_pushsum(S,W,Rounds) end),
  %%io:format("created worker ~p~n",[NodePID]),
  create_pushsum_nodes(S-1,Rounds) ++ [NodePID].


%%%%Creates Maps to associate Nodes to the neighbours for Gossip Alogrithm.

createnodes_gossip( 0,_ ) -> [];
createnodes_gossip( N,Rounds) when N > 0 ->
  NodePID = spawn(fun() -> worker(Rounds) end),
  io:format("created worker ~p~n",[NodePID]),
  createnodes_gossip( N-1,Rounds) ++ [NodePID].


%%%%Creates Maps to associate Nodes to the neighbours for Line topolgy.

create_dict_line_top(0,_) -> [];
create_dict_line_top(Nnodes,Nodelist)
  when Nnodes > 0 ->
  Key = lists:nth(Nnodes,Nodelist),
  if
    Nnodes == length(Nodelist) ->
      create_dict_line_top(Nnodes-1,Nodelist) ++ [{Key,[lists:nth(Nnodes-1,Nodelist)]}];

    Nnodes == 1 ->
      create_dict_line_top(Nnodes-1,Nodelist) ++ [{Key,[lists:nth(Nnodes+1,Nodelist)]}];

    true ->
      create_dict_line_top(Nnodes-1,Nodelist) ++ [{Key,[lists:nth(Nnodes-1,Nodelist),lists:nth(Nnodes+1,Nodelist)]}]
  end.


%%%%Creates Maps to associate Nodes to the neighbours for 2D topolgy.

create_dict_2d_top(_,_,0,_)->[];
create_dict_2d_top(IJ_values_list,IJ_values_map,Nnodes,Gsize) when Nnodes > 0 ->
  Key_IJ_Node_Pair = lists:nth(Nnodes,IJ_values_list),
  Key_IJ_Node_Pair_List = tuple_to_list(Key_IJ_Node_Pair),
  Key_Node = lists:nth(2,Key_IJ_Node_Pair_List),
  Key_IJ = lists:nth(1,Key_IJ_Node_Pair_List),
  IJ_list = tuple_to_list(Key_IJ),
  I = lists:nth(1,IJ_list),
  J = lists:nth(2,IJ_list),
  if
    J + 1 =< Gsize ->
      N1 = maps:get({I,J+1},IJ_values_map);
    true ->
      N1 =[]
  end,
  if
    J - 1 > 0 ->
      N2 = maps:get({I,J-1},IJ_values_map);
    true ->
      N2 =[]
  end,
  if
    I + 1 =< Gsize ->
      N3 = maps:get({I+1,J},IJ_values_map);
    true ->
      N3 =[]
  end,
  if
    I - 1 > 0 ->
      N4 = maps:get({I-1,J},IJ_values_map);
    true ->
      N4 =[]
  end,
  Neighbours_temp = [N1,N2,N3,N4],
  Neighbours = lists:filter(fun(X)->X/=[] end,Neighbours_temp),
  create_dict_2d_top(IJ_values_list,IJ_values_map,Nnodes-1,Gsize) ++ [{Key_Node,Neighbours}].




%%%%Creates Maps to associate Nodes to the neighbours for 3D topolgy.
create_dict_3d_top(_,_,0,_,_)->[];
create_dict_3d_top(IJK_values_list,IJK_values_map,Nnodes,Gsize,Nodelist) when Nnodes > 0 ->
  Key_IJK_Node_Pair = lists:nth(Nnodes,IJK_values_list),
  Key_IJK_Node_Pair_List = tuple_to_list(Key_IJK_Node_Pair),
  Key_Node = lists:nth(2,Key_IJK_Node_Pair_List),
  Key_IJK = lists:nth(1,Key_IJK_Node_Pair_List),
  IJK_list = tuple_to_list(Key_IJK),
  K = lists:nth(1,IJK_list),
  I = lists:nth(2,IJK_list),
  J = lists:nth(3,IJK_list),
  if
    J + 1 =< Gsize ->
      N1 = maps:get({K,I,J+1},IJK_values_map);
    true ->
      N1 =[]
  end,
  if
    J - 1 > 0 ->
      N2 = maps:get({K,I,J-1},IJK_values_map);
    true ->
      N2 =[]
  end,
  if
    I + 1 =< Gsize ->
      N3 = maps:get({K,I+1,J},IJK_values_map);
    true ->
      N3 =[]
  end,
  if
    I - 1 > 0 ->
      N4 = maps:get({K,I-1,J},IJK_values_map);
    true ->
      N4 =[]
  end,

  if
    (I + 1 =< Gsize) and (J + 1 =< Gsize) ->
      N5 = maps:get({K,I+1,J+1},IJK_values_map);
    true ->
      N5 =[]
  end,
  if
    (I + 1 =< Gsize) and (J - 1 > 0) ->
      N6 = maps:get({K,I+1,J-1},IJK_values_map);
    true ->
      N6 =[]
  end,
  if
    (I - 1 > 0) and (J + 1 =< Gsize) ->
      N7 = maps:get({K,I-1,J+1},IJK_values_map);
    true ->
      N7 =[]
  end,
  if
    (I - 1 > 0) and (J - 1 > 0) ->
      N8 = maps:get({K,I-1,J-1},IJK_values_map);
    true ->
      N8 =[]
  end,

  %Nodelist_Random_tmp = lists:delete(self(),Nodelist),
  Nodelist_Random = Nodelist -- [N1,N2,N3,N4,N5,N6,N7,N8,Key_Node],
  Random_node = lists:nth(rand:uniform(length(Nodelist_Random)), Nodelist_Random),
  Neighbours_temp = [N1,N2,N3,N4,N5,N6,N7,N8,Random_node],
  Neighbours = lists:filter(fun(X)->X/=[] end,Neighbours_temp),
  create_dict_3d_top(IJK_values_list,IJK_values_map,Nnodes-1,Gsize,Nodelist) ++ [{Key_Node,Neighbours}].





%%Creates Maps to associate IJ/IJK values to the nodes. Created Maps for Both 2D and imp3D topology
create_2d_top_map(_,_,0) -> [];
create_2d_top_map(IJ_list,Nodelist,Nnodes) when Nnodes>0 ->
  IJ_val = lists:nth(Nnodes,IJ_list),
  Node_val = lists:nth(Nnodes,Nodelist),
  create_2d_top_map(IJ_list,Nodelist,Nnodes-1) ++ [{IJ_val,Node_val}].

%%Supervisor Function controls the working of all the algorithms


supervisor(N,Topology,Algorithm)->
  Rounds_gossip = 5,
  Rounds_pushsum = 3,

  if N > 1 ->
    case Topology of
      top_2D ->
        io:format("Running 2D topology~n"),
        Totalnodes=trunc(pow(ceil(sqrt(N)),2)),
        Gsize = trunc(sqrt(Totalnodes)),
        I_list = lists:seq(1,Gsize),
        J_list = lists:seq(1,Gsize),
        IJ_list = [{I,J}||I<-I_list,J<-J_list],
        %IJ_indexed_list = lists:enumerate(IJ_list),


        case Algorithm of
          gossip->
            io:format("running gossip~n"),
            Nodelist = createnodes_gossip(Totalnodes,Rounds_gossip),
%%            io:format("~w~n",[Nodelist]),
            IJ_node_values = create_2d_top_map(IJ_list,Nodelist,Totalnodes),
           %% io:format("2D topology node map~n"),
            IJ_values_map = maps:from_list(IJ_node_values),
            %%io:format("~p~n",[IJ_values_map]),
            NeighbourList_2d=create_dict_2d_top(IJ_node_values,IJ_values_map,Totalnodes,Gsize),
            Neighboursmap_2d=maps:from_list(NeighbourList_2d),
            io:format("2D topology Neighbours Map~n"),
            io:fwrite("~p~n",[Neighboursmap_2d]),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Nodelist),
            io:format("starting node :~n"),
            io:format("~p~n",[Randomnode]),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination_line2d3d,spawn(gossipmain2,termination_line2d3d,[Starting_time])),
            Randomnode ! {line2d3dgossip,"Rumour",Neighboursmap_2d,Nodelist};
          pushsum->
            io:format("running pushsum~n"),
            Pushsum_Nodelist = create_pushsum_nodes(Totalnodes,Rounds_pushsum),
%%            io:format("~w~n",[Pushsum_Nodelist]),
            IJ_node_values = create_2d_top_map(IJ_list,Pushsum_Nodelist,Totalnodes),
            io:format("2D topology node map~n"),
            IJ_values_map = maps:from_list(IJ_node_values),
            io:format("~p~n",[IJ_values_map]),
            NeighbourList_2d=create_dict_2d_top(IJ_node_values,IJ_values_map,Totalnodes,Gsize),
            Neighboursmap_2d=maps:from_list(NeighbourList_2d),
            io:format("2D topology Neighbours Map~n"),
            io:fwrite("~p~n",[Neighboursmap_2d]),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Pushsum_Nodelist),
            io:format("starting node :~n"),
            io:format("~p~n",[Randomnode]),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination_line2d3d,spawn(gossipmain2,termination_line2d3d,[Starting_time])),
            Randomnode ! {line2d3dpushsum,0,1,Neighboursmap_2d,Pushsum_Nodelist}

        end;
      line ->
        Totalnodes=N,

        case Algorithm of
          gossip ->
            io:format("running gossip~n"),
            Nodelist = createnodes_gossip(Totalnodes,Rounds_gossip),
%%            io:format("~w~n",[Nodelist]),
            NeighborsList = create_dict_line_top(Totalnodes,Nodelist),
            NeighborsMap = maps:from_list(NeighborsList),
            io:fwrite("~p~n",[NeighborsMap]),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Nodelist),
            io:format("starting node :~n"),
            io:format("~p~n",[Randomnode]),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination_line2d3d,spawn(gossipmain2,termination_line2d3d,[Starting_time])),
            Randomnode ! {line2d3dgossip,"Rumour",NeighborsMap,Nodelist};
          pushsum ->
            io:format("running pushsum~n"),
            Pushsum_Nodelist = create_pushsum_nodes(Totalnodes,Rounds_pushsum),
%%            io:format("~w~n",[Pushsum_Nodelist]),
            NeighborsList = create_dict_line_top(Totalnodes,Pushsum_Nodelist),
            NeighborsMap = maps:from_list(NeighborsList),
            io:fwrite("~p~n",[NeighborsMap]),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Pushsum_Nodelist),
            io:format("starting node :~n"),
            io:format("~p~n",[Randomnode]),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination_line2d3d,spawn(gossipmain2,termination_line2d3d,[Starting_time])),
            Randomnode ! {line2d3dpushsum,0,1,NeighborsMap,Pushsum_Nodelist};


          (_)->
            io:format("no such algorithm~n")

        end;

      full->
        Totalnodes=N,

        %io:format("~w~n",[Nodelist]),

        case Algorithm of
          gossip ->
            io:format("running gossip~n"),
            Nodelist = createnodes_gossip(Totalnodes,Rounds_gossip),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Nodelist),
            %io:format("Random node~n"),
            %io:format("~p~n",[Randomnode]),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination,spawn(gossipmain2,termination,[Starting_time])),
            Randomnode ! {fullgossip,"Rumour",Nodelist};
          pushsum ->
            io:format("running pushsum~n"),
            Pushsum_Nodelist = create_pushsum_nodes(Totalnodes,Rounds_pushsum),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Pushsum_Nodelist),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination,spawn(gossipmain2,termination,[Starting_time])),
            Randomnode ! {fullpushsum,0,1,Pushsum_Nodelist};

          (_)->
            io:format("no such algorithm~n")

        end;



      imp3D->
        Totalnodes=trunc(pow(ceil(pow(N,1/3)),3)),
        Gsize = trunc(round(pow(Totalnodes,1/3))),
        I_list = lists:seq(1,Gsize),
        J_list = lists:seq(1,Gsize),
        K_list = lists:seq(1,Gsize),
        IJK_list = [{K,I,J}||I<-I_list,J<-J_list,K<-K_list],
        %IJ_indexed_list = lists:enumerate(IJ_list),


        case Algorithm of
          gossip->
            io:format("running gossip~n"),
            Nodelist = createnodes_gossip(Totalnodes,Rounds_gossip),
            io:format("~w~n",[Nodelist]),
            IJK_node_values = create_2d_top_map(IJK_list,Nodelist,Totalnodes),
            io:format("topology node map~n"),
            IJK_values_map = maps:from_list(IJK_node_values),
            io:format("~p~n",[IJK_values_map]),
            NeighbourList_3d=create_dict_3d_top(IJK_node_values,IJK_values_map,Totalnodes,Gsize,Nodelist),
            Neighboursmap_3d=maps:from_list(NeighbourList_3d),
            io:format("3D topology Neighbours Map~n"),
            io:fwrite("~p~n",[Neighboursmap_3d]),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Nodelist),
            io:format("starting node :~n"),
            io:format("~p~n",[Randomnode]),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination_line2d3d,spawn(gossipmain2,termination_line2d3d,[Starting_time])),

            Randomnode ! {line2d3dgossip,"Rumour",Neighboursmap_3d,Nodelist};
          pushsum->
            io:format("running pushsum~n"),
            Pushsum_Nodelist = create_pushsum_nodes(Totalnodes,Rounds_pushsum),
            io:format("~w~n",[Pushsum_Nodelist]),
            IJK_node_values = create_2d_top_map(IJK_list,Pushsum_Nodelist,Totalnodes),
            io:format("3D topology node map~n"),
            IJK_values_map = maps:from_list(IJK_node_values),
            io:format("~p~n",[IJK_values_map]),
            NeighbourList_3d=create_dict_3d_top(IJK_node_values,IJK_values_map,Totalnodes,Gsize,Pushsum_Nodelist),
            Neighboursmap_3d=maps:from_list(NeighbourList_3d),
            io:format("3D topology Neighbours Map~n"),
            io:fwrite("~p~n",[Neighboursmap_3d]),
            Randomnode = lists:nth(rand:uniform(Totalnodes), Pushsum_Nodelist),
            io:format("starting node :~n"),
            io:format("~p~n",[Randomnode]),
            Starting_time = erlang:monotonic_time()/10000,
            register(termination_line2d3d,spawn(gossipmain2,termination_line2d3d,[Starting_time])),
            Randomnode ! {line2d3dpushsum,0,1,Neighboursmap_3d,Pushsum_Nodelist}

        end;
      (_)->
        io:format("no such topology~n")

    end;
    true->
      io:format("Less than 2 nodes~n")
  end.


%% Start function where we will spawn the supervisor. We give Number of nodes, Topology and Alogirthm as input
start(N,Topology,Algorithm)->
  io:format("Supervisor actor ~p~n",[spawn(fun() -> supervisor(N,Topology,Algorithm) end)]).








