// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BilBoydCarNFT is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _carIds;

    struct Car {
        uint256 id;
        string model;
        string color;
        uint256 year;
        uint256 originalValue;
        uint256 currentMileage;
    }

    struct Lease {
        uint256 carId;
        address lessee;
        uint256 monthlyQuota;
        uint256 nextPaymentDue;
        bool confirmedByBilBoyd;
        bool active;
    }

    mapping(uint256 => Car) public cars;
    mapping(address => Lease) public leases;
    address public bilBoyd;

    uint256 public constant PAYMENT_PERIOD = 30 days; // payment due every month 

    constructor() ERC721("BilBoydCarNFT", "BBCNFT") {
        bilBoyd = msg.sender;
    }

    modifier onlyBilBoyd() {
        require(msg.sender == bilBoyd, "Only BilBoyd can perform this action.");
        _;
    }

    modifier onlyLessee(uint256 carId) {
        require(leases[msg.sender].carId == carId, "Not authorized.");
        _;
    }

    // TASK 1
    // Function to mint a new car NFT
    function addCar(
        string memory model,
        string memory color,
        uint256 year,
        uint256 originalValue,
        uint256 mileageCap
    ) public onlyBilBoyd {
        _carIds.increment();
        uint256 newCarId = _carIds.current();

        cars[newCarId] = Car(newCarId, model, color, year, originalValue, mileageCap);
        _mint(bilBoyd, newCarId);
    }

    // TASK 2
    // Function to calculate the monthly quota for leasing
    function calculateMonthlyQuota(
        uint256 carId,
        uint256 yearsOfExperience,
        uint256 contractDuration,
        uint256 mileageCap

    ) public view returns (uint256) {
        Car memory car = cars[carId];
        uint256 baseRate = car.originalValue / 1000;
        
        uint256 experienceDiscount = 0;
        if (yearsOfExperience >= 4 && yearsOfExperience <= 10) {
            experienceDiscount = (baseRate * 2) / 100; // 2% discount
        } else if (yearsOfExperience > 10) {
            experienceDiscount = (baseRate * 5) / 100; // 5% discount
        }

        uint256 contractDiscount = 0;
        if (contractDuration >= 2 && contractDuration < 6) {
            contractDiscount = (baseRate * 3) / 100; // 3% discount
        } else if (contractDuration >= 6 && contractDuration < 12) {
            contractDiscount = (baseRate * 5) / 100; // 5% discount
        } else if (contractDuration > 12 ) {
            contractDiscount = (baseRate * 8) / 100; // 8% discount
        }

        // Mileage cap premium
        uint256 mileageCapPremium = 0;
        if (mileageCap >= 5000 && mileageCap < 10000) {
            mileageCapPremium = baseRate / 100; // 1% premium
        } else if (mileageCap >= 10000 && mileageCap < 20000) {
            mileageCapPremium = (baseRate * 2) / 100; // 2% premium
        } else if (mileageCap > 20000) {
            mileageCapPremium = (baseRate * 3) / 100; // 3% premium
        }
        
        // Current malage 
        uint256 currentMileageDiscount = 0;
        if (car.currentMileage >= 10000 && car.currentMileage < 20000) {
            currentMileageDiscount = baseRate / 100; // 1% discount
        } else if (car.currentMileage >= 20000 && car.currentMileage < 50000) {
            currentMileageDiscount = (baseRate * 2) / 100; // 2% discount
        } else if (car.currentMileage >= 50000) {
            currentMileageDiscount = (baseRate * 3) / 100; // 3% discount
        }

        // Final monthly quota calculation
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
    // Function to end lease options at lease expiry
    function endLease(uint256 carId, uint8 option) public onlyLessee(carId) {
        Lease storage lease = leases[msg.sender];
        require(lease.active, "Lease not active.");

        if (option == 1) {
            // Option A: Terminate the lease
            lease.active = false;
            _transfer(msg.sender, bilBoyd, carId);
        } else if (option == 2) {
            // Option B: Extend lease by one year with a recalculated monthly quota
            uint256 newQuota = calculateMonthlyQuota(carId, 0, 1, 12); // Assume 1 year extension with updated parameters
            lease.monthlyQuota = newQuota;
            lease.nextPaymentDue = block.timestamp + PAYMENT_PERIOD; // Reset payment due date
        } else if (option == 3) {
            // Option C: Sign a lease for a new vehicle
            lease.active = false;
            _transfer(msg.sender, bilBoyd, carId);
            // Lessee can then call registerLease to start a new lease for a different car
        }
    }

}
