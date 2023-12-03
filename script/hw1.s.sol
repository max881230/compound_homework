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
    TestERC20 tokenA;

    CErc20Delegate cErc20Delegate;
    CErc20Delegator cErc20Delegator;

    WhitePaperInterestRateModel whitePaper;
    SimplePriceOracle priceOracle;

    Unitroller unitroller;
    ComptrollerG7 comptroller;
    ComptrollerG7 unitrollerProxy;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        tokenA = new TestERC20("token A", "TKA");
        // console2.log(tokenA.decimals());

        priceOracle = new SimplePriceOracle();
        whitePaper = new WhitePaperInterestRateModel(0, 0);

        unitroller = new Unitroller();
        comptroller = new ComptrollerG7();
        unitrollerProxy = ComptrollerG7(address(unitroller));

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller);
        unitrollerProxy._setPriceOracle(priceOracle);

        cErc20Delegate = new CErc20Delegate();

        cErc20Delegator = new CErc20Delegator(
            address(tokenA),
            unitrollerProxy,
            whitePaper,
            1e18,
            "cTokenA",
            "cTKA",
            18,
            payable(msg.sender),
            // payable(0xa3aDEAF5b297fb984440eF172fEBEd5B79bAa9DA),
            address(cErc20Delegate),
            new bytes(0)
        );

        vm.stopBroadcast();
    }
}
