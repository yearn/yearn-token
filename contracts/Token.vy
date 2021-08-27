# @version 0.2.15

from vyper.interfaces import ERC20

implements: ERC20


interface FlashMinter:
    def onFlashLoan(
        sender: address,
        token: address,
        amount: uint256,
        fee: uint256,
        data: Bytes[1028],
    ): nonpayable

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


@external
def __init__():
    self.treasury = msg.sender

    self.balanceOf[msg.sender] = TOTAL_SUPPLY
    self.totalSupply = TOTAL_SUPPLY

    log Transfer(ZERO_ADDRESS, msg.sender, TOTAL_SUPPLY)


@external
def setTreasury(treasury: address):
    assert msg.sender == self.treasury
    self.treasury = treasury


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
def _mint(receiver: address, amount: uint256):
    assert not receiver in [self, ZERO_ADDRESS]

    self.balanceOf[receiver] += amount
    self.totalSupply += amount

    log Transfer(ZERO_ADDRESS, receiver, amount)


@internal
def _burn(sender: address, amount: uint256):
    self.balanceOf[sender] -= amount
    self.totalSupply -= amount

    log Transfer(sender, ZERO_ADDRESS, amount)


@internal
def _transfer(sender: address, receiver: address, amount: uint256):
    assert not receiver in [self, ZERO_ADDRESS]

    self.balanceOf[sender] -= amount
    self.balanceOf[receiver] += amount

    log Transfer(sender, receiver, amount)


@external
def transfer(receiver: address, amount: uint256) -> bool:
    self._transfer(msg.sender, receiver, amount)
    return True


@external
def transferFrom(sender: address, receiver: address, amount: uint256) -> bool:
    self.allowance[sender][msg.sender] -= amount
    self._transfer(sender, receiver, amount)
    return True


@external
def approve(spender: address, amount: uint256) -> bool:
    self.allowance[msg.sender][spender] = amount
    log Approval(msg.sender, spender, amount)
    return True


@external
def increaseAllowance(spender: address, amount: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][spender] + amount
    self.allowance[msg.sender][spender] = allowance
    log Approval(msg.sender, spender, allowance)
    return True


@external
def decreaseAllowance(spender: address, amount: uint256) -> bool:
    allowance: uint256 = self.allowance[msg.sender][spender] - amount
    self.allowance[msg.sender][spender] = allowance
    log Approval(msg.sender, spender, allowance)
    return True


@external
def maxFlashAmount(token: address) -> uint256:
    if token != self:
        return 0  # unsupported
    else:
        return MAX_UINT256 - self.totalSupply


@view
@internal
def _flashFee(amount: uint256) -> uint256:
    return 100 * amount / 10000  # 1%


@view
@external
def flashFee(token: address, amount: uint256) -> uint256:
    assert token == self  # dev: Not YFI Token
    return self._flashFee(amount)


@external
def flashMint(receiver: address, token: address, amount: uint256, data: Bytes[1028] = b"") -> bool:
    assert token == self  # dev: Not YFI Token
    assert amount >= MIN_FLASHMINT_AMOUNT  # dev: Insufficient amount
    assert self.totalSupply == TOTAL_SUPPLY  # dev: Can't already be flash minting
    self._mint(msg.sender, amount)
    fee: uint256 = self._flashFee(amount)
    FlashMinter(receiver).onFlashLoan(msg.sender, token, amount, fee, data)
    self._burn(msg.sender, amount)
    self._transfer(msg.sender, self.treasury, fee)
    assert self.totalSupply == TOTAL_SUPPLY  # dev: Can't create new supply from flash minting
    return True
