// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TokenLaunchpad {
    address public immutable creator;
    uint256 public immutable tokenPrice;
    uint256 public immutable maxRaise;
    uint256 public immutable deadline;

    uint256 public totalRaised;
    bool public finalized;
    bool public cancelled;

    mapping(address => uint256) public contributions;

    error NotCreator();
    error SaleEnded();
    error SaleNotEnded();
    error InvalidAmount();
    error MaxRaiseExceeded();
    error AlreadyFinalized();
    error AlreadyCancelled();
    error TransferFailed();
    error NothingToRefund();
    error Reentrancy();

    event TokensPurchased(address indexed buyer, uint256 amount);
    event LaunchFinalized(uint256 totalRaised);
    event LaunchCancelled();
    event Refunded(address indexed buyer, uint256 amount);

    uint256 private constant NOT_ENTERED = 1;
    uint256 private constant ENTERED = 2;
    uint256 private reentrancyStatus = NOT_ENTERED;

    modifier onlyCreator() {
        if (msg.sender != creator) revert NotCreator();
        _;
    }

    modifier nonReentrant() {
        if (reentrancyStatus == ENTERED) revert Reentrancy();
        reentrancyStatus = ENTERED;
        _;
        reentrancyStatus = NOT_ENTERED;
    }

    constructor(uint256 _tokenPrice, uint256 _maxRaise, uint256 _deadline) {
        if (_tokenPrice == 0) revert InvalidAmount();
        if (_maxRaise == 0) revert InvalidAmount();
        if (_deadline <= block.timestamp) revert SaleEnded();

        creator = msg.sender;
        tokenPrice = _tokenPrice;
        maxRaise = _maxRaise;
        deadline = _deadline;
    }

    function buyTokens() external payable {
        if (block.timestamp >= deadline) revert SaleEnded();
        if (finalized || cancelled) revert SaleEnded();
        if (msg.value == 0) revert InvalidAmount();
        if (totalRaised + msg.value > maxRaise) {
            revert MaxRaiseExceeded();
        }

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;

        emit TokensPurchased(msg.sender, msg.value);
    }

    function finalize() external onlyCreator nonReentrant {
        if (block.timestamp < deadline && totalRaised < maxRaise) {
            revert SaleNotEnded();
        }
        if (finalized) revert AlreadyFinalized();
        if (cancelled) revert AlreadyCancelled();

        finalized = true;

        (bool success, ) = payable(creator).call{value: totalRaised}("");
        if (!success) revert TransferFailed();

        emit LaunchFinalized(totalRaised);
    }

    function cancel() external onlyCreator {
        if (finalized) revert AlreadyFinalized();
        if (cancelled) revert AlreadyCancelled();

        cancelled = true;

        emit LaunchCancelled();
    }

    function refund() external nonReentrant {
        if (!cancelled && block.timestamp < deadline) {
            revert SaleNotEnded();
        }

        if (finalized) revert AlreadyFinalized();

        uint256 amount = contributions[msg.sender];

        if (amount == 0) revert NothingToRefund();

        contributions[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        if (!success) revert TransferFailed();

        emit Refunded(msg.sender, amount);
    }
}
