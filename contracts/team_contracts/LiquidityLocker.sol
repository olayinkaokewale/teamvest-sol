//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LiquidityLocker {
    using SafeMath for uint256;
    using SafeMath for uint128;

    struct LockObject {
        address tokenAddress;
        uint256 lockedAmount;
        uint timeLockedFor;
        bool withdrawn;
    }

    LockObject[] public lockedPairs;
    mapping(uint256 => address) public lockedPairToOwnerAddress;
    uint256 public totalSupply;


    event Transfer(uint256 indexed _tokenId, address indexed _to);

    modifier onlyOwner(uint256 _tokenId) {
        require(lockedPairToOwnerAddress[_tokenId] == msg.sender, "Not owner of token");
        _;
    }

    modifier timeIsUp(uint256 _tokenId) {
        require(lockedPairs[_tokenId].timeLockedFor < block.timestamp, "Time is not up");
        _;
    }

    constructor() {

    }

    function tokenIndex() private view returns (uint256) {
        return lockedPairs.length;
    }

    function lockToken(address _tokenAddress, uint256 _lockedAmount, uint _lockTimestamp) public {
        require(IERC20(_tokenAddress).allowance(msg.sender, address(this)) >= _lockedAmount, "Not enough allowance to transfer token");
        require(_lockTimestamp > block.timestamp, "Time must be greater than now");
        // transfer the token to the contract
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _lockedAmount);
        // create the lockpair object
        lockedPairs.push(LockObject({
            tokenAddress: _tokenAddress,
            lockedAmount: _lockedAmount,
            timeLockedFor: _lockTimestamp,
            withdrawn: false
        }));
        uint256 tokenId = lockedPairs.length - 1;
        // set this tokenId to the owner
        lockedPairToOwnerAddress[tokenId] = msg.sender;
        // increase the total supply
        totalSupply = totalSupply + 1;
    }

    function withdrawToken(uint256 _tokenId) public onlyOwner(_tokenId) timeIsUp(_tokenId) {
        // transfer the pair token to the address
        IERC20(lockedPairs[_tokenId].tokenAddress).transfer(msg.sender, lockedPairs[_tokenId].lockedAmount);
        lockedPairs[_tokenId].withdrawn = true;
        // assign the token Id to burn address
        _transfer(_tokenId, address(0));
        // remove from total supply
        totalSupply = totalSupply - 1;
    }

    function transfer(uint256 _tokenId, address _to) public onlyOwner(_tokenId) {
        // Make the transfer
        _transfer(_tokenId, _to);
    }

    function _transfer(uint256 _tokenId, address _to) private {
        // Make the transfer
        lockedPairToOwnerAddress[_tokenId] = _to;
        // emit the transfer event
        emit Transfer(_tokenId, _to);
    }

}