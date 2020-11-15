import pytest


@pytest.fixture
def flasher(deployer, token, FlashMob):
    yield deployer.deploy(FlashMob, token)
