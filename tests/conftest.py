import pytest


@pytest.fixture
def deployer(a):
    yield a[-1]


@pytest.fixture
def treasury(a):
    yield a[-2]


@pytest.fixture
def token(accounts, deployer, treasury, Token):
    token = deployer.deploy(Token)
    token.setTreasury(treasury, {"from": deployer})
    amount = token.balanceOf(deployer) // len(accounts)
    for a in accounts:
        if a != deployer:
            token.transfer(a, amount, {"from": deployer})
    yield token


# Function scoped isolation fixture to enable xdist.
# Snapshots the chain before each test and reverts after test completion.
@pytest.fixture(scope="function", autouse=True)
def shared_setup(fn_isolation):
    pass
