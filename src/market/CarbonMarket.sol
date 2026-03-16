// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../access/Ownable.sol";
import "../security/ReentrancyGuard.sol";

interface IToken {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

contract CarbonMarket is Ownable, ReentrancyGuard {
    struct Order {
        address seller;
        uint128 amount;
        uint128 price;
        bool active;
    }

    uint256 public constant BPS_DENOMINATOR = 10_000;

    uint256 public nextOrderId;
    uint256 public feeBps;
    address public feeRecipient;

    mapping(uint256 => Order) public orders;

    IToken public immutable token;

    error InvalidOrder();
    error IncorrectPayment();
    error Unauthorized();
    error TransferFailed();
    error InvalidFee();

    event OrderCreated(uint256 indexed id, address indexed seller, uint256 amount, uint256 price);
    event OrderCancelled(uint256 indexed id);
    event OrderFilled(uint256 indexed id, address indexed buyer, uint256 feePaid);
    event FeeConfigUpdated(uint256 feeBps, address feeRecipient);

    constructor(address _owner, address _token, address _feeRecipient, uint256 _feeBps) Ownable(_owner) {
        if (_token == address(0) || _feeRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > 1_000) revert InvalidFee();

        token = IToken(_token);
        feeRecipient = _feeRecipient;
        feeBps = _feeBps;

        emit FeeConfigUpdated(_feeBps, _feeRecipient);
    }

    function setFeeConfig(uint256 _feeBps, address _feeRecipient) external onlyOwner {
        if (_feeRecipient == address(0)) revert ZeroAddress();
        if (_feeBps > 1_000) revert InvalidFee();

        feeBps = _feeBps;
        feeRecipient = _feeRecipient;

        emit FeeConfigUpdated(_feeBps, _feeRecipient);
    }

    function createOrder(uint256 amount, uint256 price) external returns (uint256 id) {
        if (amount == 0 || price == 0) revert InvalidOrder();

        id = ++nextOrderId;
        orders[id] = Order({
            seller: msg.sender,
            amount: uint128(amount),
            price: uint128(price),
            active: true
        });

        emit OrderCreated(id, msg.sender, amount, price);
    }

    function cancelOrder(uint256 id) external {
        Order storage myOrder = orders[id];
        if (!myOrder.active) revert InvalidOrder();
        if (myOrder.seller != msg.sender) revert Unauthorized();

        myOrder.active = false;
        emit OrderCancelled(id);
    }

    function fillOrder(uint256 id) external payable nonReentrant {
        Order storage myOrder = orders[id];
        if (!myOrder.active) revert InvalidOrder();
        if (msg.value != myOrder.price) revert IncorrectPayment();

        myOrder.active = false;

        uint256 fee = (uint256(myOrder.price) * feeBps) / BPS_DENOMINATOR;
        uint256 sellerProceeds = uint256(myOrder.price) - fee;

        bool tokenTransferOk = token.transferFrom(myOrder.seller, msg.sender, myOrder.amount);
        if (!tokenTransferOk) revert TransferFailed();

        (bool feePaid,) = payable(feeRecipient).call{value: fee}("");
        if (!feePaid) revert TransferFailed();

        (bool sellerPaid,) = payable(myOrder.seller).call{value: sellerProceeds}("");
        if (!sellerPaid) revert TransferFailed();

        emit OrderFilled(id, msg.sender, fee);
    }
}
