async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deployer Address: " + deployer.address)
    console.log("Deploying contracts with the account:", deployer.address);

    console.log("Account balance:", (await deployer.getBalance()).toString());

    //const Token = await ethers.getContractFactory("SomethingSomething");
    const Token = await ethers.getContractFactory("TheMonsterCommunity");
    //const token = await Token.deploy('0x079f1BaC0025ad71Ab16253271ceCA92b222C614');
    const token = await Token.deploy(
    '0xf5e3D593FC734b267b313240A0FcE8E0edEBD69a',
    '0xf5e3D593FC734b267b313240A0FcE8E0edEBD69a',
    'https://techoshiprojects.s3.amazonaws.com/MonstersCommunity/json/',
    'https://techoshiprojects.s3.amazonaws.com/MonstersCommunity/assets/reveal.json',
    [
        ethers.utils.getAddress('0xf5e3D593FC734b267b313240A0FcE8E0edEBD69a'), 
        ethers.utils.getAddress('0xc664F3f1C7170A9C213F56456a83f54E26FF310f'),
        ethers.utils.getAddress('0xf886B127d4E381E7619d2Af1617476fef0d04F8c'),
        ethers.utils.getAddress('0x36Fa3E52D58A7401Be46353F50667FBf931e4F42')
        // ethers.utils.getAddress('0x9C3f261e2cc4C88DfaC56A5B46cdbf767eE2f231'), 
        // ethers.utils.getAddress('0x608328a456D3205fFBAcD2E00AaFE2eE2471dd17'),
        // ethers.utils.getAddress('0x9EF4c075E19ed467813aCA21A23c6aF309B6D236'),
        // ethers.utils.getAddress('0xf886B127d4E381E7619d2Af1617476fef0d04F8c'),
        // ethers.utils.getAddress('0x36Fa3E52D58A7401Be46353F50667FBf931e4F42'),
        // ethers.utils.getAddress('0x96353d42d88e8a9945cdc8308592f4853f39e114'),
        // ethers.utils.getAddress('0x109094D990aDbdfC97c5c9Ea5F5bcE54f4EB1BDB'),
        // ethers.utils.getAddress('0x4aC5d838Cc15686f45fB8BAF54e519B8388914f0'),
        // ethers.utils.getAddress('0x27a25E7d890F656cD508173A9E16369B5A29108C'),
        // ethers.utils.getAddress('0xC7b8822E1eEAd4Cd1Fb3ae33f34Daf694DBA6B23'),
        // ethers.utils.getAddress('0x317C315056fF37F9A74256Ff5345a95915673B88'),
        // ethers.utils.getAddress('0x5d2eCEDDc74D1675Ce6934AB364b01799F40F644')
    ],
    [
        50,
        20,
        10,
        20,
    ]);

    console.log("Token address:", token.address);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });