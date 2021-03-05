const MasterMex = artifacts.require("MasterMex");
require("chai").should();

contract("MasterMex", accounts => {
    const account_one = accounts[0];
    const account_two = accounts[4];
    const account_three = accounts[5];
    const decimals = 18;

    beforeEach(async function() {
        this.mastermex = await MasterMex.new() ;
    });

    describe("MasterMex test", function() {
        it("should have valid contract address", function() {
            const address = this.mastermex.address;
            address.should.not.equal(null);
        });

        // it("should get price information", async function() {
        //     await this.mastermex.getPriceInfo({from: account_two});
        //     let poolInfo = await this.mastermex.getPool.call({from: account_two});
        //     parseInt(poolInfo).should.equal(5798422601123670000);

        //     await this.mastermex.getPriceInfo({from: account_two});
        //     parseInt(priceInfo).should.equal(0);
        // });

        it("should be able to deposit", async function() {
            await this.mastermex.setGroup(1, {from: account_two});

            web3.eth.sendTransaction({
                from: account_two,
                to: this.mastermex.address,
                value: web3.utils.toWei("2", "ether")
            });

            await this.mastermex.deposit({from: account_two});

            let deposit_account_two = await this.mastermex.getBalance.call(account_two);
            parseInt(deposit_account_two).should.equal(2*(10**decimals));
        });

        it("should be able to predict and claim", async function() {
            await this.mastermex.setGroup(1, {from: account_two});
            web3.eth.sendTransaction({
                from: account_two,
                to: this.mastermex.address,
                value: web3.utils.toWei("2", "ether")
            });
            await this.mastermex.deposit({from: account_two});
            let deposit_account_two = await this.mastermex.getBalance.call(account_two);
            parseInt(deposit_account_two).should.equal(2*(10**decimals));



            await this.mastermex.setGroup(0, {from: account_three});
            web3.eth.sendTransaction({
                from: account_three,
                to: this.mastermex.address,
                value: web3.utils.toWei("1", "ether")
            });
            await this.mastermex.deposit({from: account_three});
            let deposit_account_three = await this.mastermex.getBalance.call(account_three);
            parseInt(deposit_account_three).should.equal(1.2*(10**decimals));



            web3.eth.sendTransaction({
                from: account_three,
                to: this.mastermex.address,
                value: web3.utils.toWei("0", "ether")
            });
            await this.mastermex.deposit({from: account_three});

            let groupInfoDown = await this.mastermex.getGroup.call(0);
            parseInt(groupInfoDown.totalAmt).should.equal(1*(10**decimals));
            parseInt(groupInfoDown.depositAmt).should.equal(1*(10**decimals));
            parseInt(groupInfoDown.profitAmt).should.equal(0);
            parseInt(groupInfoDown.lossAmt).should.equal(0);
            parseInt(groupInfoDown.shareProfitPerETH).should.equal(0.38*(10**decimals));

            let groupInfoUp = await this.mastermex.getGroup.call(1);
            parseInt(groupInfoUp.totalAmt).should.equal(1.62*(10**decimals));
            parseInt(groupInfoUp.depositAmt).should.equal(2*(10**decimals));           
            parseInt(groupInfoUp.profitAmt).should.equal(0);
            parseInt(groupInfoUp.lossAmt).should.equal(0.38*(10**decimals));
            parseInt(groupInfoUp.shareProfitPerETH).should.equal(0.19*(10**decimals));
        });

        it("should be able to withdraw", async function() {
            web3.eth.sendTransaction({
                from: account_two,
                to: this.mastermex.address,
                value: web3.utils.toWei("3", "ether")
            });

            await this.mastermex.setGroup(1, {from: account_two});
            await this.mastermex.deposit({from: account_two});

            let deposit_account_two = await this.mastermex.getBalance.call(account_two);
            deposit_account_two = web3.utils.fromWei(deposit_account_two, "ether");
            parseInt(deposit_account_two).should.equal(3);

            let withdraw_account_two = web3.utils.toWei("3", "ether");
            await this.mastermex.withdraw(withdraw_account_two, {from: account_two});

            deposit_account_two = await this.mastermex.getBalance.call(account_two);
            deposit_account_two = web3.utils.fromWei(deposit_account_two, "ether");
            parseFloat(deposit_account_two).should.equal(0);

        });
    });
})