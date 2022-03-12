//SPDX-License-Identifier: UNLICENSED

// Solidity files have to start with this pragma.
// It will be used by the Solidity compiler to validate its version.
pragma solidity ^0.8.0;

// We import this library to be able to use console.log
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

// This is the main building block for smart contracts.
contract NFTGame {

    Participant firstParticipant;
    Participant secondParticipant;

    mapping (address => Lobby) public lobbyByFirstPlayer;
    Participant waitingParticipant;

    function getNFTHash(address collectionAddress, uint id) private pure returns(uint){
        return uint(keccak256(abi.encode(collectionAddress, id)));
    }

    function register(address collectionAddress, uint id) public {
        if(waitingParticipant.owner == address(0)){
            waitingParticipant = Participant(id, msg.sender, collectionAddress);
            return;
        }

        lobbyByFirstPlayer[waitingParticipant.owner] = Lobby(waitingParticipant, Participant(id, msg.sender, collectionAddress));

        delete waitingParticipant;
    }

    function startFight(address firstPlayerAdress, bool firstPlayerAnsweredRight, bool secondPlayerAnsweredRight) public {
        uint firstAdvantage = firstPlayerAnsweredRight? 33: 0;
        uint secondAdvantage = secondPlayerAnsweredRight? 33: 0;

        Lobby memory lobby = lobbyByFirstPlayer[firstPlayerAdress];
        uint firstHash = getNFTHash(lobby.firstParticipant.nftAddress, lobby.firstParticipant.nftId);
        uint secondHash = getNFTHash(lobby.secondParticipant.nftAddress, lobby.secondParticipant.nftId);
        bool firstPlayerWon = simulateFight(firstHash, secondHash, firstAdvantage, secondAdvantage);

        if(firstPlayerWon){
            firstPlayerWon= firstPlayerWon;
            //rewardFirstPlayer
        }
        else{
            firstPlayerWon = firstPlayerWon;
            //reward second player
        }

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
}

struct Lobby{
    Participant firstParticipant;
    Participant secondParticipant;
}