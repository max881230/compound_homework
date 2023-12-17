// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// util
import {Script, console2} from "forge-std/Script.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// cToken
import {CErc20Delegate} from "compound-protocol/contracts/CErc20Delegate.sol";
import {CErc20Delegator} from "compound-protocol/contracts/CErc20Delegator.sol";
// comptroller
import {Unitroller} from "compound-protocol/contracts/Unitroller.sol";
import {ComptrollerG7} from "compound-protocol/contracts/ComptrollerG7.sol";
// interestModel
import {WhitePaperInterestRateModel} from "compound-protocol/contracts/WhitePaperInterestRateModel.sol";
// priceOracle
import {SimplePriceOracle} from "compound-protocol/contracts/SimplePriceOracle.sol";

contract TestERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}
}

contract compoundScript is Script {
    ERC20 USDC = ERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    ERC20 UNI = ERC20(0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984);

    // address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    // address UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;

    CErc20Delegate cErc20Delegate;

    CErc20Delegator cUSDC;
    CErc20Delegator cUNI;

    WhitePaperInterestRateModel whitePaper;
    SimplePriceOracle priceOracle;

    Unitroller unitroller;
    ComptrollerG7 comptroller;
    ComptrollerG7 unitrollerProxy;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        deploycToken(0xa3aDEAF5b297fb984440eF172fEBEd5B79bAa9DA);
        vm.stopBroadcast();
    }

    function deploycToken(address admin_) public {
        priceOracle = new SimplePriceOracle();
        whitePaper = new WhitePaperInterestRateModel(0, 0);

        unitroller = new Unitroller();
        comptroller = new ComptrollerG7();
        unitrollerProxy = ComptrollerG7(address(unitroller));

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);

        cErc20Delegate = new CErc20Delegate();

        // tokenA -> USDC
        cUSDC = new CErc20Delegator(
            address(USDC),
            unitrollerProxy,
            whitePaper,
            1e6,
            "cUSDC",
            "cUSDC",
            18,
            payable(admin_),
            // payable(0xa3aDEAF5b297fb984440eF172fEBEd5B79bAa9DA),
            address(cErc20Delegate),
            new bytes(0)
        );

        // tokenB -> UNI
        cUNI = new CErc20Delegator(
            address(UNI),
            unitrollerProxy,
            whitePaper,
            1e18,
            "cUniswap",
            "cUNI",
            18,
            payable(admin_),
            // payable(0xa3aDEAF5b297fb984440eF172fEBEd5B79bAa9DA),
            address(cErc20Delegate),
            new bytes(0)
        );
    }
}
