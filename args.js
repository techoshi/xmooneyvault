require('dotenv').config();

console.log("Source Chain" + process.env.SOURCE_CHAIN);
if (process.env.SOURCE_CHAIN == 'testnet') {
    module.exports = [
        "xMooney Bank1", "xMBank1", "0xEEFE69a45CB83d8e62d4ba22F7068480BE09b78c", [], 3, "0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3"
    ]
}

if (process.env.SOURCE_CHAIN == 'bsc') {
    module.exports = [
        "xMooney Bank", "xMBank", "0x98631c69602083d04f83934576a53e2a133d482f", [], 28, "0x10ED43C718714eb63d5aA57B78B54704E256024E"
    ]
}

