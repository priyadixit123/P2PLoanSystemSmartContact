// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract P2PLoan {

    struct Loan {

        address borrower;
        address lender;
        uint256 loanAmount;
        uint256 interestRate;
        uint256 loanDuration;
        uint collateralAmount;
        bool isRepaid;
        uint256 startTime;
    }

    uint256 public loanCounter = 0;
    mapping(uint256 => Loan) public loans;

    mapping (address => uint256 ) public collateralBalance;

     event LoanRequested (uint256 loanId, address borrower, uint256 loanAmount, uint256 collateralAmount );
     event LoanRepaid (uint256 loanId );
     event CollateralLiquidated (uint256 loanId);
     event LoanFunded (uint256 loanId, address lender);
     // Function to get collateral balance of a user (borrower)
     function getCollateralBalance (address _user) external view returns (uint) {
         return collateralBalance[_user];
     }
    // Function to request a loan (borrower)
    function requestLoan(uint256 _loanAmount, uint256 _interestRate, uint256 _loanDuration) external payable {
    require(msg.value > 0, "Collateral is required");

       Loan memory loan = 
        Loan({
            borrower: msg.sender,
            lender: address(0),
            loanAmount: _loanAmount,
            interestRate:_interestRate ,
            loanDuration :_loanDuration ,
            collateralAmount:msg.value , // note that this field name was changed
            isRepaid:false,
            startTime:block.timestamp 
});
        
         loanCounter++;
         loans[loanCounter].loanAmount = _loanAmount;
         loans[loanCounter].startTime = block.timestamp;
         collateralBalance[msg.sender] += msg.value;
         emit LoanRequested(loanCounter, msg.sender, _loanAmount, msg.value);

       }   
       // Function to fund a loan (lender)

       function fundLoan(uint256 loanId) external payable {

        Loan storage _loan = loans[loanId];
        require(_loan.lender == address(0), "Already funded");
        require(msg.value == _loan.loanAmount , "Incorrect Loan Amount");

        _loan.lender = msg.sender;
        _loan.startTime =block.timestamp;

        payable(_loan.borrower). transfer(_loan.loanAmount);
        emit LoanFunded(loanId, msg.sender);
       }
       
       // Function to repay the loan (borrower)

       function repayLoan(uint256 loanId) external payable{
        Loan storage loan = loans[loanId];
        require(loan.borrower == msg.sender ,"Not the right loan");
        require(loan.isRepaid == false , "Loan already Repaid");
        uint256 interest = (loan.loanAmount *loan.interestRate) / 100;
        uint256 totalRepayment = loan.loanAmount + interest;
        require(msg.value == totalRepayment , "Incorrect Repayment amount ");
         loan.isRepaid = true;
         // Transfer repayment to lender
         payable (loan.lender). transfer(totalRepayment);

         payable (loan.borrower). transfer (loan.collateralAmount );
         emit LoanRepaid(loanId);

        }
        // Function to liquidate collateral if loan is not repaid on time (lender)
        function liquidateCollateral (uint256 loanId) external payable{
            require(loans[loanId].isRepaid == true , "Loan not repaid");
            require(loans[loanId].loanDuration < block.timestamp - loans[loanId].startTime , "Loan not repaid on time");
            uint256 totalCollateral = loans[loanId].collateralAmount + collateralBalance[loans[loanId].borrower];
            uint256 totalRepayment = loans[loanId].loanAmount + (collateralBalance[loans[loanId].borrower] *loans[loanId].interestRate) / 100;
            require(msg.value == totalRepayment , "Incorrect Repayment amount ");
            loans[loanId].isRepaid = true;
            loans[loanId].collateralAmount = 1;
            loans[loanId].lender = msg.sender;
            loans[loanId].startTime = block.timestamp;
            payable (loans[loanId].borrower). transfer (totalCollateral);
            emit CollateralLiquidated(loanId);

       }

       // Fallback function to receive ether
       receive()external payable {}

}    
