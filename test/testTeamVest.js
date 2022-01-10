const TestToken = artifacts.require("TestToken");
const TeamVest = artifacts.require("TeamVestMock");
const truffleAssert = require('truffle-assertions');
const { BN } = require('@openzeppelin/test-helpers');
// const { assert, expect } = require("chai");

const IS_VERBOSE = true; // change to false to hide all logs
const Logger = {
    log: (...args) => {
        if (IS_VERBOSE) {
            console.log(...args);
        }
    },
    shallow: (...args) => {
        console.log(...args);
    }
}

contract("Test Team Vesting Contract", (accounts, provider) => {

    let testToken, totalTokens = '100000000000000', teamVest;

    before(async() => {
        testToken = await TestToken.new(totalTokens);
        teamVest = await TeamVest.new();
        testToken.approve(teamVest.address, '100000000000000000000000000000000');
    });

    describe("=> Get Minter Balance", () => {
        it("Tries to get the balance of factory", async () => {
            const getBal = await testToken.balanceOf(teamVest.address);
            Logger.log(BN(getBal).toString(), "<== Balance");
        });

        it("Transfers ownership of factory", async () => {
            const trOwnership = await teamVest.transferOwnership(accounts[1]);
            Logger.log(trOwnership, "<== Transfer Ownership");
            // transfer ownership back
            await teamVest.transferOwnership(accounts[0], {from: accounts[1]});
        });
    });

    describe("Do all the vesting", () => {
        it("Tries to add members to vesting", async () => {
            const vest = await teamVest.addBulkVesting(
                [ accounts[5], accounts[6], accounts[7], accounts[8] ],
                [ 12960000, 12960000, 12960000, 12960000 ],
                [ '2000000000000000000000000000', '1000000000000000000000000000', '1000000000000000000000000000', '1000000000000000000000000000' ],
                [ 12, 12, 12, 12 ],
                testToken.address,
            );

            Logger.log(vest, "<== Bulk Vesting Logs");
        });

        it("Tries to add a new member to vesting", async () => {
            const vest = await teamVest.addSingleVesting(
                accounts[9],
                12960000,
                '2000000000000000000000000000',
                12,
                testToken.address,
            );

            Logger.log(vest, "<== Single Vesting Logs");
        });
    });

    describe("All withdrawal scenario", () => {
        it("Tries to withdraw", async () => {
            // 1. Get Balances
            let bal1 = await testToken.balanceOf(teamVest.address);
            let bal2 = await testToken.balanceOf(accounts[5]);
            Logger.log(BN(bal1).toString(), "|", BN(bal2).toString(), "<== Factory | Account 2 Balance");
            // 2. run the transaction
            const withrawalTime = Math.floor(Date.now() / 1000) + 1080000; //should go past the withdrawal time
            const withdraw = await teamVest.withdrawVest(1, withrawalTime, { from: accounts[5]});
            Logger.log(withdraw, "<== Withdraw Logs");
            // 3. Get Balances
            bal1 = await testToken.balanceOf(teamVest.address);
            bal2 = await testToken.balanceOf(accounts[5]);
            Logger.log(BN(bal1).toString(), "|", BN(bal2).toString(), "<== Factory | Account 2 Balance");
        });

        it("Account 8 withdraw all at once", async () => {
            // 1. Get Balances
            let bal1 = await testToken.balanceOf(teamVest.address);
            let bal2 = await testToken.balanceOf(accounts[8]);
            Logger.log(BN(bal1).toString(), "|", BN(bal2).toString(), "<== Factory | Account 8 Balance");
            // 2. run the transaction
            const withrawalTime = Math.floor(Date.now() / 1000) + 13960000; //should go past the withdrawal time
            const withdraw = await teamVest.withdrawVest(4, withrawalTime, { from: accounts[8]});
            Logger.log(withdraw, "<== Withdraw Logs");
            // 3. Get Balances
            bal1 = await testToken.balanceOf(teamVest.address);
            bal2 = await testToken.balanceOf(accounts[8]);
            Logger.log(BN(bal1).toString(), "|", BN(bal2).toString(), "<== Factory | Account 8 Balance");
            // 4. should try to withdraw again the transaction
            const withrawalTime2 = Math.floor(Date.now() / 1000) + (13960000 * 2); //should go past the withdrawal time
            const withdraw2 = teamVest.withdrawVest(4, withrawalTime2, { from: accounts[8]});
            await truffleAssert.fails(withdraw2, truffleAssert.ErrorType.REVERT, "TEAMVEST: you have withdrawn all amounts");
            Logger.log("TEAMVEST: you have withdrawn all amounts", "<== Response from 2nd try");
        });

        it("Tries to transfer NFT and try to withdraw - should fail (not a team member)", async () => {
            const transferNft = await teamVest.safeTransferFrom(accounts[5], accounts[1], 1, { from: accounts[5] });
            Logger.log(transferNft, "<== Transfer NFT Logs");
            const withrawalTime = Math.floor(Date.now() / 1000) + 1080000; //should go past the withdrawal time
            const withdraw = teamVest.withdrawVest(1, withrawalTime, { from: accounts[1]});
            await truffleAssert.fails(withdraw, truffleAssert.ErrorType.REVERT, "TEAMVEST: Owner is not a team member");
        });

        it("Tries to withdraw before time - should fail (time not up)", async () => {
            const withrawalTime = Math.floor(Date.now() / 1000) + 108000; //should not go past the withdrawal time
            const withdraw = teamVest.withdrawVest(3, withrawalTime, { from: accounts[7]});
            await truffleAssert.fails(withdraw, truffleAssert.ErrorType.REVERT, "TEAMVEST: you can not withdraw at this time");
        });

        it("Tries to transfer NFT, add as team member and try to withdraw - should work", async () => {
            // 1. Get Balances
            let bal1 = await testToken.balanceOf(teamVest.address);
            let bal2 = await testToken.balanceOf(accounts[1]);
            Logger.log(BN(bal1).toString(), "|", BN(bal2).toString(), "<== Factory | Account 2 Balance");
            // 2. run the transaction
            const transferNft = await teamVest.safeTransferFrom(accounts[6], accounts[1], 2, { from: accounts[6] });
            Logger.log(transferNft, "<== Transfer NFT Logs");
            // 3. Add as team member
            const addTeamMember = await teamVest.addTeamMember(accounts[1]);
            Logger.log(addTeamMember, "<== Add team member Logs");
            const withrawalTime = Math.floor(Date.now() / 1000) + 1080000; //should go past the withdrawal time
            const withdraw = await teamVest.withdrawVest(2, withrawalTime, { from: accounts[1]});
            Logger.log(withdraw, "<== Withdraw Logs");
            // 3. Get Balances
            bal1 = await testToken.balanceOf(teamVest.address);
            bal2 = await testToken.balanceOf(accounts[1]);
            Logger.log(BN(bal1).toString(), "|", BN(bal2).toString(), "<== Factory | Account 2 Balance");
        });
    });

    describe("==> Failure is good", () => {
        it("Should fail to add team member - not owner", async () => {
            const addMember = teamVest.addTeamMember(accounts[2], { from: accounts[3] });
            await truffleAssert.fails(addMember, truffleAssert.ErrorType.REVERT, "Ownable: caller is not the owner.");
        });
    })

    describe("==> Get things", () => {
        it("Get token URI", async () => {
            const tokenUri = await teamVest.tokenURI(1);
            Logger.log(tokenUri, "<== Token URI 1");
        });
    });
});