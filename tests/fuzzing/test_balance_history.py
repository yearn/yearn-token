from brownie.test import strategy


class BalanceHistory:
    st_accounts = strategy("address")
    st_decimals = strategy("decimal", min_value="0.01", max_value="0.99")

    def __init__(self, chain, accounts, token, flasher, history):
        self.chain = chain
        self.accounts = accounts
        self.token = token
        self.flasher = flasher
        self.history = history

    def update_balances(self):
        self.history.append(
            {a: self.token.balanceOf(a) for a in [self.flasher, *self.accounts]}
        )

    def rule_transfer(self, a="st_accounts", b="st_accounts", ratio="st_decimals"):
        print(f"  Token.transfer()")

        amt = int(ratio * self.token.balanceOf(a))
        self.token.transfer(b, amt, {"from": a})
        self.update_balances()

    def rule_transferFrom(
        self, a="st_accounts", b="st_accounts", c="st_accounts", ratio="st_decimals"
    ):
        print(f"  Token.transferFrom()")

        amt = int(ratio * self.token.balanceOf(a))
        self.token.increaseApproval(c, amt, {"from": a})
        self.update_balances()

        self.token.transfer(a, b, amt, {"from": c})
        self.update_balances()

    def rule_flashmint(self, a="st_accounts", ratio="st_decimals"):
        print(f"  Token.flashMint()")

        amt = int(ratio * self.token.balanceOf(a))
        self.token.transfer(self.flasher, amt, {"from": a})
        self.update_balances()

        # Ask for exactly 100 times our fee (fee is 1%)
        self.flasher.callNormal(100 * amt, {"from": a})
        self.update_balances()

        # NOTE: Because of choice of value to mint, this should always be true
        #       It helps with the balance history invariant below
        assert self.token.balanceOf(self.flasher) == 0

    def invariant_balance_history(self):
        for blk in range(len(self.chain)):
            assert sum(self.history[blk].values()) == self.token.totalSupplyAt(blk)

            for acct, balance in self.history[blk].items():
                assert self.token.balanceOfAt(acct, blk) == balance


def test_normal_operation(chain, accounts, token, flasher, state_machine):

    history = [{a: 0 for a in [flasher, *accounts]}]
    history.append(dict(history[0]))
    history[1].update({accounts[9]: 30 * 10 ** 21})
    history.append(dict(history[1]))
    history.append(dict(history[2]))
    history[3].update({accounts[9]: 27 * 10 ** 21, accounts[0]: 3 * 10 ** 21})
    history.append(dict(history[3]))
    history[4].update({accounts[9]: 24 * 10 ** 21, accounts[1]: 3 * 10 ** 21})
    history.append(dict(history[4]))
    history[5].update({accounts[9]: 21 * 10 ** 21, accounts[2]: 3 * 10 ** 21})
    history.append(dict(history[5]))
    history[6].update({accounts[9]: 18 * 10 ** 21, accounts[3]: 3 * 10 ** 21})
    history.append(dict(history[6]))
    history[7].update({accounts[9]: 15 * 10 ** 21, accounts[4]: 3 * 10 ** 21})
    history.append(dict(history[7]))
    history[8].update({accounts[9]: 12 * 10 ** 21, accounts[5]: 3 * 10 ** 21})
    history.append(dict(history[8]))
    history[9].update({accounts[9]: 9 * 10 ** 21, accounts[6]: 3 * 10 ** 21})
    history.append(dict(history[9]))
    history[10].update({accounts[9]: 6 * 10 ** 21, accounts[7]: 3 * 10 ** 21})
    history.append(dict(history[10]))
    history[11].update({accounts[9]: 3 * 10 ** 21, accounts[8]: 3 * 10 ** 21})
    history.append(dict(history[11]))

    state_machine(BalanceHistory, chain, accounts, token, flasher, history)
