-module(sendfunc).

-export([twttosvr/1,twtfrmusr/1,hashmaptweet/1,tweetbreaker/5,rectwtfrmuser/0,sendTweetAll/4]).



twtfrmusr(UserTwtMap)->
    receive
        {UserName,Tweet,Pid,RmtNode}->
            TwtLst=maps:find(UserName,UserTwtMap),
            if
              TwtLst==error->
                    Pid ! {"User Not present in Server Database",RmtNode},
                    twtfrmusr(UserTwtMap);
                true ->
                    {ok,Tweets}=TwtLst,
                    io:format("~s~n",[Tweet]),
                    io:format("~p~n",[Tweets]),
                    Tweets1=lists:append(Tweets,[Tweet]),
                    io:format("~p~n",[Tweets1]),
                    NewUserTwtMap=maps:put(UserName,Tweets1,UserTwtMap),
                    Pid ! {"Tweet Posted",RmtNode},
                    TweetSplitList=string:split(Tweet," ",all),
                    io:format("~p~n",[TweetSplitList]),
                    tweetbreaker(TweetSplitList,1,Tweet,UserName,"#"),
                    tweetbreaker(TweetSplitList,1,Tweet,UserName,"@"),
                    userfollower ! {UserName,self()},
                    receive
                        {Subscribers}->
                          io:format("Subscribers are ~p~n",[Subscribers]),
                          spawn(sendfunc,sendTweetAll,[Subscribers,1,Tweet,UserName])
                    end,                  
                    twtfrmusr(NewUserTwtMap)
            end;
         {UserName}->
            NewUserTweetMap=maps:put(UserName,[],UserTwtMap),
            twtfrmusr(NewUserTweetMap);
         {UserName,Pid,RmtNode}->
           TwtLst=maps:find(UserName,UserTwtMap),
            if
              TwtLst==error->
                    Pid ! {[],RmtNode};
                true ->
                    {ok,Tweets}=TwtLst,
                    io:format("length= ~p~n",[length(Tweets)]),
                    Pid ! {Tweets,RmtNode}
            end,
            twtfrmusr(UserTwtMap)
    end. 


hashmaptweet(HashTagTweetMap)->
   receive
    {HashTag,Tweet,UserName,addnewhashTag}->
        io:format("~s~n",[Tweet]),
      TwtLst=maps:find(HashTag,HashTagTweetMap),
        if
          TwtLst==error->
                NewHashTagTwtMap=maps:put(HashTag,[{Tweet,UserName}],HashTagTweetMap),
                hashmaptweet(NewHashTagTwtMap);
            true ->
                {ok,Tweets}=TwtLst,
                io:format("~p~n",[Tweets]),
                Tweets1=lists:append(Tweets,[{Tweet,UserName}]),
                io:format("~p~n",[Tweets1]),
                NewHashTagTwtMap=maps:put(HashTag,Tweets1,HashTagTweetMap),
                % io:format("~p",NewUserTweetMap),                
                hashmaptweet(NewHashTagTwtMap)
        end;
     {HashTag,Pid,RmtNode}->
       TwtLst=maps:find(HashTag,HashTagTweetMap),
        if
          TwtLst==error->
                Pid ! {[],RmtNode};
            true ->
                {ok,Tweets}=TwtLst,
                io:format("~p~n",[Tweets]),
                Pid ! {Tweets,RmtNode}
        end,
        hashmaptweet(HashTagTweetMap)
    end.
sendTweetAll(Subscribers,Id,Tweet,UserName)->
 if
   Id>length(Subscribers)->
            ok;
    true->
        {Username1,_}=lists:nth(Id,Subscribers),
        % io:format("~p~n",[Pid]),
        mapidproc!{Username1,Tweet},
        sendTweetAll(Subscribers,Id+1,Tweet,UserName)
 end.       

rectwtfrmuser()->
    receive
     {Message,UserName}->
        CurrentMessage=UserName++" : "++Message,
        io:format("~s~n",[CurrentMessage]),
        rectwtfrmuser()
    end.







tweetbreaker(BreakTweet,Id,Tweet,UserName,Tag)->
  if
    Id==length(BreakTweet)+1 ->
      ok;
    true ->
      CurStr=string:find(lists:nth(Id,BreakTweet),Tag,trailing),
      io:format("~s~n",[CurStr]),
      if
        CurStr==nomatch ->
          ok;
        true ->
          hashTagMap ! {CurStr,Tweet,UserName,addnewhashTag}
      end,
      tweetbreaker(BreakTweet,Id+1,Tweet,UserName,Tag)
  end.




twttosvr(Tweet)->
  try persistent_term:get("LoggedIn")
  catch
    error:X ->
      io:format("~p~n",[X])
  end,
  SignedIn=persistent_term:get("LoggedIn"),
  if
    SignedIn==true->
      RemoteServerId=persistent_term:get("ServerId"),
      RemoteServerId!{persistent_term:get("UserName"),Tweet,self(),tweet},
      receive
        {Registered}->
          io:format("~s~n",[Registered])
      end;
    true->
      io:format("You should sign in to send tweets Call main:signin_register() to complete signin~n")
  end.