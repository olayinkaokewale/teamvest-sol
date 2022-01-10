//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "base64-sol/base64.sol";

contract TeamVest is ERC721, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint128;
    using Strings for string;
    using Address for address;

    uint256 private _currentTokenId = 0;

    mapping(address => bool) public teamMember;
    uint public TEAM_MEMBERS_COUNT;
    uint256 public lastVestTime;

    struct Vest {
        address vestedTokenAddress;
        uint256 amountLocked; // this will remain as is or can be increased by admin.
        uint256 amountCollected; // immutable - this will keep increasing as the token gets disbursed. [amountRemianing = amountLocked - amountCollected]
        uint lockTimestamp; // keep track of timestamp locked - used together with totalVestingTime
        uint totalVestingInterval; // total number of times allowed to withdraw vested token - e.g. 12
        uint totalVestingTime; // total vesting time (in seconds) - e.g. 24 months time = 24m * 30d * 24h * 60m * 60s = 62208000 seconds
        uint lastCollectedTimestamp; // important to calculate how much to withdraw
    }
    mapping(uint256 => Vest) internal tokenIdToVestData;
    mapping(address => uint256[]) public addressToTokenToAddress; // To get all 
    string private tokenBaseURI = "data:application/json;base64,";
    string private baseImageURI = "https://teamvest.finance/assets/image.png";

    constructor() ERC721("TeamVest", "TMVT") {
        // Initialize the contract
    }

    function addBulkVesting(
        address[] calldata _teamAddresses, 
        uint[] calldata _vestingPeriods, // time in seconds
        uint256[] calldata _vestAmounts,
        uint [] calldata _vestingIntervals, // integer like 10 or 12, etc.
        address _tokenAddress
    ) external onlyOwner() {
        // 1. be sure everything has the same array lengths
        require(_teamAddresses.length == _vestingPeriods.length 
            && _vestingPeriods.length == _vestAmounts.length
            && _vestAmounts.length == _vestingIntervals.length, "TEAMVEST: length is not the same");
        
        // 2. be sure there is approval to deposit the amount required from the calling contract and then deposit it.
        uint256 _amountNeeded;
        for (uint i=0; i < _vestAmounts.length; i++) {
            _amountNeeded = _amountNeeded.add(_vestAmounts[i]);
        }
        require(IERC20(_tokenAddress).allowance(msg.sender, address(this)) >= _amountNeeded, "TEAMVEST: token not approved");
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amountNeeded);
        //set the team addresses
        uint timeNow = block.timestamp;
        for (uint i=0; i < _teamAddresses.length; i++) {
            _mintVest(_teamAddresses[i], _vestingPeriods[i], _vestAmounts[i], _vestingIntervals[i], _tokenAddress, timeNow);
        }
        TEAM_MEMBERS_COUNT = TEAM_MEMBERS_COUNT + _teamAddresses.length;
        lastVestTime = timeNow;
    }

    function addSingleVesting(
        address _teamMember, 
        uint _vestingPeriod, // time in seconds
        uint256 _vestAmount,
        uint _vestingInterval, // integer like 10 or 12, etc.
        address _tokenAddress
    ) external onlyOwner() {
        //1. be sure there is approval to deposit the amount required from the calling contract and then deposit it.
        require(IERC20(_tokenAddress).allowance(msg.sender, address(this)) >= _vestAmount, "TEAMVEST: token not approved");
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _vestAmount);
        //set the team addresses
        uint timeNow = block.timestamp;
        _mintVest(_teamMember, _vestingPeriod, _vestAmount, _vestingInterval, _tokenAddress, timeNow);
        TEAM_MEMBERS_COUNT = TEAM_MEMBERS_COUNT + 1;
        lastVestTime = timeNow;
    }

    function _mintVest(
        address _to, 
        uint _vestingPeriod, 
        uint256 _vestAmount,
        uint _vestInterval,
        address _tokenAddress,
        uint timeNow
    ) private {
        // 1. mint and get id of the token
        uint256 _tokenId = _mintTo(_to);
        // 2. Set the vesting struct
        tokenIdToVestData[_tokenId] = Vest({
            vestedTokenAddress: _tokenAddress,
            amountLocked: _vestAmount, // this will remain as is or can be increased by admin.
            amountCollected: 0, // immutable - this will keep increasing as the token gets disbursed. [amountRemianing = amountLocked - amountCollected]
            lockTimestamp: timeNow, // keep track of timestamp locked - used together with totalVestingTime
            totalVestingInterval: _vestInterval, // total number of times allowed to withdraw vested token - e.g. 12
            totalVestingTime: _vestingPeriod, // total vesting time (in seconds) - e.g. 24 months time = 24m * 30d * 24h * 60m * 60s = 62208000 seconds
            lastCollectedTimestamp: timeNow
        });
        // 3. add user to team members
        teamMember[_to] = true;
    }

    modifier ownerIsTeamMember(uint256 _tokenId) {
        require(msg.sender == ownerOf(_tokenId), "TEAMVEST: Owner is not the caller");
        require(teamMember[ownerOf(_tokenId)], "TEAMVEST: Owner is not a team member");
        _;
    }

    modifier isTeamMember(address _addr) {
        require(teamMember[msg.sender], "TEAMVEST: User is not a team member");
        _;
    }

    modifier isNotTeamMember(address _addr) {
        require(!teamMember[_addr], "TEAMVEST: User is already a team member");
        _;
    }

    function addTeamMember(address _memberAddress) external onlyOwner() isNotTeamMember(_memberAddress) {
        teamMember[_memberAddress] = true;
        TEAM_MEMBERS_COUNT = TEAM_MEMBERS_COUNT + 1;
    }

    function removeTeamMember(address _memberAddress) external onlyOwner() isTeamMember(_memberAddress) {
        delete teamMember[_memberAddress]; // delete the team member
        TEAM_MEMBERS_COUNT = TEAM_MEMBERS_COUNT - 1;
    }

    function withdrawVest(uint256 _tokenId) external ownerIsTeamMember(_tokenId) {
        require(tokenIdToVestData[_tokenId].amountLocked > tokenIdToVestData[_tokenId].amountCollected, "TEAMVEST: you have withdrawn all amounts");
        // 1. Calculate the amount per seconds and other neccessary things
        uint vestExpiryTime = tokenIdToVestData[_tokenId].lockTimestamp + tokenIdToVestData[_tokenId].totalVestingTime;
        uint256 amountPerSeconds = (tokenIdToVestData[_tokenId].amountLocked).div(tokenIdToVestData[_tokenId].totalVestingTime); //z
        uint minimumWithdrawalTime = tokenIdToVestData[_tokenId].totalVestingTime / tokenIdToVestData[_tokenId].totalVestingInterval; //y
        // 2. Set the elapse time and check if possible to withdraw
        uint elapsedTime; //x
        uint256 amountToWithdraw;
        uint timeNow = block.timestamp;
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

    function withdrawRemainingAfterVesting(address _tokenAddress) external onlyOwner() {
        require(lastVestTime < block.timestamp, "Cannot withdraw before the last vesting period");
        require(IERC20(_tokenAddress).balanceOf(address(this)) > 0, "Token does not exist in contract");
        IERC20(_tokenAddress).transfer(msg.sender, IERC20(_tokenAddress).balanceOf(address(this)));
    }

    // receive and fallback methods
    receive() payable external {}
    fallback() payable external {}


    // =================== ERC 721 FUNCTIONS: START ==============================================================

    function generateMetadata(uint256 _tokenId) private view returns (string memory) {
        return string(abi.encodePacked(
            '{"trait_type": "vestedTokenAddress", "value": ', tokenIdToVestData[_tokenId].vestedTokenAddress,'},',
            '{"trait_type": "amountLocked", "value": ', Strings.toString(tokenIdToVestData[_tokenId].amountLocked),'},',
            '{"trait_type": "amountCollected", "value": ', Strings.toString(tokenIdToVestData[_tokenId].amountCollected),'},',
            '{"trait_type": "lockTimestamp", "value": ', Strings.toString(tokenIdToVestData[_tokenId].lockTimestamp),'},',
            '{"trait_type": "totalVestingInterval", "value": ', Strings.toString(tokenIdToVestData[_tokenId].totalVestingInterval),'},',
            '{"trait_type": "totalVestingTime", "value": ', Strings.toString(tokenIdToVestData[_tokenId].totalVestingTime),'},',
            '{"trait_type": "lastCollectedTimestamp", "value": ', Strings.toString(tokenIdToVestData[_tokenId].lastCollectedTimestamp),'}'
        ));
    }

    function tokenURI(uint256 _tokenId) override public view returns (string memory) {
        // return string(abi.encodePacked(baseTokenURI, Strings.toString(_tokenId), ".json"));
        string memory attributes = string(abi.encodePacked(
            '[',
            generateMetadata(_tokenId),
            ']'
        ));
        string memory encodedJsonData = Base64.encode(
            bytes(abi.encodePacked(
                '{"name": "', name(), '#', Strings.toString(_tokenId), '",',
                '"description":"TeamVest Vesting Token",',
                '"attributes":', attributes, ',',
                '"image":"', baseImageURI,'"'
            ))
        );
        return string(abi.encodePacked(tokenBaseURI,encodedJsonData));
    }

    // 1. ------------------------- Creation -----------------------------
    /**
     * @dev Mints a token to an address with a tokenURI.
     * @param _to address of the future owner of the token
     */
    function _mintTo(address _to) private returns (uint256) {
        uint256 newTokenId = _getNextTokenId();
        _mint(_to, newTokenId);
        _incrementTokenId();
        return newTokenId;
    }

    /**
     * @dev calculates the next token ID based on value of _currentTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.add(1);
    }

    /**
     * @dev increments the value of _currentTokenId
     */
    function _incrementTokenId() private {
        _currentTokenId++;
    }
    // 1. ----------------------------------------------------------------

    // =================== ERC 721 FUNCTIONS: END ==============================================================



}