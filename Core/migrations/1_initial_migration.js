// const Migrations = artifacts.require("Migrations");
const UniswapV2Factory = artifacts.require("UniswapV2Factory");

module.exports = function(deployer) {
  // deployer.deploy(Migrations);
  deployer.deploy(UniswapV2Factory, "0x776044D26572773d00261581071c81d79E85b6D9");
};
