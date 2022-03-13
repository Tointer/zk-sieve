//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;

// We import this library to be able to use console.log
import "hardhat/console.sol";
import "./Verifier.sol";
import "./NFTGame.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// This is the main building block for smart contracts.
contract SieveQuestions is VRFConsumerBase  {
    Question[] rankedQuestions;
    Question[] public allQuestions;
    mapping (address => uint) pendingQuestions;
    uint8 targetWinrate;
    Verifier verifier;
    NFTGame nftGame;

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public randomResult;

    constructor(address verifierAddress, address nftGameAddress) VRFConsumerBase(
            0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
            0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
        ) public {
        verifier = Verifier(verifierAddress);
        nftGame = NFTGame(nftGameAddress);

                keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
        fee = 0.1 * 10 ** 18;
    }

    function getQuestion() public returns (bytes32 ipfsLink, uint answerHash, uint id){
        uint length = rankedQuestions.length;
        getRandomNumber();
        uint randomIndex = randomResult % length; //TODO: change distribution from linear to gaussian way

        ipfsLink = rankedQuestions[randomIndex].ipfsQuestionHash;
        answerHash = rankedQuestions[randomIndex].answerHash;
        id = rankedQuestions[randomIndex].id;

        rankedQuestions[randomIndex].askedTimes++;
    }

    function getRandomNumber() public returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHash, fee);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        randomResult = randomness;
    }

    function moveQuestionLeft(uint id, uint amount) private {
        amount = amount > id? id: amount;
        for(uint i = 0; i < amount; i++){
            Question memory buffer = rankedQuestions[id-1-i];
            rankedQuestions[id-1-i] = rankedQuestions[id-i];
            rankedQuestions[id-i] = buffer;
        }
    }

    function moveQuestionRight(uint id, uint amount) private {
        amount = amount > rankedQuestions.length - id ? rankedQuestions.length - id: amount;
        for(uint i = 0; i < amount; i++){
            Question memory buffer = rankedQuestions[id+1+i];
            rankedQuestions[id+1+i] = rankedQuestions[id+i];
            rankedQuestions[id+i] = buffer;
        }
    }

    function answerQuestion(uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c, uint id) public returns (bool correct){

        correct = verifier.verifyProof(a, b, c, [(allQuestions[id].answerHash)]);

        nftGame.setQuestionAnswered(msg.sender, correct);

        if(correct){
            allQuestions[id].correctAnswerTimes++;
        }

        if(allQuestions[id].askedTimes > 10){
            uint newWinrate = (allQuestions[id].correctAnswerTimes*1000000)/allQuestions[id].askedTimes;
            uint delta = delta(newWinrate, 750000);
            if(delta < 50000){
                moveQuestionLeft(allQuestions[id].rank, 1);
            }
            else if(delta > 150000){
                moveQuestionRight(allQuestions[id].rank, 1);
            }
        }

        delete pendingQuestions[msg.sender];
    }

    function addQuestion(bytes32 ipfsHash, uint answerHash) public {
        uint128 rank = uint128(rankedQuestions.length);
        rankedQuestions.push(Question(ipfsHash, answerHash, 0, 0, rank, rank));
        allQuestions.push(Question(ipfsHash, answerHash, 0, 0, rank, rank));
    }

    function delta(uint a, uint b) private pure returns(uint){
        return a > b? a - b : b - a;
    }
}

struct Question{
    bytes32 ipfsQuestionHash;
    uint answerHash;
    uint128 askedTimes;
    uint128 correctAnswerTimes;
    uint128 id;
    uint128 rank;
}
