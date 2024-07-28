-module(main).

-export([signin_register/0,startengine/0,signinsystem/0,tweet/0,userlist/0,follow/0,signout/0,hashtag/1,retweet/1]).

signin_register()->
    io:format("~s~n",["Welcome TO WORLD'S BEST TWITTER BY PUJAN MUSK AND ELON PORWAL"]),
    {ok,[LogIn]}=io:fread("To LogIn, Press S!!! To Register, Press R","~ts"),
    if
        (LogIn=="S")->
            registerfunc:signInUser();
        true->
            registerfunc:userregistration()
    end.
tweet()->
    Twt1=io:get_line("Enter Your Tweet "),
    Twt=lists:nth(1,string:tokens(Twt1,"\n")),
    try sendfunc:twttosvr(Twt)
    catch 
    error:_ -> 
      io:format("User is not signed in~n")
    end.   

follow()->
    UserName_to_follow=io:get_line("Enter User You want to follow to"),
    UserName=lists:nth(1,string:tokens(UserName_to_follow,"\n")),
    registerfunc:userfollower(UserName).
signout()->
    registerfunc:signuserOut().

userlist()->

    spawn(register,userlist,[]).

startengine()->
    Twt1 = [{"Elon","musk"}],
    Twt2=[{"Rahulia",["I am the greatest"]}],
    Twt3=[{"I","Want internship for summer 2023 "}],
    Twt5=[{"Pujank",[]}],
    Twt4=[{"Pujan Kothari","Rahul Porwar"}],
    Map1 = maps:from_list(Twt1),
    Map2 = maps:from_list(Twt2),
    Map3= maps:from_list(Twt3),
    Map4=maps:from_list(Twt4),
    Map5=maps:from_list(Twt5),
    register(userregister,spawn(list_to_atom("centralserver@DESKTOP-CPC7PAK"),registerfunc,messageTorec,[Map1])),
    register(receiveTweet,spawn(list_to_atom("centralserver@DESKTOP-CPC7PAK"),sendfunc,twtfrmusr,[Map2])),
    register(hashTagMap,spawn(list_to_atom("centralserver@DESKTOP-CPC7PAK"),sendfunc,hashmaptweet,[Map3])),
    register(userfollower,spawn(list_to_atom("centralserver@DESKTOP-CPC7PAK"),registerfunc,mapofusers1,[Map4])),
    register(mapidproc,spawn(list_to_atom("centralserver@DESKTOP-CPC7PAK"),registerfunc,mapidproc,[Map5])).

signinsystem()->
    receive
    % for LogIn
        {UserName,Passwordproc,Pid}->
            userregister ! {UserName,Passwordproc,self(),Pid};
    % for registerfuncation
        {UserName,Pwd,Email,Pid,registerfunc}->
            userregister ! {UserName,Pwd,Email,self(),Pid};
        {UserName,Tweet,Pid,tweet}->
            receiveTweet !{UserName,Tweet,self(),Pid};
        {UserName,Pid}->
            if
                Pid==signOut->
                    [UserID1,RemoteNodePid]=UserName,
                    mapidproc!{UserID1,RemoteNodePid,self(),randomShitAgain};
                true->
                    receiveTweet !{UserName,self(),Pid}
            end;
        {Pid}->
            userregister ! {self(),Pid,"FOR BLUETICK PAY US 8$"};
        {UserName,CurrUserName,Pid,RcvPid}->
            userfollower ! {UserName,CurrUserName,RcvPid,self(),Pid}
    end,
    receive
        {Msg,Pid}->
            Pid ! {Msg},
            signinsystem()
    end.


hashtag(HashId)->
    io:format("~s~n",[HashId]),
    io:format("~s~n",["I love doing #DOSP project"]).

retweet(Name)->
    io:format("~s~n",[Name]),
    io:format("~s~n",["Tweet has been reTweeted"]).