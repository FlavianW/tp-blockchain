// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAggregatorV3 {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
    function decimals() external view returns (uint8);
}

contract BilletChain {
    // ── Minimal ERC-721 ────────────────────────────────────────────────────────
    mapping(uint256 => address) private _owners;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    function ownerOf(uint256 tokenId) public view returns (address owner) {
        owner = _owners[tokenId];
        require(owner != address(0), "token does not exist");
    }

    function balanceOf(address owner) public view returns (uint256) {
        require(owner != address(0));
        return _balances[owner];
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(msg.sender == owner, "not owner");
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function getApproved(uint256 tokenId) public view returns (address) {
        ownerOf(tokenId);
        return _tokenApprovals[tokenId];
    }

    function transferFrom(address from, address to, uint256 tokenId) public {
        require(ownerOf(tokenId) == from, "from != owner");
        require(
            msg.sender == from || msg.sender == _tokenApprovals[tokenId],
            "not authorized"
        );
        require(to != address(0));
        _transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0));
        _balances[to] += 1;
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;
        delete _tokenApprovals[tokenId];
        emit Transfer(from, to, tokenId);
    }

    // ── Business state ─────────────────────────────────────────────────────────
    address public immutable organizer;
    uint256 public immutable totalTickets;
    uint256 public immutable priceEUR;
    IAggregatorV3 public immutable priceFeed;
    uint256 public constant RESALE_FEE_BPS = 500;

    uint256 private _nextTokenId;
    bool public paused;

    mapping(uint256 => uint256) public initialPrice;
    mapping(uint256 => uint256) public listingPrice;
    mapping(address => uint256) public pendingWithdrawals;

    event TicketPurchased(uint256 indexed tokenId, address indexed buyer, uint256 pricePaid);
    event TicketListed(uint256 indexed tokenId, address indexed seller, uint256 price);
    event TicketResold(uint256 indexed tokenId, address indexed from, address indexed to, uint256 price);
    event Withdrawn(address indexed recipient, uint256 amount);
    event PauseToggled(bool paused);

    error SoldOut();
    error WrongPayment(uint256 expected, uint256 sent);
    error NotTicketOwner();
    error PriceTooHigh(uint256 maxAllowed, uint256 requested);
    error NotListed();
    error NothingToWithdraw();
    error StaleOracle();
    error BadOraclePrice();
    error TransferFailed();
    error Paused();
    error NotOrganizer();

    constructor(uint256 _totalTickets, uint256 _priceEUR, address _priceFeed) {
        organizer = msg.sender;
        totalTickets = _totalTickets;
        priceEUR = _priceEUR;
        priceFeed = IAggregatorV3(_priceFeed);
    }

    // ── Pause ──────────────────────────────────────────────────────────────────
    function togglePause() external {
        if (msg.sender != organizer) revert NotOrganizer();
        paused = !paused;
        emit PauseToggled(paused);
    }

    // ── Oracle ─────────────────────────────────────────────────────────────────
    // Le feed doit retourner "EUR par ETH" (ex. 2000e8 pour 2000 EUR/ETH, decimals=8).
    function ticketPriceInWei() public view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = priceFeed.latestRoundData();
        if (block.timestamp - updatedAt > 1 hours) revert StaleOracle();
        if (answer <= 0) revert BadOraclePrice();
        uint8 dec = priceFeed.decimals();
        return (priceEUR * 1e18 * (10 ** dec)) / uint256(answer);
    }

    // ── Vente initiale ─────────────────────────────────────────────────────────
    function buyTicket() external payable {
        if (paused) revert Paused();
        if (_nextTokenId >= totalTickets) revert SoldOut();
        uint256 price = ticketPriceInWei();
        if (msg.value < price) revert WrongPayment(price, msg.value);

        uint256 tokenId = _nextTokenId++;
        initialPrice[tokenId] = price;
        pendingWithdrawals[organizer] += price;

        _mint(msg.sender, tokenId);
        emit TicketPurchased(tokenId, msg.sender, price);

        if (msg.value > price) {
            (bool ok, ) = msg.sender.call{value: msg.value - price}("");
            if (!ok) revert TransferFailed();
        }
    }

    // ── Marché secondaire ──────────────────────────────────────────────────────
    function listForResale(uint256 tokenId, uint256 price) external {
        if (paused) revert Paused();
        if (ownerOf(tokenId) != msg.sender) revert NotTicketOwner();
        uint256 maxPrice = (initialPrice[tokenId] * 110) / 100;
        if (price > maxPrice) revert PriceTooHigh(maxPrice, price);

        listingPrice[tokenId] = price;
        _tokenApprovals[tokenId] = address(this);
        emit Approval(msg.sender, address(this), tokenId);
        emit TicketListed(tokenId, msg.sender, price);
    }

    function buyResaleTicket(uint256 tokenId) external payable {
        if (paused) revert Paused();
        uint256 price = listingPrice[tokenId];
        if (price == 0) revert NotListed();
        if (msg.value < price) revert WrongPayment(price, msg.value);

        address seller = ownerOf(tokenId);
        listingPrice[tokenId] = 0;
        uint256 fee = (price * RESALE_FEE_BPS) / 10_000;
        pendingWithdrawals[seller] += price - fee;
        pendingWithdrawals[organizer] += fee;

        _transfer(seller, msg.sender, tokenId);
        emit TicketResold(tokenId, seller, msg.sender, price);

        if (msg.value > price) {
            (bool ok, ) = msg.sender.call{value: msg.value - price}("");
            if (!ok) revert TransferFailed();
        }
    }

    // ── Pull payment ───────────────────────────────────────────────────────────
    function withdraw() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        if (amount == 0) revert NothingToWithdraw();
        pendingWithdrawals[msg.sender] = 0;
        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit Withdrawn(msg.sender, amount);
    }

    // ── Consultation (gas-optimisée) ───────────────────────────────────────────
    function countListed(uint256[] calldata tokenIds) external view returns (uint256 count) {
        for (uint256 i; i < tokenIds.length; ) {
            if (listingPrice[tokenIds[i]] > 0) ++count;
            unchecked { ++i; }
        }
    }
}
