import pytest


@pytest.mark.parametrize(
    "acct,history",
    [
        (
            # Deployer
            "0x1CEE82EEd89Bd5Be5bf2507a92a755dcF1D8e8dc",
            [0, 30 * 10 ** 21] + [(30 - 3 * i) * 10 ** 21 for i in range(10)],
        ),
        # All the other accounts
        ("0x66aB6D9362d4F35596279692F0251Db635165871", [0] * 3 + [3 * 10 ** 21] * 9),
        ("0x33A4622B82D4c04a53e170c638B944ce27cffce3", [0] * 4 + [3 * 10 ** 21] * 8),
        ("0x0063046686E46Dc6F15918b61AE2B121458534a5", [0] * 5 + [3 * 10 ** 21] * 7),
        ("0x21b42413bA931038f35e7A5224FaDb065d297Ba3", [0] * 6 + [3 * 10 ** 21] * 6),
        ("0x46C0a5326E643E4f71D3149d50B48216e174Ae84", [0] * 7 + [3 * 10 ** 21] * 5),
        ("0x807c47A89F720fe4Ee9b8343c286Fc886f43191b", [0] * 8 + [3 * 10 ** 21] * 4),
        ("0x844ec86426F076647A5362706a04570A5965473B", [0] * 9 + [3 * 10 ** 21] * 3),
        ("0x23BB2Bb6c340D4C91cAa478EdF6593fC5c4a6d4B", [0] * 10 + [3 * 10 ** 21] * 2),
        # Treasury
        ("0xA868bC7c1AF08B8831795FAC946025557369F69C", [0] * 11 + [3 * 10 ** 21]),
    ],
)
def test_balance_history(chain, token, acct, history):
    assert token.balanceOfAt(acct, len(chain)) == token.balanceOf(acct)

    for blk, balance in enumerate(history):
        assert token.balanceOfAt(acct, blk) == balance


def test_flashmint_history(chain, token, treasury, FlashMob):
    starting_block = len(chain) - 1
    balance = token.balanceOf(treasury)
    flasher = treasury.deploy(FlashMob, token)

    # Double check this event
    next_event = token.nextBalanceEvent(treasury)
    token.transfer(flasher, balance, {"from": treasury})
    # Transfer events
    assert token.balanceEvents(treasury, next_event).dict() == {
        "blockNumber": starting_block + 2,
        "finalBalance": 0,
    }
    assert token.balanceEvents(flasher, 0).dict() == {
        "blockNumber": starting_block + 2,
        "finalBalance": balance,
    }
    assert token.balanceOfAt(flasher, starting_block + 2) == balance
    assert token.balanceOfAt(treasury, starting_block + 2) == 0
    assert token.balanceOf(flasher) == balance

    # Call flash mint
    next_event = token.nextBalanceEvent(treasury)
    flasher.callNormal(100 * balance, {"from": treasury})
    # Flash mint events
    assert token.balanceEvents(flasher, 1).dict() == {
        "blockNumber": starting_block + 3,
        "finalBalance": 101 * balance,
    }
    assert token.balanceEvents(flasher, 2).dict() == {
        "blockNumber": starting_block + 3,
        "finalBalance": balance,
    }
    assert token.balanceEvents(flasher, 3).dict() == {
        "blockNumber": starting_block + 3,
        "finalBalance": 0,
    }
    assert token.balanceEvents(treasury, next_event).dict() == {
        "blockNumber": starting_block + 3,
        "finalBalance": balance,
    }
    assert token.balanceOfAt(flasher, starting_block + 3) == 0
    assert token.balanceOfAt(treasury, starting_block + 3) == balance
    assert token.balanceOf(treasury) == balance
