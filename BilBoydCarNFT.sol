/*
  We acknowledge the use of ChatGPT to help with structuring the code and debugging errors.
*/

// SPDX-License-Identifier: MIT

/*
  Specify compiler version to be used.
  Does not compile with versions earlier than 0.8.0
  Headers and how the contract is created is inspirated by
  https://docs.openzeppelin.com/contracts/3.x/erc721 
*/
pragma solidity ^0.8.0;

/*
  Import OpenZeppelin libraries for NFT functionality and counter utilities.
  These allow leveraging ERC721 implementation and tracking the number of cars available.
*/
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Defining the contract as an ERC721 smart contract utilizing openzeppelin's library
contract BilBoydCarNFT is ERC721 {
    // Enable the use of the Counters library for our counter
    // Inspired by: https://docs.openzeppelin.com/contracts/2.x/erc721
    using Counters for Counters.Counter;  
    
    // Track the unique ID for each car
    Counters.Counter private _carIds;

    /*
    Struct logic is inspired by:
    https://medium.com/@PaulElisha1/erc721-intricacies-simplified-understanding-erc721-receiver-hook-writing-a-gas-efficient-nft-0298030a46b6
    */
    // Defines the structure of our car objects with appropriate attributes.
    struct Car { 
        uint256 id;                 // Unique ID for the car
        string model;               // Model name of the car
        string color;               // Color of the car
        uint256 year;               // Year of manufacturing
        uint256 originalValue;      // Original price of the car
        uint256 currentMileage;     // Current mileage, updated over time
    }

    // Struct to store details about each car lease. 
    struct Lease {
        uint256 carId;               // ID of the car being leased
        address lessee;              // Address of the lessee
        uint256 monthlyQuota;        // Monthly payment amount for the lease
        uint256 nextPaymentDue;      // Timestamp for the next payment due date
        bool confirmedByBilBoyd;     // Flag for lease confirmation by BilBoyd
        bool active;                 // Flag indicating if the lease is active
    }

    // Mapping from car ID to Car struct, enabling retrieval by car ID
    mapping(uint256 => Car) public cars;
    mapping(address => Lease) public leases;
    
    // Address of bilBoyd, usually the ethereum address which is assigned in the constructor
    address public bilBoyd;

    // Payment period constant for monthly payments
    uint256 public constant PAYMENT_PERIOD = 30 days;

    // Constructor initializes ERC721 contract with name and symbol
    constructor() ERC721("BilBoydCarNFT", "BBCNFT") {
        bilBoyd = msg.sender;   //Sets bilBoyd as the contract owner
    }

    // Modifier to restrict functions to only bilboyd
    // Inspired by "An introduction to Solidity and smart contracts" provided by professor
    modifier onlyBilBoyd() {
        require(msg.sender == bilBoyd, "Only BilBoyd can perform this action.");
        _;
    }
    // Modifier to restrict functions to only the leasee of a specific car
    modifier onlyLessee(uint256 carId) {
        require(leases[msg.sender].carId == carId, "Not authorized.");
        _;
    }

    // TASK 1
    // Function to mint a new car NFT
    // Inspired by: "An introduction to Solidity and smart contracts"
    function addCar(
        string memory model,                    
        string memory color,                    
        uint256 year,                           
        uint256 originalValue,                  
        uint256 currentMileage                  
    ) public onlyBilBoyd {                      
        _carIds.increment();                    // Increment the car ID counter
        uint256 newCarId = _carIds.current();   // Assign unique id to the car to be minted

        cars[newCarId] = Car(newCarId, model, color, year, originalValue, currentMileage);  // Add car attributes
        _mint(bilBoyd, newCarId);               // Mint car NFT and assign to BilBoyd
    }

    // TASK 2
    // Function to calculate the monthly quota for leasing
    function calculateMonthlyQuota(
        uint256 carId,          
        uint256 yearsOfExperience,
        uint256 contractDuration,
        uint256 mileageCap

    // View-only so the function costs no gas fee. 
    // All the calculations are defined on what we infer to be reasonable discounts/premiums for each instance.
    ) public view returns (uint256) {
        Car memory car = cars[carId];                   // Retriev car details from storage
        uint256 baseRate = car.originalValue / 1000;    // Monthly rate as 1/1000 of car's original value
        
        // Calculate discount based on the driver's experience in years
        // More experience yeields a higher discount
        uint256 experienceDiscount = 0;
        if (yearsOfExperience >= 4 && yearsOfExperience <= 10) {
            // 2% discount for 4-10 years of experience
            experienceDiscount = (baseRate * 2) / 100;
        } else if (yearsOfExperience > 10) {
            // 5% discount for 10+ years of experience
            experienceDiscount = (baseRate * 5) / 100;
        }

        // Calculate discount based on the contract duration
        // The longer the contract is, the higher the discount
        uint256 contractDiscount = 0;
        if (contractDuration >= 2 && contractDuration < 6) {
            // 3% discount for a contract duration of  2-5 months
            contractDiscount = (baseRate * 3) / 100;
        } else if (contractDuration >= 6 && contractDuration <= 12) {
            // 5% discount for a contract duration of  6-12 months
            contractDiscount = (baseRate * 5) / 100;
        } else if (contractDuration > 12 ) {
            // 8% discount for a contract duration over a year
            contractDiscount = (baseRate * 8) / 100;
        }

        // Calculate milage cap premium
        // The premium gets higher the higher the milage cap is
        uint256 mileageCapPremium = 0;
        if (mileageCap >= 5000 && mileageCap < 10000) {
            // 1% premium for a mileage cap between 5,000-9,999 km
            mileageCapPremium = baseRate / 100;
        } else if (mileageCap >= 10000 && mileageCap < 20000) {
            // 2% premium for a mileage cap between 10,000-19,999 km
            mileageCapPremium = (baseRate * 2) / 100;
        } else if (mileageCap > 20000) {
            // 3% premium for a mileage cap over 20,000 km
            mileageCapPremium = (baseRate * 3) / 100;
        }
        
        // Calculate discount based on current mileage
        // Higher milage gives higher discounts
        uint256 currentMileageDiscount = 0;
        if (car.currentMileage >= 10000 && car.currentMileage < 20000) {
            // 1% discount for mileage between 10,000-19,999 km
            currentMileageDiscount = baseRate / 100;
        } else if (car.currentMileage >= 20000 && car.currentMileage < 50000) {
            // 2% for mileage between 20,000-49,999 km
            currentMileageDiscount = (baseRate * 2) / 100;
        } else if (car.currentMileage >= 50000) {
            // 3% discount for mileage over 50,000 km
            currentMileageDiscount = (baseRate * 3) / 100;
        }

        //Final monthly quota calculation, combiing all previous calculations.
        uint256 monthlyQuota = baseRate - experienceDiscount - contractDiscount + mileageCapPremium - currentMileageDiscount;

        return monthlyQuota;
    }

    // TASK 3
    /* The task has taken inspiration from the following sources:
        - "An introduction to Solidity and smart contracts" provided by professor
        - payable functionality from https://solidity-by-example.org/payable/
        - error handling:
          https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions
        - payment duedates:
          https://docs.soliditylang.org/en/latest/units-and-global-variables.html 
        - modify access control (onlyBilboyd and onlyLeasee):
          https://docs.soliditylang.org/en/latest/contracts.html#function-modifiers
        - transfer functionality:
          https://docs.openzeppelin.com/contracts/2.x/api/token/erc721
        - transaction properties (e.g. sender, value):
          https://docs.soliditylang.org/en/latest/cheatsheet.html#index-5
    */
    // Function to register the lease and lock funds
    function registerLease(
        uint256 carId,
        uint256 yearsOfExperience,
        uint256 contractDuration,
        uint256 mileageCap
    ) public payable {

        uint256 monthlyQuota = calculateMonthlyQuota(carId, yearsOfExperience, contractDuration, mileageCap);
        
        // Total payment includes 3-month down payment + 1st monthly quota
        uint256 totalPayment = monthlyQuota * 4;

        // Check if the lessee has sent the correct amount to register the lease
        require(msg.value == totalPayment, "Incorrect payment amount.");
        
        // Create a new lease entry for the lessee
        leases[msg.sender] = Lease(carId, msg.sender, monthlyQuota, block.timestamp + PAYMENT_PERIOD, false, true);

        // Transfer the car NFT from BilBoyd to the lessee to indicate temporary ownership
        _transfer(bilBoyd, msg.sender, carId);
    }

    // Function for BilBoyd to confirm the lease and unlock funds
    function confirmLease(address lessee) public onlyBilBoyd {
        Lease storage lease = leases[lessee]; // Access the lessee's lease record

        // Ensure the lease is active and awaiting BilBoyd's confirmation
        require(lease.active, "Lease not active.");
        require(!lease.confirmedByBilBoyd, "Lease already confirmed.");

        // BilBoyd confirms the lease, marking it as active
        lease.confirmedByBilBoyd = true;
        lease.active = true;

        // Transfer funds to BilBoyd
        // 3 months down payment + 1st monthly payment
        payable(bilBoyd).transfer(lease.monthlyQuota * 4);
    }

    // TASK 4
    /* The task has taken inspiration from the following sources:
       - modify access control (onlyBilboyd and onlyLeasee):
         https://docs.soliditylang.org/en/latest/contracts.html#function-modifiers
       - payment duedates:
         https://docs.soliditylang.org/en/latest/units-and-global-variables.html 
       - error handling:
         https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions
       - transfer functionality:
         https://docs.openzeppelin.com/contracts/2.x/api/token/erc721
       - transaction properties (e.g. sender, value):
         https://docs.soliditylang.org/en/latest/cheatsheet.html#index-5
    */
    // Function to make a monthly payment
    function payMonthlyQuota(uint256 carId) public payable onlyLessee(carId) {
        Lease storage lease = leases[msg.sender]; // Access caller's lease record

        // Ensure lease is active and confirmed by BilBoyd
        require(lease.active, "Lease is not active.");
        require(lease.confirmedByBilBoyd, "Lease is not confirmed.");

        // Ensure payment is made before next payment due date
        require(block.timestamp <= lease.nextPaymentDue, "Payment is overdue.");

        // Verify correct payment amount
        require(msg.value == lease.monthlyQuota, "Incorrect payment amount.");

        // Update next payment due date to one month from current due date
        lease.nextPaymentDue = lease.nextPaymentDue + PAYMENT_PERIOD;

        // Transfer the monthly payment to BilBoyd
        payable(bilBoyd).transfer(msg.value);
    }

    // Function to handle overdue payments
    function terminateLeaseForNonPayment(address lessee) public onlyBilBoyd {
        Lease storage lease = leases[lessee]; // Access lessee's lease record

        require(lease.active, "Lease is not active.");
        
        // Ensure payment is made before next payment due date
        require(block.timestamp > lease.nextPaymentDue, "Payment is not overdue.");

        // Deactivate the lease and transfer car back to BilBoyd
        lease.active = false;
        _transfer(lessee, bilBoyd, lease.carId);
    }
    
    // TASK 5
    // Function to handle the three different options at the end of the lease
    // Used ChatGPT to help with the function syntax
    function endLease(
        uint256 carId,             
        uint8 option,
        uint256 newCarId,
        uint256 currentMileage,
        uint256 yearsOfExperience,
        uint256 contractDuration
    ) public onlyLessee(carId) {
        Lease storage lease = leases[msg.sender]; // Access lease details
        require(lease.active, "Lease not active.");

        if (option == 1) {
            // Option 1: Terminate the lease
            lease.active = false;                    // Set lease status to inactive
            _transfer(msg.sender, bilBoyd, carId);   // Transfer car NFT ownership back to BilBoyd
        } else if (option == 2) {
            // Option 2: Extend lease by one year with a recalculated monthly quota
            uint256 newQuota = calculateMonthlyQuota(carId, 0, 1, 12); // Extend the lease by one year with updated parameters
            lease.monthlyQuota = newQuota;
            lease.nextPaymentDue = block.timestamp + PAYMENT_PERIOD;   // Reset payment due date
        } else if (option == 3) {
            // Option 3: Sign a lease for a new vehicle
            lease.active = false;
            _transfer(msg.sender, bilBoyd, carId);
            registerLease(newCarId, currentMileage, yearsOfExperience, contractDuration); // Call for a new lease registration
        } else {
            // In case option is not 1-3
            revert("Invalid option selected.");
        }
    }

}
