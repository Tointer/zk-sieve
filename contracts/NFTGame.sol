//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;

// We import this library to be able to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./Governable.sol";
import "./SieveQuestions.sol";

// This is the main building block for smart contracts.
contract NFTGame is Governable {

    Participant firstParticipant;
    Participant secondParticipant;

    mapping (address => Lobby) public lobbyByFirstPlayer;
    mapping (address => address) public firstPlayerBySecondPlayer;
    Participant waitingParticipant;
    SieveQuestions sieve;

    function getNFTHash(address collectionAddress, uint id) private pure returns(uint){
        return uint(keccak256(abi.encode(collectionAddress, id)));
    }

    function register(address collectionAddress, uint id, address sieveAddress) public {
        if(waitingParticipant.owner == address(0)){
            waitingParticipant = Participant(id, msg.sender, collectionAddress, QuestionState.Waiting);
            return;
        }

       (bytes32 ipfsLink, bytes32 answerHash, uint questionId) = SieveQuestions(sieveAddress).getQuestion();
        lobbyByFirstPlayer[waitingParticipant.owner] = Lobby(waitingParticipant, Participant(id, msg.sender, collectionAddress, QuestionState.Waiting), questionId);
        firstPlayerBySecondPlayer[msg.sender] = waitingParticipant.owner;


        delete waitingParticipant;
    }

    function setQuestionAnswered(address playerAddress, bool answered) public onlyGovernance returns(bool fightHappened, address winningAddress){
        address firstPlayerAddress;

        if(lobbyByFirstPlayer[playerAddress].firstParticipant.owner != address(0)){
            firstPlayerAddress = playerAddress;
            lobbyByFirstPlayer[firstPlayerAddress].firstParticipant.questionState = answered? QuestionState.AnsweredRight: QuestionState.AnsweredWrong;
        }
        else if(lobbyByFirstPlayer[firstPlayerBySecondPlayer[playerAddress]].secondParticipant.owner != address(0)){
            firstPlayerAddress = firstPlayerBySecondPlayer[playerAddress];
            lobbyByFirstPlayer[firstPlayerAddress].secondParticipant.questionState = answered? QuestionState.AnsweredRight: QuestionState.AnsweredWrong;
        }
        else {
            revert();
        }

        QuestionState firstPlayerQuestion = lobbyByFirstPlayer[playerAddress].firstParticipant.questionState;
        QuestionState secondPlayerQuestion = lobbyByFirstPlayer[playerAddress].secondParticipant.questionState;

        if(firstPlayerQuestion != QuestionState.Waiting && secondPlayerQuestion!= QuestionState.Waiting ){
            fightHappened = true;
            winningAddress = startFight(firstPlayerAddress, 
            firstPlayerQuestion == QuestionState.AnsweredRight,
            secondPlayerQuestion == QuestionState.AnsweredRight);
        }
    }

    function startFight(address firstPlayerAdress, bool firstPlayerAnsweredRight, bool secondPlayerAnsweredRight) private returns(address){
        uint firstAdvantage = firstPlayerAnsweredRight? 33: 0;
        uint secondAdvantage = secondPlayerAnsweredRight? 33: 0;

        Lobby memory lobby = lobbyByFirstPlayer[firstPlayerAdress];
        uint firstHash = getNFTHash(lobby.firstParticipant.nftAddress, lobby.firstParticipant.nftId);
        uint secondHash = getNFTHash(lobby.secondParticipant.nftAddress, lobby.secondParticipant.nftId);
        bool firstPlayerWon = simulateFight(firstHash, secondHash, firstAdvantage, secondAdvantage);

        if(firstPlayerWon){
            return firstPlayerAdress;
        }
        else{
            return lobby.secondParticipant.owner;
        }

        delete firstPlayerBySecondPlayer[lobbyByFirstPlayer[firstPlayerAdress].secondParticipant.owner];
        delete lobbyByFirstPlayer[firstPlayerAdress];
    }

    function simulateFight(uint firstHash, uint secondHash, uint firstAdvantagePercents, uint secondAdvantagePercents) private pure returns(bool firstPlayerWin){
        (uint8 firstMelee, uint8 firstRanged, uint8 firstSpeed, uint8 firstHealth) = getStatsOfNFT(firstHash, firstAdvantagePercents);
        (uint8 secondMelee, uint8 secondRanged, uint8 secondSpeed, uint8 secondHealth) = getStatsOfNFT(secondHash, secondAdvantagePercents);

        //ranged turn
        if(firstSpeed > secondSpeed)
            secondHealth -= firstRanged;
        else
            firstHealth -= secondRanged;

        if(firstHealth <= 0) return false;
        if(secondHealth <= 0) return true;

        if(firstSpeed > secondSpeed)
            firstHealth -= secondRanged;
        else
            secondHealth -= firstRanged;

        if(firstHealth <= 0) return false;
        if(secondHealth <= 0) return true;

        //melee turn
        if(firstSpeed >= secondSpeed)
            secondHealth -= firstMelee;
        else
            firstHealth -= secondMelee;

        if(firstHealth <= 0) return false;
        if(secondHealth <= 0) return true;

        if(firstSpeed > secondSpeed)
            firstHealth -= secondMelee;
        else
            secondHealth -= firstMelee;

        if(firstHealth <= 0) return false;
        if(secondHealth <= 0) return true;

        return firstHealth > secondHealth;
    }

    function getStatsOfNFT(address collectionAddress, uint id, uint advantagePercents) public pure returns (uint8 meleeAttack, uint8 rangedAttack, uint8 speed, uint8 health){
        return getStatsOfNFT(getNFTHash(collectionAddress, id), advantagePercents);
    }

    function getStatsOfNFT(uint seed, uint advantagePercents) public pure returns (uint8 meleeAttack, uint8 rangedAttack, uint8 speed, uint8 health){
        meleeAttack = uint8(popcnt(seed, 64) * ((100 + advantagePercents)/100));
        seed >>= 64;
        rangedAttack = uint8(popcnt(seed, 64) * ((100 + advantagePercents)/100))/2;
        seed >>= 64;
        speed = uint8(popcnt(seed, 64) * ((100 + advantagePercents)/100));
        seed >>= 64;
        health = uint8(popcnt(seed, 64) * ((100 + advantagePercents)/100));
    }


    function popcnt(uint256 input, uint count) internal pure returns (uint256) {
        uint256 result = 0;
        uint256 tmp_mask = input;
        for (uint256 i = 0; i < 256 && i < count; ++i) {
            if (1 == tmp_mask & 1) {
                result++;
            }
            tmp_mask >>= 1;
        }

        assert(0 == tmp_mask);
        return result;
    }

}

struct Stats{
    uint8 meleeAttack;
    uint8 rangedAttack;
    uint8 speed;
    uint8 health;
}

struct Participant{
    uint nftId;
    address owner;
    address nftAddress;
    QuestionState questionState;
}

struct Lobby{
    Participant firstParticipant;
    Participant secondParticipant;
    uint questionId;
}

enum QuestionState{Waiting, AnsweredWrong, AnsweredRight}