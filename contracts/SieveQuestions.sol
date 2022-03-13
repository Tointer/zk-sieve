//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;

// We import this library to be able to use console.log
import "hardhat/console.sol";
import "./Verifier.sol";
import "./NFTGame.sol";

// This is the main building block for smart contracts.
contract SieveQuestions {
    Question[] rankedQuestions;
    Question[] public allQuestions;
    mapping (address => uint) pendingQuestions;
    uint8 targetWinrate;
    Verifier verifier;
    NFTGame nftGame;

    constructor(address verifierAddress, address nftGameAddress) public {
        verifier = Verifier(verifierAddress);
        nftGame = NFTGame(nftGameAddress);
    }


    function getQuestion() public returns (bytes32 ipfsLink, bytes32 answerHash, uint id){
        uint length = rankedQuestions.length;
        uint randomIndex = 12 % length; //it's gonna be random and distributed in gaussian way

        ipfsLink = rankedQuestions[randomIndex].ipfsQuestionHash;
        answerHash = rankedQuestions[randomIndex].answerHash;
        id = rankedQuestions[randomIndex].id;

        rankedQuestions[randomIndex].askedTimes++;
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
            uint[2] memory c) public returns (bool correct){

        uint id = pendingQuestions[msg.sender];
        correct = verifier.verifyProof(a, b, c, [uint(allQuestions[id].answerHash)]);

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

    function addQuestion(bytes32 ipfsHash, bytes32 answerHash) public {
        uint128 rank = uint128(rankedQuestions.length);
        rankedQuestions.push(Question(ipfsHash, answerHash, 0, 0, rank, rank));
    }

    function delta(uint a, uint b) private pure returns(uint){
        return a > b? a - b : b - a;
    }
}

struct Question{
    bytes32 ipfsQuestionHash;
    bytes32 answerHash;
    uint128 askedTimes;
    uint128 correctAnswerTimes;
    uint128 id;
    uint128 rank;
}
