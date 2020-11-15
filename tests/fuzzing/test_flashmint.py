import brownie
from brownie.test import given, strategy

MAX_VALUE = 300000 * 10 ** 18


@given(amount=strategy("uint256", max_value=MAX_VALUE))
def test_flashmint_insufficient_fee(deployer, token, flasher, amount):
    fee = amount // 100
    if fee > 1:
        token.transfer(flasher, fee - 1, {"from": deployer})
    with brownie.reverts():
        flasher.callNormal(amount)


@given(amount=strategy("uint256", min_value=100, max_value=MAX_VALUE))
def test_flashmint_normal(deployer, token, flasher, amount):
    token.transfer(flasher, amount // 100, {"from": deployer})
    flasher.callNormal(amount)


@given(amount=strategy("uint256", min_value=100, max_value=MAX_VALUE))
@given(data=strategy("bytes"))
def test_flashmint_with_data(deployer, token, flasher, amount, data):
    token.transfer(flasher, amount // 100, {"from": deployer})
    flasher.callWithData(amount, data)


@given(amount=strategy("uint256", min_value=100, max_value=MAX_VALUE))
def test_flashmint_call_twice(deployer, token, flasher, amount):
    token.transfer(flasher, token.balanceOf(deployer), {"from": deployer})
    with brownie.reverts():
        flasher.callWithData(amount, b"call twice")


@given(amount=strategy("uint256", min_value=100, max_value=MAX_VALUE))
def test_flashmint_reentrancy(deployer, token, flasher, amount):
    token.transfer(flasher, token.balanceOf(deployer), {"from": deployer})
    with brownie.reverts():
        flasher.callWithData(amount, b"reentrancy")
