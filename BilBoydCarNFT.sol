// SPDX-License-Identifier: MIT

/*Specify compiler version to be used. Does not compile with versions earlier than 0.8.0
  Headers and how the contract is created is inspirated by https://docs.openzeppelin.com/contracts/3.x/erc721 
*/
pragma solidity ^0.8.0;  

/*
Import openzeppelin libraries to our NFT project. This allows us to leverage ERC721 implementations for our smart contract
and a counter to keep track of number of cars available.
*/
import "@openzeppelin/contracts/token/ERC721/ERC721.sol"; 
import "@openzeppelin/contracts/utils/Counters.sol"; 

// defining our contract as an ERC721 smart contract utilizing openzeppelin's library

contract BilBoydCarNFT is ERC721 {  
    using Counters for Counters.Counter;  // enables the use of the Counters library for our counter. Inspired by: https://docs.openzeppelin.com/contracts/2.x/erc721
    Counters.Counter private _carIds;     // tracks the unique ID for each car

    // Defines the structure of our car objects with appropriate attributes. Struct logic is inspired by: https://medium.com/@PaulElisha1/erc721-intricacies-simplified-understanding-erc721-receiver-hook-writing-a-gas-efficient-nft-0298030a46b6
    struct Car { 
        uint256 id;                       // Unique ID for the car
        string model;                     // Model name of the car
        string color;                     // Color of the car
        uint256 year;                     // Year of manufacturing
        uint256 originalValue;            // Original price of the car
        uint256 currentMileage;           // The current mileage of the car. This will change over time.
    }

    struct Lease {
        uint256 carId;
        address lessee;
        uint256 monthlyQuota;
        uint256 nextPaymentDue;
        bool confirmedByBilBoyd;
        bool active;
    }

    mapping(uint256 => Car) public cars;   // Mapping fromn car id to the car struct. This allows retrieval of cat details by its ID
    mapping(address => Lease) public leases;
    address public bilBoyd;                // Address of bilBoyd, usually the ethereum address which is assigned in the constructor

    uint256 public constant PAYMENT_PERIOD = 30 days; // payment due every month 

    //Defines the constructor of the contract. This initializes the ERC721 contract with name and symbol.
    constructor() ERC721("BilBoydCarNFT", "BBCNFT") {
        bilBoyd = msg.sender;                                       //sets bilBoyd as the contract owner
    }

    /* modifier to restrict functions to only bilboyd.
    Inspired by "An introduction to Solidity and smart contracts" provided by professor.
    */
    modifier onlyBilBoyd() {
        require(msg.sender == bilBoyd, "Only BilBoyd can perform this action.");
        _;
    }
    // modifier to restrict functions to only the leasee of a specific car
    modifier onlyLessee(uint256 carId) {
        require(leases[msg.sender].carId == carId, "Not authorized.");
        _;
    }

    // TASK 1
    // Function to mint a new car NFT. Inspired by: "An introduction to Solidity and smart contracts"
    function addCar(
        string memory model,                        // defines the model
        string memory color,                        // defines the color
        uint256 year,                               // defines the year of manufacturing
        uint256 originalValue,                      // Original value of the car
        uint256 currentMileage                      // Current mileage of the car
    ) public onlyBilBoyd {                          // Only bilboyd can call this function
        _carIds.increment();                        // Increment the car ID counter
        uint256 newCarId = _carIds.current();       // assign an unique id to the car to be minted

        cars[newCarId] = Car(newCarId, model, color, year, originalValue, currentMileage);  // Store the new cars attributes in the cars mapping
        _mint(bilBoyd, newCarId);                   // Mint the car NFT and assign it to the contract owner (bilBoyd)
    }

    // TASK 2
    // Function to calculate the monthly quota for leasing
    function calculateMonthlyQuota(
        uint256 carId,                      //ID of leased car
        uint256 yearsOfExperience,          //Driving experience of lessee (in years)
        uint256 contractDuration,           //Duration of contract (in months)
        uint256 mileageCap                  //Milage cap set for the lease

    //View-only so the function costs no gas fee. 
    //All the calculations are defined on what we infer to be reasonable discounts/premiums for each instance.
    ) public view returns (uint256) {
        Car memory car = cars[carId];                                   //Get the car details from storage
        uint256 baseRate = car.originalValue / 1000;                    //Monthly rate calculated as 1/1000 of the car's original value
        
        //Calculate discount based on the driver's experience in years. More experience yeields a higher discount.
        uint256 experienceDiscount = 0;
        if (yearsOfExperience >= 4 && yearsOfExperience <= 10) {
            experienceDiscount = (baseRate * 2) / 100; //2% discount for 4-10 years of experience
        } else if (yearsOfExperience > 10) {
            experienceDiscount = (baseRate * 5) / 100; //5% discount for 10+ years of experience
        }

         //Calculate discount based on the contract duration. The longer the contract is, the higher the discount.
        uint256 contractDiscount = 0;
        if (contractDuration >= 2 && contractDuration < 6) {
            contractDiscount = (baseRate * 3) / 100; //3% discount for a contract duration of  2-5 months
        } else if (contractDuration >= 6 && contractDuration <= 12) {
            contractDiscount = (baseRate * 5) / 100; //5% discount for a contract duration of  6-12 months
        } else if (contractDuration > 12 ) {
            contractDiscount = (baseRate * 8) / 100; //8% discount for a contract duration over a year
        }

        //Calculate milage cap premium. The premium gets higher the higher the milage cap is.
        uint256 mileageCapPremium = 0;
        if (mileageCap >= 5000 && mileageCap < 10000) {
            mileageCapPremium = baseRate / 100; //1% premium for a mileage cap between 5,000-9,999 km
        } else if (mileageCap >= 10000 && mileageCap < 20000) {
            mileageCapPremium = (baseRate * 2) / 100; //2% premium for a mileage cap between 10,000-19,999 km
        } else if (mileageCap > 20000) {
            mileageCapPremium = (baseRate * 3) / 100; //3% premium for a mileage cap over 20,000 km
        }
        
        //Calculate discount based on current mileage. Higher milage gives higher discounts. 
        uint256 currentMileageDiscount = 0;
        if (car.currentMileage >= 10000 && car.currentMileage < 20000) {
            currentMileageDiscount = baseRate / 100; //1% discount for mileage between 10,000-19,999 km
        } else if (car.currentMileage >= 20000 && car.currentMileage < 50000) {
            currentMileageDiscount = (baseRate * 2) / 100; //2% for mileage between 20,000-49,999 km
        } else if (car.currentMileage >= 50000) {
            currentMileageDiscount = (baseRate * 3) / 100; //3% discount for mileage over 50,000 km
        }

        //Final monthly quota calculation, combiing all previous calculations.
        uint256 monthlyQuota = baseRate - experienceDiscount - contractDiscount + mileageCapPremium - currentMileageDiscount;

        return monthlyQuota;
    }

    // TASK 3
    // Function to register the lease and lock funds
    function registerLease(
        uint256 carId,
        uint256 yearsOfExperience,
        uint256 contractDuration,
        uint256 mileageCap
    ) public payable {
        //require(ownerOf(carId) == bilBoyd, "Car is not available for lease.");
        //require(!leases[msg.sender].active, "Already leasing a car.");

        uint256 monthlyQuota = calculateMonthlyQuota(carId, yearsOfExperience, contractDuration, mileageCap);
        uint256 totalPayment = monthlyQuota * 4;

        require(msg.value == totalPayment, "Incorrect payment amount.");
        
        leases[msg.sender] = Lease(carId, msg.sender, monthlyQuota, block.timestamp + PAYMENT_PERIOD, false, true);
        _transfer(bilBoyd, msg.sender, carId);
    }

    // Function for BilBoyd to confirm the lease and unlock funds
    function confirmLease(address lessee) public onlyBilBoyd {
        Lease storage lease = leases[lessee];
        require(lease.active, "Lease not active.");
        require(!lease.confirmedByBilBoyd, "Lease already confirmed.");

        lease.confirmedByBilBoyd = true;
        lease.active = true; // Activate the leas

        // Transfer funds to BilBoyd
        payable(bilBoyd).transfer(lease.monthlyQuota * 4); // 3 months down payment + 1st monthly payment
    }

    // TASK 4
    // Function to make a monthly payment
    function payMonthlyQuota(uint256 carId) public payable onlyLessee(carId) {
        Lease storage lease = leases[msg.sender];
        require(lease.active, "Lease is not active.");
        require(lease.confirmedByBilBoyd, "Lease is not confirmed.");
        require(block.timestamp <= lease.nextPaymentDue, "Payment is overdue.");
        require(msg.value == lease.monthlyQuota, "Incorrect payment amount.");

        // Update next payment due date
        lease.nextPaymentDue = lease.nextPaymentDue + PAYMENT_PERIOD;

        // Transfer payment to BilBoyd
        payable(bilBoyd).transfer(msg.value);
    }

    // Function to handle overdue payments
    function terminateLeaseForNonPayment(address lessee) public onlyBilBoyd {
        Lease storage lease = leases[lessee];
        require(lease.active, "Lease is not active.");
        require(block.timestamp > lease.nextPaymentDue, "Payment is not overdue.");

        // Terminate lease and transfer car back to BilBoyd
        lease.active = false;
        _transfer(lessee, bilBoyd, lease.carId);
    }
    
    // TASK 5
    // Function with the three different options at the end of the lease
    // Used ChatGPT to help with the function syntax
    function endLease(uint256 carId, uint8 option, uint256 newCarId, uint256 currentMileage, uint256 yearsOfExperience, uint256 contractDuration) public onlyLessee(carId) {
        Lease storage lease = leases[msg.sender];       // Access lease details
        require(lease.active, "Lease not active.");

        if (option == 1) {
            // Option 1: Terminate the lease
            lease.active = false;                       // Sets lease status to inactive
            _transfer(msg.sender, bilBoyd, carId);      // Transfers the car NFT ownership back to BilBoyd
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
