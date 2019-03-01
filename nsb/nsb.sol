pragma solidity ^0.4.22;
contract NetworkStatusBlockChain {
    uint constant public MAX_OWNER_COUNT = 50;
    uint constant public MAX_VALUE_PROPOSAL_COUNT = 5;

    struct MelkeProof {
        // storage roothash
        bytes32 storagehash;
        // storaged key
        bytes32 key;
        // corresponding value
        bytes32 value;
    }
    
    struct Action {
        // Party a
        // address pa;
        // Party z
        // address pz;
        // signature
        string signature;
    }
    
    // The MelkeProofTree
    // keccak256(storagehash + key + value) maps to MelkeProof
    bytes32[] public waitingVerifyProof;

    // corresponding valid votes' number
    uint32[] public validCount;

    // corresponding votes' number
    uint32[] public votedCount;

    // remained verifying MelkeProofs range [votedPointer, waitingVerifyProof.length)
    uint32 votedPointer;

    // all the MelkeProofs on the contract
    mapping (bytes32 => MelkeProof) public MelkeProofTree;
    // if the MelkeProof Atte is valid, verifiedMelkeProof[Atte] == true
    mapping (bytes32 => bool) public verifiedMelkeProof;

    // The Net State BlockChain(NSB) contract is owned by multple entities to ensure security.
    mapping (address => bool) public isOwner;
    address[] public owners;

    // remained caught MelkeProofs range [ownersPointer, waitingVerifyProof.length)
    mapping(address => uint32) public ownersPointer;
    // remained verifying MelkeProofs by onwers range [onwersvotedPointer, waitingVerifyProof.length)
    mapping(address => uint32) public ownersVotedPointer;
    uint public requiredOwnerCount;
    uint public requiredValidVotesCount;
    
    // ActionTree (keccak256(Action) => Action)
    mapping (bytes32 => Action) public ActionTree;

    // Maps used for adding and removing owners.
    mapping (address => mapping (address => bool)) public addingOwnerProposal;
    mapping (address => mapping (address => bool)) public removingOwnerProposal;

    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner], "owner exists");
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "onwer does not exist");
        _;
    }

    event addingMelkeProof(bytes32, bytes32, bytes32);

    modifier validRequirement(uint ownerCount, uint _requiredOwner) {
        require(ownerCount < MAX_OWNER_COUNT, "too many owners");
        require(_requiredOwner <= ownerCount, "not enough owners");
        require(_requiredOwner != 0, "at least one positive voter");
        require(ownerCount != 0, "at least one owner");
        _;
    }

    modifier validMelkeProof(bytes32 storagehash, bytes32 key) {
        require(storagehash != 0, "invalid storagehash");
        require(key != 0, "invalid key");
        _;
    }
    modifier remainMelkeProof(uint curPointer) {
        require(curPointer < waitingVerifyProof.length, "no MelkeProof to fetch");
        _;
    }

    modifier validVote(address addr, uint curVotedPointer) {
        require(votedPointer <= curVotedPointer, "the MelkeProof is proved");
        require(curVotedPointer < ownersPointer[addr], "no MelkeProof to vote");
        require(waitingVerifyProof[curVotedPointer] != 0, "the MelkeProof is proved");
        _;
    }

    modifier validUpdate(uint curPointer) {
        require(curPointer < votedPointer, "Remain Proof to verify");
        _;
    }

    modifier validChange(address addr, uint changeNum) {
        require(ownersVotedPointer[addr] <= changeNum, "too small");
        require(changeNum < waitingVerifyProof.length, "too big");
        _;
    }

    // Remember to specify at least one address and set the _required as one.
    constructor (address[] _owners, uint _required)
        public
        validRequirement(_owners.length, _required)
    {
        for (uint i = 0; i<_owners.length; i++) {
            require(!isOwner[_owners[i]] && _owners[i] != 0, "owner exists or its address is invalid");
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        requiredOwnerCount = _required;
        requiredValidVotesCount = (requiredOwnerCount + 1) >> 1;
    }

    function addOwner(address _newOwner)
        public
        ownerExists(msg.sender)
        validRequirement(owners.length + 1, requiredOwnerCount)
    {
        require(_newOwner != 0, "invalid owner address");
        addingOwnerProposal[_newOwner][msg.sender] = true;

        //use a integer to count it?
        uint vote_count = 0;
        for (uint i = 0; i < owners.length; i++) {
            address owner = owners[i];
            if (addingOwnerProposal[_newOwner][owner] == true) {
                vote_count ++;
            }
        }

        // Adding owner proposal is approved.
        if (vote_count >= requiredOwnerCount) {
            owners.push(_newOwner);
            isOwner[_newOwner] = true;
        }
    }

    function removeOwner(address _removeOwner)
        public
        ownerExists(msg.sender)
        ownerExists(_removeOwner)
        validRequirement(owners.length - 1, requiredOwnerCount)
    {
        removingOwnerProposal[_removeOwner][msg.sender] = true;

        //use a integer to count it?
        uint vote_count = 0;
        for (uint i = 0; i < owners.length; i++) {
            address owner = owners[i];
            if (removingOwnerProposal[_removeOwner][owner] == true) {
                vote_count ++;
            }
        }

        // Removing owner proposal is approved.
        if (vote_count >= requiredOwnerCount) {
            isOwner[_removeOwner] = false;
            for (uint j = 0; j < owners.length; j++) {
                if (owners[j] == _removeOwner) {
                    owners[j] = owners[owners.length - 1];
                    break;
                }
            }
            owners.length -= 1;
        }
    }

    // change it to VES/DAPP/NSB user?
    function addMelkeProof(bytes32 storagehash, bytes32 key, bytes32 val)
        public
        ownerExists(msg.sender)
        validMelkeProof(storagehash, key)
    {
        MelkeProof memory toAdd = MelkeProof(storagehash, key, val);
        bytes32 keccakhash = keccak256(storagehash, key, val);
        
        require(MelkeProofTree[keccakhash].storagehash == bytes32(0), "already in MelkeProofTree");
        
        waitingVerifyProof.push(keccakhash);
        MelkeProofTree[keccakhash] = toAdd;
        validCount.length ++;
        votedCount.length ++;
        
        emit addingMelkeProof(storagehash, key, val);
    }

    function getMelkeProof()
        public
        ownerExists(msg.sender)
        remainMelkeProof(uint(ownersPointer[msg.sender]))
        returns (bytes32 s, bytes32 k, bytes32 v)
    {
        while(ownersPointer[msg.sender] < waitingVerifyProof.length &&
              waitingVerifyProof[ownersPointer[msg.sender]] == 0) {
            ownersPointer[msg.sender] ++;
        }
        MelkeProof storage toGet = MelkeProofTree[waitingVerifyProof[ownersPointer[msg.sender]]];
        ownersPointer[msg.sender] ++;
        s = toGet.storagehash;
        k = toGet.key;
        v = toGet.value;
    }
    function voteProof(bool validProof)
        public
        ownerExists(msg.sender)
        validVote(msg.sender, uint(ownersVotedPointer[msg.sender]))
    {
        uint32 curPointer = ownersVotedPointer[msg.sender];
        ownersVotedPointer[msg.sender] ++;
        if(validProof) {
            validCount[curPointer] ++;
        }
        votedCount[curPointer] ++;
        if (votedCount[curPointer] == requiredOwnerCount) {
            if (validCount[curPointer] >= requiredValidVotesCount) {
                verifiedMelkeProof[waitingVerifyProof[curPointer]] = true;
            } else {
                delete MelkeProofTree[waitingVerifyProof[curPointer]];
            }
            delete waitingVerifyProof[curPointer];
            delete validCount[curPointer];
            delete votedCount[curPointer];
        }
        while(votedPointer < waitingVerifyProof.length && 
            waitingVerifyProof[votedPointer] == 0)votedPointer ++;
    }
    
    function updateToLatestVote()
        public
        ownerExists(msg.sender)
        validUpdate(uint(ownersVotedPointer[msg.sender]))
    {
        ownersVotedPointer[msg.sender] = votedPointer;
        if(ownersPointer[msg.sender] < votedPointer) {
            ownersPointer[msg.sender] = votedPointer;
        }
    }

    function resetGetPointer(uint32 num)
        public
        ownerExists(msg.sender)
        validChange(msg.sender, num)
    {
        ownersPointer[msg.sender] = num;
    }

    function addAction(string signature)
        public
        ownerExists(msg.sender)
        returns (bytes32 keccakhash)
    {
        // require(pa != 0, "invalid pa address");
        // require(pz != 0, "invalid pz address");
        
        Action memory toAdd = Action(signature);
        keccakhash = keccak256(signature);
        
        ActionTree[keccakhash]= toAdd;
    }
    
    function getAction(bytes32 keccakhash)
        public
        view
        returns (string signature)
    {
        Action storage toGet = ActionTree[keccakhash];
        // pa = toGet.pa;
        // pz = toGet.pz;
        signature = toGet.signature;
    }
    
    //is it necessary?
    function reGetMelkeProof(bytes32 keccakhash)
        public
        view
        ownerExists(msg.sender)
        returns (bytes32 s, bytes32 k, bytes32 v)
    {
        // require(MelkeProofTree[keccakhash] != , "not exists");
        MelkeProof storage toGet = MelkeProofTree[keccakhash];
        s = toGet.storagehash;
        k = toGet.key;
        v = toGet.value;
    }

    function getOwnerCount()
        public
        view
        returns (uint)
    {
        return owners.length;
    }

    function isSenderAOwner()
        public
        view
        returns (bool)
    {
        return isOwner[msg.sender];
    }

    function getTobeVotes()
        public
        view
        ownerExists(msg.sender)
        returns (uint32)
    {
        return ownersVotedPointer[msg.sender];
    }
    
    function validMelkeProoforNot(bytes32 keccakhash)
        public
        view
        returns (bool)
    {
        return verifiedMelkeProof[keccakhash];
    }
    
    function getVaildMelkeProof(bytes32 keccakhash)
        public
        view
        returns (bytes32 s, bytes32 k, bytes32 v)
    {
        require(verifiedMelkeProof[keccakhash] == true, "invalid");
        MelkeProof storage toGet = MelkeProofTree[keccakhash];
        s = toGet.storagehash;
        k = toGet.key;
        v = toGet.value;
    }
}
