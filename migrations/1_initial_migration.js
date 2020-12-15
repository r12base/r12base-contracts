const R12BaseToken = artifacts.require("R12BaseToken");

module.exports = function (deployer) {
  deployer.deploy(R12BaseToken);
};
