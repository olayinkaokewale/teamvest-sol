const TestToken = artifacts.require("TestToken");
const TeamVest = artifacts.require("TeamVest");

module.exports = async function (deployer, network) {

    if (network == 'development') {
        // deploy for development here
        await deployer.deploy(TestToken, '1000000000'); // 1B total supply
        const testToken = await TestToken.deployed();
        await deployer.deploy(TeamVest);
        const teamVest = await TeamVest.deployed();
    } else if (network == 'testnet') {
        // deploy testnet here
    } else if (network == 'mainnet') {
        // deploy mainnet here
    }
};
