// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract TicketNFT is ERC1155, Ownable {
    uint256 public constant VIP = 1;
    uint256 public constant RSVP = 2;
    uint256 public constant General = 3;

    struct TicketDetails {
    uint256 purchasePrice;
    uint256 sellingPrice;
    bool forSale;
    }

    address private _organiser;
    address[] private customers;
    uint256[] private ticketsForSale;
    // uint256 private _ticketPrice;
    uint256 private _totalSupply;

    mapping(uint256 => TicketDetails) public _ticketDetails;
    mapping(address => mapping(uint =>uint256[])) public  purchasedTickets;
    mapping (uint => uint) public categoryWiseTotalSupply;

    modifier isValidSellAmount(uint256 ticketId) {
        uint256 purchasePrice = _ticketDetails[ticketId].purchasePrice;
        uint256 sellingPrice = _ticketDetails[ticketId].sellingPrice;

        require(
            purchasePrice + ((purchasePrice * 110) / 100) > sellingPrice,
            "Re-selling price is more than 110%"
        );
        _;
    }

    receive() external payable{

    }
    

    constructor(
        // uint256 ticketPrice,
        uint totalVipTicket,
        uint totalRsvpTicket,
        uint totalGeneralTicket
    ) ERC1155("https://gateway.pinata.cloud/ipfs/QmVJBppEtr1jCZXDSvvHqSN1jQxuhofpAFMwGn4GtmM9B9/{id}.json") {
        _organiser = msg.sender;

        // _ticketPrice = ticketPrice;


        categoryWiseTotalSupply[1] = totalVipTicket;
        categoryWiseTotalSupply[2] = totalRsvpTicket;
        categoryWiseTotalSupply[3] = totalGeneralTicket;

        _ticketDetails[VIP] = TicketDetails(5 ether, 0 , false);
        _ticketDetails[RSVP] = TicketDetails(2 ether, 0 , false);
        _ticketDetails[General] = TicketDetails(1 ether, 0 , false);

        _mint(msg.sender, VIP, totalVipTicket, "");
        _mint(msg.sender, RSVP, totalRsvpTicket, "");
        _mint(msg.sender, General, totalGeneralTicket, "");
        
    }





    function uri(uint256 _tokenid) override public pure returns (string memory) {
        return string(
            abi.encodePacked(
                "https://gateway.pinata.cloud/ipfs/QmVJBppEtr1jCZXDSvvHqSN1jQxuhofpAFMwGn4GtmM9B9/",
                Strings.toString(_tokenid),".json"
            )
        );
    }

    
    function mint(address account, uint256 newTicketId, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
            _ticketDetails[newTicketId] = TicketDetails({
            purchasePrice: _ticketDetails[newTicketId].purchasePrice,
            sellingPrice: 0,
            forSale: false
        });

            _mint(account, newTicketId, amount, data);
    }   

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        for(uint i = 0 ; i < ids.length ; i++){
            
            _ticketDetails[i] = TicketDetails({

            purchasePrice: _ticketDetails[i].purchasePrice,
            sellingPrice: 0,
            forSale: false
        });
        }

        _mintBatch(to, ids, amounts, data);


    }

    function primaryTransferTicket(
        address seller,
        address buyer,
        uint saleTicketId,
        uint ticketQuantity,
        bytes memory data) 
        
        public payable{

        require(
            seller == _organiser,
            "Only initial purchase allowed"
        );

        uint price = _ticketDetails[saleTicketId].purchasePrice;
        console.log("price %s",price);

        uint numOfTickets = (msg.value)/price;
        console.log("numOfTickets %s", numOfTickets);

        require(ticketQuantity == numOfTickets,"Not exact tickets");

        safeTransferFrom(seller, buyer, saleTicketId, ticketQuantity, data);

        if (!isCustomerExist(buyer)) {
            customers.push(buyer);
        }
        purchasedTickets[buyer][saleTicketId].push(ticketQuantity);
    }

    function secondaryTransferTicket(
        address buyer,
        uint256 saleTicketId,
        bytes memory data
        )
        public
        payable 
        isValidSellAmount(saleTicketId)
    {
        // address seller = ownerOf(saleTicketId);
        uint256 purchasePrice = _ticketDetails[saleTicketId].purchasePrice;
        uint256 increasedPurchasePrice = purchasePrice + ((purchasePrice * 110) / 100);

        uint numOfTicket = msg.value / increasedPurchasePrice;

        uint256 sellingPrice = _ticketDetails[saleTicketId].sellingPrice;
        
        require(msg.value >= purchasePrice + ((purchasePrice * 110) / 100));

        safeTransferFrom(msg.sender, buyer, saleTicketId, numOfTicket, data );

        if (!isCustomerExist(buyer)) {
            customers.push(buyer);
        }

        purchasedTickets[buyer][saleTicketId].push(numOfTicket);

        // removeTicketFromCustomer(seller, saleTicketId);
        // removeTicketFromSale(saleTicketId);

        _ticketDetails[saleTicketId] = TicketDetails({
            purchasePrice: sellingPrice,
            sellingPrice: 0,
            forSale: false
        });
    }


    function setSaleDetails(
        uint256 ticketId,
        uint256 amount,
        uint256 sellingPrice,
        address operator
    ) public {
        uint256 purchasePrice = _ticketDetails[ticketId].purchasePrice;

        require(
            purchasePrice + ((purchasePrice * 110) / 100) > sellingPrice,
            "Re-selling price is more than 110%"
        );

        // Should not be an organiser
        require(msg.sender != owner(), "Function is Only for Reselling");

        _ticketDetails[ticketId].sellingPrice = sellingPrice;
        _ticketDetails[ticketId].forSale = true;

        if (!isSaleTicketAvailable(ticketId)) {
            ticketsForSale.push(ticketId);
        }

        setApprovalForAll(operator, true);
    }


    function isCustomerExist(address buyer) internal view returns (bool) {
        for (uint256 i = 0; i < customers.length; i++) {
            if (customers[i] == buyer) {
                return true;
            }
        }
        return false;
    }    


    function isSaleTicketAvailable(uint256 ticketId)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < ticketsForSale.length; i++) {
            if (ticketsForSale[i] == ticketId) {
                return true;
            }
        }
        return false;
    }

        function getTicketPrice(uint newTicketId) public view returns (uint256) {
        return _ticketDetails[newTicketId].purchasePrice;
    }

    // Get organiser's address
    function getOrganiser() public view returns (address) {
        return _organiser;
    }

    // Get current ticketId
    function ticketRemaining(uint id) public view returns (uint256[] memory) {
        return purchasedTickets[address(this)][id];
    }

    // Get selling price for the ticket
    function getSellingPrice(uint256 ticketId) public view returns (uint256) {
        return _ticketDetails[ticketId].sellingPrice;
    }

    // Get all tickets available for sale
    function getTicketsForSale() public view returns (uint256[] memory) {
        return ticketsForSale;
    }

    // Get ticket details
    function getTicketDetails(uint256 ticketId)
        public
        view
        returns (
            uint256 purchasePrice,
            uint256 sellingPrice,
            bool forSale
        )
    {
        return (
            _ticketDetails[ticketId].purchasePrice,
            _ticketDetails[ticketId].sellingPrice,
            _ticketDetails[ticketId].forSale
        );
    }

    // Get all tickets owned by a customer
    function getTicketsOfCustomer(address customer, uint id)
        public
        view
        returns (uint256[] memory)
    {
        return purchasedTickets[customer][id];
    }



}    

//0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
//0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2