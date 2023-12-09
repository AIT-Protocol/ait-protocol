// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract IDO is Ownable {
    bytes32 public merkleRoot;
    address public ait;
    uint256 public aitPerEther = 20000;
    uint256 public startTime;
    uint256 public endTime;
    uint256 public cap = 0.1 ether;
    uint256 public total;
    bool public isClaimed;

    mapping (address => uint256) public payAmount;
    mapping (address => uint256) private aitReleased;

    modifier verifyTransactionAmount(uint _amount, uint purchaseLimit){
        require(total + _amount <= cap, "IDO: AMOUNT_WRONG");
        require(payAmount[msg.sender] + _amount <= purchaseLimit, "IDO: PURCHASE_LIMIT_WRONG");
        _;
    }

    constructor(bytes32 _merkleRoot, address _ait, uint256 _start, uint256 _end) {
        merkleRoot = _merkleRoot;
        ait = _ait;
        startTime = _start;
        endTime = _end;
    }

    receive() external payable {}

    event SetPrice(uint256 price, uint256 blockTime);
    event SetTime(uint256 startTime, uint256 endTime, uint256 blockTime);
    event SetCap(uint256 cap, uint256 blockTime);
    event SetClaim(bool status, uint256 blockTime);
    event SetPurchaseLimit(uint256 limit, uint256 blockTime);
    event SetAITToken(address token, uint256 blockTime);
    event Buy(address user, uint256 amount, uint256 total, uint256 blockTime);
    event AITReleased(address user, uint256 amount, uint256 blockTime);

    function setPrice(uint256 _price) external onlyOwner {
        require(block.timestamp < startTime, "IDO has started, the price cannot be changed");
        aitPerEther = _price;
        emit SetPrice(_price, block.timestamp);
    }

    function setCap(uint _cap) external onlyOwner {
        require(block.timestamp < endTime, "IDO: CAP_WRONG");
        cap = _cap;
        emit SetCap(_cap, block.timestamp);
    }

    function setTime(uint256 _start, uint256 _end) external onlyOwner {
        if(startTime > 0) {
            require(block.timestamp < startTime);
        }
        startTime = _start;
        endTime = _end;
        emit SetTime(_start, _end, block.timestamp);
    }

    function setClaim(bool status) external onlyOwner {
        isClaimed = status;
        emit SetClaim(status, block.timestamp);
    }

    function setAITToken(address _token) external onlyOwner {
        ait = _token;
        emit SetAITToken(_token, block.timestamp);
    }

    function withdrawEther() external onlyOwner {
        require(block.timestamp >= endTime, "The owner can only withdraw ETH after the IDO ends");
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function withdrawToken(address _token) external onlyOwner {
        require(block.timestamp >= endTime, "The owner can only withdraw ETH after the IDO ends");
        uint256 amount = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(msg.sender, amount);
    }

    // Function to add an address to the whitelist using MerkleProof
    function buy(bytes32[] memory proof, uint256 purchaseLimit) external payable verifyTransactionAmount(msg.value, purchaseLimit) {
        require(block.timestamp > startTime && block.timestamp < endTime, "IDO: TIME_WRONG");
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, purchaseLimit));
        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid Merkle proof");
        uint256 amount = msg.value;
        payAmount[msg.sender] += amount;
        total += amount;
        emit Buy(msg.sender, amount, total, block.timestamp);
    }

    function released(address _user) public view returns(uint256){
        //withdraw
        return aitReleased[_user];
    }

    function releasable(address _user) public view returns(uint256){
        //available
        uint256 amount = (block.timestamp > endTime) ? payAmount[_user] * aitPerEther : 0;
        return amount - released(_user);
    }

    function release() external {
        require(isClaimed, "IDO: IS_CLAIMED_WRONG");
        require(block.timestamp > endTime, "IDO: RELEASE_WRONG");
        uint256 amount = releasable(msg.sender);
        require(amount > 0, "IDO: AMOUNT=0");
        aitReleased[msg.sender] += amount;
        emit AITReleased(msg.sender, amount, block.timestamp);
        IERC20(ait).transfer(msg.sender, amount);
    }
}
