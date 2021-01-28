# @version 0.2.7

from vyper.interfaces import ERC20

implements: ERC20


interface FlashMinter:
    def executeAndReturn(amount: uint256, fee: uint256, data: Bytes[1028]): nonpayable

MIN_FLASHMINT_AMOUNT: constant(uint256) = 100

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

treasury: public(address)

allowance: public(HashMap[address, HashMap[address, uint256]])
balanceOf: public(HashMap[address, uint256])
totalSupply: public(uint256)

DECIMALS: constant(uint256) = 18
TOTAL_SUPPLY: constant(uint256) = 30_000 * 10 ** DECIMALS


struct BalanceEvent:
    blockNumber: uint256
    finalBalance: uint256


# owner => len(BalanceEvent[])
nextBalanceEvent: public(HashMap[address, uint256])
# owner => eventId => BalanceEvent
balanceEvents: public(HashMap[address, HashMap[uint256, BalanceEvent]])
# for tracking total supply change events (really just one)
deploymentBlock: uint256


@external
def __init__():
    self.treasury = msg.sender

    self.balanceOf[msg.sender] = TOTAL_SUPPLY
    self.totalSupply = TOTAL_SUPPLY

    # Record initial balance event
    self.balanceEvents[msg.sender][0] = BalanceEvent({
        blockNumber: block.number,
        finalBalance: TOTAL_SUPPLY,
    })
    self.nextBalanceEvent[msg.sender] = 1
    self.deploymentBlock = block.number

    log Transfer(ZERO_ADDRESS, msg.sender, TOTAL_SUPPLY)


@external
def setTreasury(_treasury: address):
    assert msg.sender == self.treasury
    self.treasury = _treasury


@view
@external
def name() -> String[13]:
    return "yearn.finance"


@view
@external
def symbol() -> String[3]:
    return "YFI"


@view
@external
def decimals() -> uint256:
    return DECIMALS


@internal
def _updateBalance(_account: address, _balance: uint256):
    eventId: uint256 = self.nextBalanceEvent[_account]

    self.balanceEvents[_account][eventId] = BalanceEvent({
        blockNumber: block.number,
        finalBalance: _balance,
    })
    self.nextBalanceEvent[_account] = eventId + 1
    self.balanceOf[_account] = _balance


@internal
def _mint(_receiver: address, _amount: uint256):
    assert not _receiver in [self, ZERO_ADDRESS]

    self._updateBalance(_receiver, self.balanceOf[_receiver] + _amount)
    self.totalSupply += _amount

    log Transfer(ZERO_ADDRESS, _receiver, _amount)


@internal
def _burn(_sender: address, _amount: uint256):
    self._updateBalance(_sender, self.balanceOf[_sender] - _amount)
    self.totalSupply -= _amount

    log Transfer(_sender, ZERO_ADDRESS, _amount)


@internal
def _transfer(_sender: address, _receiver: address, _amount: uint256):
    assert not _receiver in [self, ZERO_ADDRESS]

    self._updateBalance(_receiver, self.balanceOf[_receiver] + _amount)
    self._updateBalance(_sender, self.balanceOf[_sender] - _amount)

    log Transfer(_sender, _receiver, _amount)


@view
@external
def totalSupplyAt(_block: uint256) -> uint256:
    if _block < self.deploymentBlock:
        return 0
    else:
        return TOTAL_SUPPLY  # Doesn't change!


@view
@external
def balanceOfAt(_owner: address, _block: uint256) -> uint256:
    if _block < self.deploymentBlock:
        return 0

    maxEventId: uint256 = self.nextBalanceEvent[_owner]  # Guaranteed to be empty
    if maxEventId == 0:
        return 0  # No balance change events for this account!

    maxEventId -= 1  # NOTE: Binary search starts at `max = n - 1` (largest event)
    if self.balanceEvents[_owner][maxEventId].blockNumber <= _block:
        return self.balanceOf[_owner]  # After the last change event

    minEventId: uint256 = 0
    if self.balanceEvents[_owner][minEventId].blockNumber > _block:
        return 0  # Before the first change event

    # Binary search for block.number (maxiumum `log_2(MAX_UINT256)` iterations)
    for lvl in range(256):

        if minEventId >= maxEventId:
            break

        # NOTE: This is the `ceil` variant of this algorithm, so add 1 here
        selectedEventId: uint256 = (minEventId + maxEventId + 1) / 2
        blockNumber: uint256 = self.balanceEvents[_owner][selectedEventId].blockNumber

        if blockNumber > _block:
            # Move search range downwards
            # NOTE: This is the `ceil` variant of this algorithm, so only deduct 1 here
            maxEventId = selectedEventId - 1

        else:
            # Move search range upwards
            # NOTE: Always move up so we snag the last event in a series where a
            #       bunch of transfer events occured within the same block (e.g. flashmint)
            minEventId = selectedEventId

    return self.balanceEvents[_owner][maxEventId].finalBalance


@external
def transfer(_receiver: address, _amount: uint256) -> bool:
    self._transfer(msg.sender, _receiver, _amount)
    return True


@external
def transferFrom(_sender: address, _receiver: address, _amount: uint256) -> bool:
    self.allowance[_sender][msg.sender] -= _amount
    self._transfer(_sender, _receiver, _amount)
    return True


@external
def approve(_spender: address, _amount: uint256) -> bool:
    self.allowance[msg.sender][_spender] = _amount
    log Approval(msg.sender, _spender, _amount)
    return True


@external
def increaseAllowance(_spender: address, _amount: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender] + _amount
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True


@external
def decreaseAllowance(_spender: address, _amount: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][_spender] - _amount
    self.allowance[msg.sender][_spender] = allowance
    log Approval(msg.sender, _spender, allowance)
    return True


@external
def flashMint(_amount: uint256, _data: Bytes[1028] = b"") -> bool:
    assert _amount >= MIN_FLASHMINT_AMOUNT  # dev: Insufficient amount
    assert self.totalSupply == TOTAL_SUPPLY  # dev: Can't already be flash minting
    self._mint(msg.sender, _amount)
    fee: uint256 = 100 * _amount / 10000  # 1%
    FlashMinter(msg.sender).executeAndReturn(_amount, fee, _data)
    self._burn(msg.sender, _amount)
    self._transfer(msg.sender, self.treasury, fee)
    assert self.totalSupply == TOTAL_SUPPLY  # dev: Can't create new supply from flash minting
    return True
