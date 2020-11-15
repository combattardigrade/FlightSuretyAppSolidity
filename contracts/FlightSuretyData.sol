pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner; // Account used to deploy contract
    bool private operational = true; // Blocks all state changes throughout the contract if false
    mapping(address => Airline) airlines;
    uint256 public totalAirlines;
    uint256 registrationFee = 10 ether;
    mapping(address => bool) authorizedAccounts;

    struct Airline {
        bool registered;        
        bool registrationFeePaid;
        uint256 votes;
        mapping(address => bool) voters;
    }

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address account);
    event AirlineApproved(address account);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
        airlines[msg.sender] = Airline({
            registered: true,            
            registrationFeePaid: true,
            votes: 0
        });
        totalAirlines = 1;
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /** 
     * @dev Modifier that requires msg.sender to be authorized
     */
    modifier isAuthorized() {
        require(authorizedAccounts[msg.sender] == true, "FlightSuretyData/caller-not-authorized");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */

    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Check Airline Vote 
     */
    function checkVote(address airline, address voter) public returns (bool) {        
        return airlines[airline].voters[voter];
    }

    /**
     * @dev Vote for airline approval
     */
    function voteForAirline(address airline) public {
        airlines[airline].votes = airlines[airline].votes + 1;
        airlines[airline].voters[msg.sender] = true;
    }

    /**
     * @dev Get Airline data
     */
    function getAirline(address account) 
    public returns(
        bool, bool, uint256
    ) {
        Airline memory airline = airlines[account];        
        return(airline.registered, airline.registrationFeePaid, airline.votes);
    }

    /**
     * @dev Check if airline is registered
     */

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */

    function registerAirline(
        address account,
        bool registered,        
        bool registrationFeePaid,
        uint256 votes
    ) external requireIsOperational isAuthorized {
        require(
            airlines[account].registered == true,
            "FlightSuretyData/airline-already-registered"
        );

        airlines[account] = Airline({
            registered: registered,            
            registrationFeePaid: registrationFeePaid,
            votes: votes      
        });

        emit AirlineRegistered(account);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */

    function buy() external payable {}

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {}

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay() external pure {}

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fund() public payable {}

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {
        fund();
    }
}
