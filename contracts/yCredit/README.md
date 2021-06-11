问题主要来自`_deposit`中在调用 sushi 的`mint`函数时，yCredit 这个合约提供了 yCredit 代币去 mint

[banteg exploit](https://github.com/banteg/exploit-ycredit)

```typescript
    function deposit(IERC20 token, uint amount) external {
        _deposit(token, amount);
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired
    ) internal virtual returns (address pair, uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        pair = FACTORY.getPair(tokenA, tokenB);
        if (pair == address(0)) {
            pair = FACTORY.createPair(tokenA, tokenB);
            pairs[pair] = true;
            _markets.push(tokenA);
        } else if (!pairs[pair]) {
            pairs[pair] = true;
            _markets.push(tokenA);
        }

        (uint reserveA, uint reserveB) = SushiswapV2Library.getReserves(address(FACTORY), tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = SushiswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = SushiswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

    function _deposit(IERC20 token, uint amount) internal {
        uint _value = LINK.getPriceUSD(address(token)) * amount / uint256(10)**token.decimals();
        require(_value > 0, "!value");

        (address _pair, uint amountA,) = _addLiquidity(address(token), address(this), amount, _value);

        token.safeTransferFrom(msg.sender, _pair, amountA);
        _mint(_pair, _value); // Amount of scUSD to mint

        uint _liquidity = ISushiswapV2Pair(_pair).mint(address(this));
        collateral[msg.sender][address(token)] += _liquidity;

        collateralCredit[msg.sender][address(token)] += _value;
        uint _fee = _value * FEE / BASE;
        _mint(msg.sender, _value - _fee);
        _mint(address(this), _fee);
        notifyFeeAmount(_fee);

        emit Deposit(msg.sender, address(token), _value, amount, _value);
    }
```
