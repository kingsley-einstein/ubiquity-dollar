// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/ICreditRedemptionCalculator.sol";
import "./UbiquityDollarManager.sol";
import "./libs/ABDKMathQuad.sol";
import "./CreditNFT.sol";

/// @title Uses the following formula: ((1/(1-R)^2) - 1)
contract CreditRedemptionCalculator is ICreditRedemptionCalculator {
    using ABDKMathQuad for uint256;
    using ABDKMathQuad for bytes16;

    UbiquityDollarManager public manager;
    uint256 private _coef = 1 ether;

    modifier onlyAdmin() {
        require(
            manager.hasRole(manager.INCENTIVE_MANAGER_ROLE(), msg.sender),
            "UARCalc: not admin"
        );
        _;
    }

    /// @param _manager the address of the manager/config contract so we can fetch variables
    constructor(address _manager) {
        manager = UbiquityDollarManager(_manager);
    }

    /// @notice set the constant for uAR calculation
    /// @param coef new constant for uAR calculation in ETH format
    /// @dev a coef of 1 ether means 1
    function setConstant(uint256 coef) external onlyAdmin {
        _coef = coef;
    }

    /// @notice get the constant for uAR calculation
    function getConstant() external view returns (uint256) {
        return _coef;
    }

    // dollarsToBurn * (blockHeight_debt/blockHeight_burn) * _coef
    function getUARAmount(uint256 dollarsToBurn, uint256 blockHeightDebt)
        external
        view
        override
        returns (uint256)
    {
        require(
            CreditNFT(manager.debtCouponAddress()).getTotalOutstandingDebt()
                < IERC20(manager.dollarTokenAddress()).totalSupply(),
            "uAR to Dollar: DEBT_TOO_HIGH"
        );
        bytes16 coef = _coef.fromUInt().div((uint256(1 ether)).fromUInt());
        bytes16 curBlock = uint256(block.number).fromUInt();
        bytes16 multiplier = blockHeightDebt.fromUInt().div(curBlock);
        // x^a = e^(a*lnx(x)) so multiplier^(_coef) = e^(_coef*lnx(multiplier))
        bytes16 op = (coef.mul(multiplier.ln())).exp();
        uint256 res = dollarsToBurn.fromUInt().mul(op).toUInt();
        return res;
    }
}
