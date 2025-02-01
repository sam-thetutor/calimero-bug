import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Hash "mo:base/Hash";
import Nat "mo:base/Nat";
import Result "mo:base/Result";
import Array "mo:base/Array";
actor class Backend() = this {

    type Task = {
        prompt : Text;
        to : Principal;
        from : Principal;
        callbackId : Nat;
    };

    type Agent = {
        metadata : Text;
        Price : Nat;
        reputation : Nat;
    };


    type Response = {
        output : Text;
        from : Principal;
        callbackId : Nat;
    };


    // type Prices={
    //     token:Text;
    //     amount:Nat;
    // };

    stable var currentTaskId : Nat = 0;
    stable var Owner :Principal = Principal.fromText("2vxsx-fae");

    private stable var metadataArray : [(Principal, Agent)] = [];
    private var metadataHashMap = HashMap.fromIter<Principal, Agent>(
        Iter.fromArray(metadataArray),
        Iter.size(Iter.fromArray(metadataArray)),
        Principal.equal,
        Principal.hash,
    );

    var agentAddresses : [Principal] = [];

    private stable var tasksArray : [(Nat, Task)] = [];
    private var tasksHashMap = HashMap.fromIter<Nat, Task>(
        Iter.fromArray(tasksArray),
        Iter.size(Iter.fromArray(tasksArray)),
        Nat.equal,
        Hash.hash,
    );

    private stable var balanceArray : [(Principal, Nat)] = [];
    private var balanceHashMap = HashMap.fromIter<Principal, Nat>(
        Iter.fromArray(balanceArray),
        Iter.size(Iter.fromArray(balanceArray)),
        Principal.equal,
        Principal.hash,
    );

    //store the responses
    private stable var responsesArray : [(Nat, Response)] = [];
    private var responsesHashMap = HashMap.fromIter<Nat, Response>(
        Iter.fromArray(responsesArray),
        Iter.size(Iter.fromArray(responsesArray)),
        Nat.equal,
        Hash.hash,
    );



    //query the agent

    public shared ({ caller }) func queryAgent(prompt : Text, to : Principal, callbackId : Nat) : async Result.Result<Nat, Text> {
        //check if the agent exists
        assert(Owner == caller);

        switch (metadataHashMap.get(to)) {

            case (?agent) {

                //if the agent exists, get its price
                let price = agent.Price;

                //get the balance of the user
                let balance = getBalance(caller);
                if (balance < price) {
                    return #err("Insufficient balance");
                };

                //deduct the price from the user's balance
                let newBalance = balance - price;
                balanceHashMap.put(caller, newBalance);

                //update the balance of the to
                let newBalanceTo = getBalance(to);
                balanceHashMap.put(to, newBalanceTo + price);

                //add the task to the tasksHashMap
                tasksHashMap.put(currentTaskId, { prompt = prompt; to = to; from = caller; callbackId = callbackId });

                //increment the currentTaskId
                currentTaskId += 1;

                //return the currentTaskId
                return #ok(currentTaskId);
            };
            case (null) {
                return #err("Agent not found");
            };

        };

    };

    //respond to the task

    public shared({caller}) func respond(output:Text,taskId:Nat):async Result.Result<Text,Text>{

    //only the agent which was directed to respond to the task can respond
    switch(tasksHashMap.get(taskId)){
        case(null){
            return #err("Task not found");
        };
        case(?task){
            if(task.to != caller){
                return #err("You are not authorized to respond to this task");
            };

            //add the response to the responsesHashMap
            responsesHashMap.put(taskId, {output = output; from = caller; callbackId = task.callbackId});


            switch(metadataHashMap.get(task.to)){
                case(null){
                    return #err("Agent not found");
                };
                case(?agent){
                    let newReputation = agent.reputation + 1;
                    metadataHashMap.put(task.to, {agent with reputation = newReputation});
                };
            };
            //return the response
            return #ok(output);
        };
    };

    };


    //register the agent
    public shared({caller}) func registerAgent(metadata:Text,price:Nat):async Result.Result<Text,Text>{
        assert(Owner == caller);
        //check if the agent already exists
        switch(metadataHashMap.get(caller)){
            case(null){
                 metadataHashMap.put(caller, {metadata = metadata; Price = price; reputation = 0});
                return #ok("Agent registered");
            };
            case(?agent){
                return #err("Agent already exists");
            };
        };
    };

    //update the agent
    public shared({caller}) func updateAgent(metadata:Text):async Result.Result<Text,Text>{
        assert(Owner == caller);
        //check if the agent exists
        switch(metadataHashMap.get(caller)){
            case(null){
                return #err("Agent not found");
            };
            case(?agent){
                metadataHashMap.put(caller, {agent with metadata = metadata; reputation = 0});
                return #ok("Agent updated");
            };
        };
    };

    //get all the agents data
    public query func getAllAgentsData():async [(Principal, Agent)]{
        return Iter.toArray(metadataHashMap.entries());
    };

    //set the agent price 
    public shared({caller}) func setAgentPrice(price:Nat):async Result.Result<Text,Text>{
        assert(Owner == caller);
        //check if the agent exists
        switch(metadataHashMap.get(caller)){
            case(null){
                return #err("Agent not found");
            };
            case(?agent){
                metadataHashMap.put(caller, {agent with Price = price});
                return #ok("Agent price set");
            };
        };
    };

    //get the agent price
    public query func getAgentPrice(agent:Principal):async Nat{
        switch(metadataHashMap.get(agent)){
            case(null){
                return 0;
            };
            case(?agent){
                return agent.Price;
            };
        };
    };


















    //get user balance
    func getBalance(user : Principal) : Nat {
        switch (balanceHashMap.get(user)) {
            case (null) {
                return 0;
            };
            case (?balance) {
                return balance;
            };
        };
    };

    //return the current task id
    public query func getCurrentTaskId() : async Nat {
        return currentTaskId;
    };

    //get the task associated with the task id
    public query func getTask(taskId : Nat) : async ?Task {
        return tasksHashMap.get(taskId);
    };

};
