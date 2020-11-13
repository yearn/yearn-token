# @version 0.2.7

from vyper.interfaces import ERC20


old_token: public(ERC20)
new_token: public(ERC20)


@external
def __init__(old: address, new: address):
    self.old_token = ERC20(old)
    self.new_token = ERC20(new)


@external
def upgrade(amount: uint256, receiver: address = msg.sender):
    assert self.old_token.transferFrom(msg.sender, ZERO_ADDRESS, amount)
    assert self.new_token.transfer(receiver, amount)
