// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.5.0/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/access/Ownable.sol";

contract lottery is ERC20, Ownable {

    // =============================
    // Token management
    // =============================

    // Project's NFT contract address
    address public nft;

    // Constructor
    constructor() ERC20("Lottery", "LOT") {
        _mint(address(this), 1000);
        nft = address(new mainERC721());
    }

    // Winner
    address public winner;

    // User register
    mapping(address => address) public user_contract;

    // ERC-20 token price
    function tokenPrice(uint256 _numTokens) internal pure returns (uint256) {
        return _numTokens * (1 ether);
    }

    // Display of a user's ERC-20 token balance
    function balanceTokens(address _account) public view returns (uint256) {
        return balanceOf(_account);
    }

    // Display of the ERC-20 token balance of the SC
    function balanceTokensSC() public view returns (uint256) {
        return balanceOf(address(this));
    }

    // Display of the ether balance of the SC
    function balanceEthersSC() public view returns (uint256) {
        return address(this).balance / 10**18;
    }

    // New ERC-20 token generation
    function mint(uint256 _amount) public onlyOwner {
        _mint(address(this), _amount);
    }

    // User register
    function register() internal {
        address addr_personal_contract = address(new nftTickets(msg.sender, address(this), nft));
        user_contract[msg.sender] = addr_personal_contract;
    }

    // User's info
    function usersInfo(address _account) public view returns (address) {
        return user_contract[_account];
    }

    // ERC-20 token purchase
    function buyTokens(uint256 _numTokens) public payable {
        // User register
        if (user_contract[msg.sender] == address(0)) {
            register();
        }
        // Setting the cost of the tokens to buy
        uint256 cost = tokenPrice(_numTokens);
        // Evaluation of the money that the client pays for the tokens
        require(msg.value >= cost, "Buy less tokens or pay with more ethers");
        // Obtaining the number of ERC-20 tokens available
        uint256 balance = balanceTokensSC();
        require(_numTokens <= balance, "Buy a smaller amount of tokens");
        // Refund of excess money
        uint256 returnValue = msg.value - cost;
        // The SC returns the remaining amount
        payable(msg.sender).transfer(returnValue);
        // Sending the tokens to the user
        _transfer(address(this), msg.sender, _numTokens);
    }

    // Return tokens to the SC
    function returnTokens(uint _numTokens) public payable {
        // The number of tokens must be greater than 0
        require(_numTokens > 0, "You must return a number of tokens greater than 0");
        // The user must prove that they have the tokens they want to return
        require(_numTokens <= balanceTokens(msg.sender), "You don't have the number of tokens you want to return");
        // The user transfers the tokens to the SC
        _transfer(msg.sender, address(this), _numTokens);
        // The SC sends the ethers to the user
        payable(msg.sender).transfer(tokenPrice(_numTokens));
    }

    // =============================
    // Lottery management
    // =============================

    // Lottery ticket price (in ERC-20 tokens)
    uint public ticketPrice = 5;
    mapping(address => uint []) idUser_tickets;
    mapping(uint => address) adnTicket;
    // Random number
    uint randNonce = 0;
    // Generated lottery tickets
    uint [] boughtTickets;

    // Buy lottery tickets
    function buyTicket(uint _numTickets) public {
        // Total price of the tickets
        uint totalPrice = _numTickets * ticketPrice;
        // Verification of user tokens
        require(totalPrice <= balanceTokens(msg.sender),
        "You don't have enough tokens");
        // Token transfer from the user to the SC
        _transfer(msg.sender, address(this), totalPrice);

        for (uint i = 0; i <_numTickets; i++) {
            uint random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % 10000;
            randNonce++;
            // Storing the ticket's data linked to the user
            idUser_tickets[msg.sender].push(random);
            // Storing the ticket's data
            boughtTickets.push(random);
            // Setting the ticket's adn for winner generation
            adnTicket[random] = msg.sender;
            // Creating a new NFT for ticket number
            nftTickets(user_contract[msg.sender]).mintTicket(msg.sender, random);
        }
    }

    // Display of the user's ticket
    function yourTickets(address _owner) public view returns(uint [] memory) {
        return idUser_tickets[_owner];
    }

    // Lottery winner generation
    function generateWinner() public onlyOwner {
        // Array length declaration
        uint length = boughtTickets.length;
        // Verifying the purchase of at least 1 ticket
        require(length > 0, "No tickets have been bought");
        // Random choice of a number between 0 and length
        uint random = uint(uint(keccak256(abi.encodePacked(block.timestamp))) % length);
        // Random number selection
        uint selection = boughtTickets[random];
        // Lottery winner address
        winner = adnTicket[selection];
        // Sending 95% of the reward to the winner
        payable(winner).transfer(address(this).balance * 95 / 100);
        // Sending the 5% of the reward to the owner
        payable(owner()).transfer(address(this).balance * 5 / 100);
    }

}

// NFT SC
contract mainERC721 is ERC721 {

    address public lotteryAddress;
    constructor() ERC721("Lottery", "STE") {
        lotteryAddress = msg.sender;
    }

    // NFT creation
    function safeMint(address _owner, uint256 _ticket) public {
        require(msg.sender == lottery(lotteryAddress).usersInfo(_owner),
                "You don't have permission to execute this function");
        _safeMint(_owner, _ticket);
    }
}

contract nftTickets {

    // Owner's relevant data
    struct Owner {
        address ownerAddress;
        address parentContract;
        address nftContract;
        address userContract;
    }
    // Owner data structure
    Owner public owner;

    // SC constructor (child) 
    constructor(address _owner, address _parentContract, address _nftContract) {
        owner = Owner(_owner,
                      _parentContract, 
                      _nftContract, 
                      address(this));
    }

    // Lottery ticket conversion
    function mintTicket(address _owner, uint _ticket) public {
        require(msg.sender == owner.parentContract, 
                "You don't have permission to execute this function");
        mainERC721(owner.nftContract).safeMint(_owner, _ticket);
    }
}
