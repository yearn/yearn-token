import pytest
import brownie


def test_transfer(accounts, token):
    a, b = accounts[0:2]

    a_balance = token.balanceOf(a)
    b_balance = token.balanceOf(b)

    # Can't send your balance to the Token contract
    with brownie.reverts():
        token.transfer(token, token.balanceOf(a), {"from": a})

    # Can't send your balance to the zero address
    with brownie.reverts():
        token.transfer(
            "0x0000000000000000000000000000000000000000",
            token.balanceOf(a),
            {"from": a},
        )

    token.transfer(b, token.balanceOf(a), {"from": a})

    assert token.balanceOf(a) == 0
    assert token.balanceOf(b) == a_balance + b_balance


def test_transferFrom(accounts, token):
    a, b, c = accounts[0:3]

    a_balance = token.balanceOf(a)
    b_balance = token.balanceOf(b)

    # Unapproved can't send
    with brownie.reverts():
        token.transferFrom(a, c, a_balance, {"from": c})

    token.approve(c, token.balanceOf(a) // 2, {"from": a})
    assert token.allowance(a, c) == token.balanceOf(a) // 2

    token.increaseAllowance(c, token.balanceOf(a) // 2, {"from": a})
    assert token.allowance(a, c) == token.balanceOf(a)

    token.decreaseAllowance(c, token.balanceOf(a) // 2, {"from": a})
    assert token.allowance(a, c) == token.balanceOf(a) // 2

    # Can't send more than what is approved
    with brownie.reverts():
        token.transferFrom(a, b, token.balanceOf(a), {"from": c})

    assert token.balanceOf(a) == a_balance
    assert token.balanceOf(b) == b_balance

    token.transferFrom(a, b, token.balanceOf(a) // 2, {"from": c})

    assert token.balanceOf(a) == a_balance // 2
    assert token.balanceOf(b) == b_balance + a_balance // 2

    # If approval is unlimited, little bit of a gas savings
    token.approve(c, 2 ** 256 - 1, {"from": a})
    token.transferFrom(a, b, token.balanceOf(a), {"from": c})

    assert token.balanceOf(a) == 0
    assert token.balanceOf(b) == a_balance + b_balance
