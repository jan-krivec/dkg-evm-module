import { DeployFunction } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  await hre.helpers.deploy({
    hre,
    newContractName: 'ServiceAgreementStorageV1',
  });
};

export default func;
func.tags = ['ServiceAgreementStorageV1'];
func.dependencies = ['Hub'];
