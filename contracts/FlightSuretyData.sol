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

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
        uint256 price;
        address[] passengers;
        bool insureesCredited;
    }

    mapping(bytes32 => Flight) private flights;
    mapping(address => uint256) insureesCredit;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address account);
    event AirlineApproved(address account);
    event RegisterFlight(bytes32 flightKey);
    event InsureesCredites(bytes32 flightKey);
    event Pay(address passenger);

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
        require(
            authorizedAccounts[msg.sender] == true,
            "FlightSuretyData/caller-not-authorized"
        );
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

    function authorizeAccount(address account) external requireContractOwner {
        authorizedAccounts[account] = true;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
     * @dev Check Airline Vote
     */
    function checkVote(address airline, address voter) public view returns (bool) {
        return airlines[airline].voters[voter];
    }

    /**
     * @dev Vote for airline approval
     */
    function voteForAirline(address airline) public {        
        airlines[airline].voters[msg.sender] = true;
    }

    /**
     * @dev Get Airline data
     */
    function getAirline(address account)
        public
        view
        returns (
            bool,
            bool,
            uint256
        )
    {
        Airline memory airline = airlines[account];
        return (airline.registered, airline.registrationFeePaid, airline.votes);
    }
    

    /**
     * @dev Get Flight details
     */
    function getFlight(bytes32 flightKey)
        public
        view
        returns (
            bool isRegistered,
            uint8 statusCode,
            uint256 updatedTimestamp,
            address airline,
            uint256 price
        )
    {
        isRegistered = flights[flightKey].isRegistered;
        statusCode = flights[flightKey].statusCode;
        updatedTimestamp = flights[flightKey].updatedTimestamp;
        airline = flights[flightKey].airline;
        price = flights[flightKey].price;
    }

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
            airlines[account].registered == false,
            "FlightSuretyData/airline-already-registered"
        );

        airlines[account] = Airline({
            registered: registered,
            registrationFeePaid: registrationFeePaid,
            votes: votes
        });
        
        totalAirlines = totalAirlines + 1;

        emit AirlineRegistered(account);
    }

    /**
     * @dev Register Flight
     */
    function registerFlight(
        bytes32 flightKey,
        uint8 statusCode,
        uint256 timestamp,
        address airline,
        uint256 price
    ) public requireIsOperational isAuthorized {
        require(
            flights[flightKey].isRegistered == true,
            "FlightSuretyData/flight-already-registered"
        );
        require(
            airlines[airline].registered == true,
            "FlightSuretyData/airline-not-registered"
        );
        require(
            airlines[airline].registrationFeePaid == true,
            "FlightSuretyData/airline-registration-fee-not-paid"
        );
        require(price > 0, "FlightSuretyData/invalid-price");

        flights[flightKey] = Flight({
            isRegistered: true,
            statusCode: statusCode,
            updatedTimestamp: timestamp,
            airline: airline,
            price: price,
            passengers: new address[](0),
            insureesCredited: false
        });

        emit RegisterFlight(flightKey);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */

    function buy(bytes32 flightKey, address passenger)
        public
        payable
        requireIsOperational
        isAuthorized
    {
        require(
            flights[flightKey].isRegistered == true,
            "FlightSuretyData/flight-not-registered"
        );
        flights[flightKey].passengers.push(passenger);
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(bytes32 flightKey)
        public
        requireIsOperational
        isAuthorized
    {
        require(
            flights[flightKey].isRegistered == true,
            "FlightSuretyData/flight-not-registered"
        );
        require(
            flights[flightKey].insureesCredited == false,
            "FlightSuretyData/insurees-already-credited"
        );

        flights[flightKey].insureesCredited = true;
        for (uint8 i = 0; i < flights[flightKey].passengers.length; i++) {
            address passenger = flights[flightKey].passengers[i];
            insureesCredit[passenger] = flights[flightKey].price.mul(15e17);
        }
        emit InsureesCredites(flightKey);
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(address passenger)
        public
        requireIsOperational
        isAuthorized
    {
        uint256 amount = insureesCredit[passenger];
        require(amount > 0, "FlightSuretyData/insufficient-balance");
        insureesCredit[passenger] = 0;
        address(uint160(passenger)).transfer(insureesCredit[passenger]);
        emit Pay(passenger);
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fund(address airline)
        public
        payable
        requireIsOperational
        isAuthorized
    {
        airlines[airline].registrationFeePaid = true;
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function updateFlightStatus(bytes32 flightKey, uint8 statusCode)
        public
        requireIsOperational
        isAuthorized
    {
        flights[flightKey].statusCode = statusCode;
    }
    

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    function() external payable {}
}
