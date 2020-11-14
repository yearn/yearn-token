# @version 0.2.7

from vyper.interfaces import ERC20

implements: ERC20


interface FlashMinter:
    def executeAndReturn(amount: uint256, fee: uint256, data: Bytes[1028]): nonpayable


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


@external
def __init__(_distribution: address, _treasury: address):
    self.treasury = _treasury
    self.balanceOf[_distribution] = TOTAL_SUPPLY
    self.totalSupply = TOTAL_SUPPLY
    log Transfer(ZERO_ADDRESS, _distribution, TOTAL_SUPPLY)


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
def _mint(_receiver: address, _amount: uint256):
    self.balanceOf[_receiver] += _amount
    self.totalSupply += _amount
    log Transfer(ZERO_ADDRESS, _receiver, _amount)


@internal
def _burn(_sender: address, _amount: uint256):
    self.balanceOf[_sender] -= _amount
    self.totalSupply -= _amount
    log Transfer(_sender, ZERO_ADDRESS, _amount)


@internal
def _transfer(_sender: address, _receiver: address, _amount: uint256):
    assert not _receiver in [self, ZERO_ADDRESS]
    self.balanceOf[_sender] -= _amount
    self.balanceOf[_receiver] += _amount
    log Transfer(_sender, _receiver, _amount)


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
    self._mint(msg.sender, _amount)
    fee: uint256 = 100 * _amount / 10000  # 1%
    FlashMinter(msg.sender).executeAndReturn(_amount, fee, _data)
    self._burn(msg.sender, _amount)
    self._transfer(msg.sender, self.treasury, fee)
    return True
