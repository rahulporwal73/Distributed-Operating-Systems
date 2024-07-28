-module(registerfunc).

-export([userregistration/0,messageTorec/1,signInUser/0,userlist/0,mapofusers1/1,userfollower/1,mapidproc/1
,signuserOut/0]).

messageTorec(UserPwdMap)->
    receive

        {UserName,Passwd,_,Pid,RemoteNodePid}->
            User=maps:find(UserName,UserPwdMap),
            if
                User==error->
                    NewUserMap=maps:put(UserName,Passwd,UserPwdMap),
                    receiveTweet ! {UserName},
                    Pid ! {"Registered",RemoteNodePid},
                    messageTorec(NewUserMap);
                true ->
                    Pid ! {"Error 404, Try again after sometime",RemoteNodePid},
                    messageTorec(UserPwdMap)
            end;
        {UserName,Passwordproc,Pid,RemoteNodePid}->
            UserPassword=maps:find(UserName,UserPwdMap),
            [Pass,Process]=Passwordproc,
            ListPasswd={ok,Pass},
            if
                UserPassword==ListPasswd->
                   mapidproc!{UserName,Process,"Pay us"},
                   Pid ! {"Signed In",RemoteNodePid};
                true ->
                    Pid ! {"Wrong UserName or Password entered",RemoteNodePid}
            end,
            messageTorec(UserPwdMap);
        {UserName,Pid}->
            User=maps:find(UserName,UserPwdMap),
            if
                User==error->
                    Pid ! {"ok"};
                true ->
                    Pid ! {"not ok"}
            end,
            messageTorec(UserPwdMap);
        {Pid,RemoteNodePid,_}->
            UserList=maps:to_list(UserPwdMap),
            Pid ! {UserList,RemoteNodePid},
            messageTorec(UserPwdMap)
    end.
signInUser()->
    {ok,[UserName]}=io:fread("Enter Username","~ts"),
    {ok,[Passwd]}=io:fread("Enter Password","~ts"),
    SvrConnect_Id=spawn(list_to_atom("centralserver@DESKTOP-CPC7PAK"),main,signinsystem,[]),
    persistent_term:put("ServerId", SvrConnect_Id),
    register(rectwtfrmuser,spawn(sendfunc,rectwtfrmuser,[])),

    SvrConnect_Id!{UserName,[Passwd,whereis(rectwtfrmuser)],self()},
    receive
        {Registered}->
            if
                Registered=="Signed In"->
                    persistent_term:put("UserName",UserName),
                    persistent_term:put("LoggedIn",true);
                true->
                    persistent_term:put("LoggedIn",false)
            end,
            io:format("~s~n",[Registered])  
    end.

userlist()->
    LoggedIn=persistent_term:get("LoggedIn"),
    if
        LoggedIn==true->
            RmtSvrId=persistent_term:get("ServerId"),
            RmtSvrId!{self()},
            receive
                {UserList}->
                    
                    printuserlist(UserList,1)
            end;
        true->
            io:format("Pls signin to send tweets, Call main:signin_register() to signin~n")
    end.

mapofusers1(UserSubscriberMap)->
    receive
    {UserName,CurrentUserName,CurrentUserPid,Pid,RemoteNodePid}->
        ListSubscribers=maps:find(UserName,UserSubscriberMap),
        if
            ListSubscribers==error->
                NewUserSubscriberMap=maps:put(UserName,[{CurrentUserName,CurrentUserPid}],UserSubscriberMap),
                Pid ! {"followed",RemoteNodePid},
                mapofusers1(NewUserSubscriberMap);
            true ->
                {ok,Subscribers}=ListSubscribers,
                io:format("~p~n",[Subscribers]),
                Subscribers1=lists:append(Subscribers,[{CurrentUserName,CurrentUserPid}]),
                io:format("UserName ~p ~p~n",[UserName,Subscribers1]),
                NewUserSubscriberMap=maps:put(UserName,Subscribers1,UserSubscriberMap),
                % io:format("~p",NewUserTweetMap),
                Pid ! {"Subscribed",RemoteNodePid},                
                mapofusers1(NewUserSubscriberMap)
        end;
    {UserName,Pid}->
        ListSubscribers=maps:find(UserName,UserSubscriberMap),
        if
            ListSubscribers==error->
                Pid !{[]};
            true->
                {ok,Subscribers}=ListSubscribers,
                Pid ! {Subscribers}     
        end,         
        mapofusers1(UserSubscriberMap)
    end.   

printuserlist(UserList,Srno)->
    if
        Srno>length(UserList)->
            ok;
        true->
            {UserName,_}=lists:nth(Srno,UserList),
            io:format("~s~n",[UserName]),
            printuserlist(UserList,Srno+1)
    end.
userfollower(UserName)->
    LoggedIn=persistent_term:get("LoggedIn"),
    if
        LoggedIn==true->
            RmtSvrId=persistent_term:get("ServerId"),
            RmtSvrId!{UserName,persistent_term:get("UserName"),self(),whereis(rectwtfrmuser)},
            receive
                {Registered}->
                    io:format("~p~n",[Registered])  
            end;
        true->
            io:format("You should sign in to send tweets Call main:signin_register() to complete signin~n")
    end.
mapidproc(UserProcessIdMap)->
    receive
    {UserName,CurrentUserPid,_}->
        NewUserProcessIdMap=maps:put(UserName,CurrentUserPid,UserProcessIdMap),  
        io:format("~p~n",[NewUserProcessIdMap]),              
        mapidproc(NewUserProcessIdMap);
    {UserName,RemoteNodePid,Pid,_}->
        ListSubscribers=maps:find(UserName,UserProcessIdMap),
        if
            ListSubscribers==error->
                Pid ! {"",RemoteNodePid},
                mapidproc(UserProcessIdMap);
            true ->
                NewUserProcessIdMap=maps:remove(UserName,UserProcessIdMap),  
                Pid ! {"SignedOut",RemoteNodePid},    

                mapidproc(NewUserProcessIdMap)
        end;  
    {UserName,Tweet}->
        ListSubscribers=maps:find(UserName,UserProcessIdMap),
        if
            ListSubscribers==error->
                ok;
            true->
                {ok,ProcessId}=ListSubscribers,
                ProcessId ! {Tweet,UserName}   
        end,         
        mapidproc(UserProcessIdMap)
    end.  
signuserOut()->
    LoggedIn=persistent_term:get("LoggedIn"),
    if
        LoggedIn==true->
            RmtSvrId=persistent_term:get("ServerId"),
            RmtSvrId!{[persistent_term:get("UserName"),self()],signOut},
            receive
                {Registered}->
                    persistent_term:erase("UserName"),
                    io:format("~s~n",[Registered])  
            end;
        true->
            io:format("You should sign in to send tweets Call main:signin_register() to complete signin~n")
    end.


userregistration()->
    {ok,[UserId]}=io:fread("Enter your Username","~ts"),
    {ok,[Passwd]}=io:fread("Enter your Password","~ts"),
    {ok,[Email]}=io:fread("Enter your Email","~ts"),
    SvrConnect_Id=spawn(list_to_atom("centralserver@DESKTOP-CPC7PAK"),main,signinsystem,[]),
    SvrConnect_Id ! {UserId,Passwd,Email,self(),registerfunc},
    receive
        {Registered}->
            io:format("~s~n",[Registered])
    end.







