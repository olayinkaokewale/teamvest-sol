//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../TeamVest.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract TeamVestMock is TeamVest {
    using SafeMath for uint256;

    constructor() {

    }

    function withdrawVest(uint256 _tokenId, uint timeNow) external ownerIsTeamMember(_tokenId) {
        require(tokenIdToVestData[_tokenId].amountLocked > tokenIdToVestData[_tokenId].amountCollected, "TEAMVEST: you have withdrawn all amounts");
        // 1. Calculate the amount per seconds and other neccessary things
        uint vestExpiryTime = tokenIdToVestData[_tokenId].lockTimestamp + tokenIdToVestData[_tokenId].totalVestingTime;
        uint256 amountPerSeconds = (tokenIdToVestData[_tokenId].amountLocked).div(tokenIdToVestData[_tokenId].totalVestingTime); //z
        uint minimumWithdrawalTime = tokenIdToVestData[_tokenId].totalVestingTime / tokenIdToVestData[_tokenId].totalVestingInterval; //y
        // 2. Set the elapse time and check if possible to withdraw
        uint elapsedTime; //x
        uint256 amountToWithdraw;
        if (timeNow < vestExpiryTime) {
            elapsedTime = timeNow - tokenIdToVestData[_tokenId].lastCollectedTimestamp;
            require(elapsedTime >= minimumWithdrawalTime, "TEAMVEST: you can not withdraw at this time");
            // 3. Get the amount to withdraw and check if it is lower than the total amount
            amountToWithdraw = amountPerSeconds.mul(elapsedTime);
        } else {
            elapsedTime = vestExpiryTime - tokenIdToVestData[_tokenId].lastCollectedTimestamp;
            amountToWithdraw = tokenIdToVestData[_tokenId].amountLocked - tokenIdToVestData[_tokenId].amountCollected;
        }
        // 4. Set the states
        tokenIdToVestData[_tokenId].amountCollected = (tokenIdToVestData[_tokenId].amountCollected).add(amountToWithdraw);
        tokenIdToVestData[_tokenId].lastCollectedTimestamp = timeNow;
        // 5. transfer asset to the owner of the asset.
        IERC20(tokenIdToVestData[_tokenId].vestedTokenAddress).transfer(ownerOf(_tokenId), amountToWithdraw);
    }
}